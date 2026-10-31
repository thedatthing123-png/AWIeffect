import Foundation
import Metal
import CoreGraphics
import UIKit
import simd
import CoreImage

/// Must match DabParams / LayerCompositeParams in Draw.metal.
struct DabParams { var color: SIMD4<Float>; var dab: SIMD4<Float>; var extra: SIMD4<Float>; var region: SIMD4<UInt32> }
struct LayerCompositeParams { var info: SIMD4<Float>; var mode: SIMD4<UInt32> }

enum BrushKind: String, Codable, CaseIterable, Identifiable {
    case pen, pencil, marker, airbrush, ink, flat, spray, glow, watercolor, charcoal, screentone, eraser
    var id: String { rawValue }
    var title: String { self == .flat ? "Flat Chisel" : rawValue.capitalized }
    var symbol: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .marker: return "highlighter"
        case .airbrush: return "aqi.medium"
        case .ink: return "paintbrush.pointed"
        case .flat: return "paintbrush"
        case .spray: return "aqi.high"
        case .glow: return "sun.max"
        case .watercolor: return "drop"
        case .charcoal: return "scribble.variable"
        case .screentone: return "circle.grid.3x3.fill"
        case .eraser: return "eraser"
        }
    }
}

struct Brush: Equatable {
    var kind: BrushKind = .pen
    var size: Double = 12
    var opacity: Double = 1
    var hardness: Double = 0.85
    /// 0 = raw input, 1 = very smooth (lazy-mouse stabilizer).
    var stabilizer: Double = 0.4
    var color: RGBA = .black
    /// Size follows Apple Pencil pressure.
    var pressureSize = true
}

/// One Draw Studio layer: a GPU texture plus its settings.
final class DrawLayer: Identifiable {
    let id: UUID
    var name: String
    var opacity: Double = 1
    var blend: BlendMode = .normal
    var visible = true
    var clipping = false
    var alphaLock = false
    let texture: MTLTexture

    init(id: UUID = UUID(), name: String, texture: MTLTexture) {
        self.id = id; self.name = name; self.texture = texture
    }
}

/// Saved drawing (live-linked to a timeline image layer).
struct DrawingDoc: Codable, Equatable {
    struct LayerInfo: Codable, Equatable {
        var id: UUID; var name: String; var opacity: Double; var blend: BlendMode
        var visible: Bool; var clipping: Bool; var alphaLock: Bool; var file: String
    }
    var id = UUID()
    var width: Int
    var height: Int
    var layers: [LayerInfo]
}

/// Raster painting engine on Metal (ibisPaint-style): brushes, layers, selections, fill, undo.
final class DrawEngine: ObservableObject {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let width: Int, height: Int
    @Published private(set) var layers: [DrawLayer] = []
    @Published var activeIndex = 0
    @Published private(set) var hasSelection = false
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published var revision = 0
    var brush = Brush()
    let canvas: MTLTexture
    private(set) var selection: MTLTexture
    private let stampPSO, compositePSO, fillPSO: MTLComputePipelineState
    let displayPSO: MTLRenderPipelineState
    private var undoStack: [(layer: UUID, bytes: [UInt8])] = []
    private var redoStack: [(layer: UUID, bytes: [UInt8])] = []
    private var lastPoint: SIMD2<Double>?
    private var smoothed: SIMD2<Double>?
    private var residual = 0.0
    static let maxUndo = 12

    init?(width: Int, height: Int) {
        guard let r = Renderer.shared, let lib = r.device.makeDefaultLibrary() else { return nil }
        device = r.device
        queue = r.queue
        self.width = width; self.height = height
        func pso(_ n: String) -> MTLComputePipelineState? { lib.makeFunction(name: n).flatMap { try? r.device.makeComputePipelineState(function: $0) } }
        guard let s = pso("stampDab"), let c = pso("compositeDrawLayer"), let f = pso("fillCanvas") else { return nil }
        stampPSO = s; compositePSO = c; fillPSO = f
        let rp = MTLRenderPipelineDescriptor()
        rp.vertexFunction = lib.makeFunction(name: "drawDisplayVertex")
        rp.fragmentFunction = lib.makeFunction(name: "drawDisplayFragment")
        rp.colorAttachments[0].pixelFormat = .bgra8Unorm
        guard let dp = try? r.device.makeRenderPipelineState(descriptor: rp) else { return nil }
        displayPSO = dp
        guard let cv = Self.makeTexture(r.device, width, height, .rgba8Unorm),
              let sel = Self.makeTexture(r.device, width, height, .r8Unorm) else { return nil }
        canvas = cv
        selection = sel
        clearSelection()
        addLayer(name: "Layer 1")
    }

    static func makeTexture(_ d: MTLDevice, _ w: Int, _ h: Int, _ f: MTLPixelFormat) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: f, width: max(1, w), height: max(1, h), mipmapped: false)
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .shared
        return d.makeTexture(descriptor: desc)
    }

    var activeLayer: DrawLayer? { layers.indices.contains(activeIndex) ? layers[activeIndex] : nil }

    // MARK: Layers

    @discardableResult
    func addLayer(name: String? = nil, bytes: [UInt8]? = nil, at index: Int? = nil) -> DrawLayer? {
        guard let t = Self.makeTexture(device, width, height, .rgba8Unorm) else { return nil }
        let bytesToWrite = bytes ?? [UInt8](repeating: 0, count: width * height * 4)
        t.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytesToWrite, bytesPerRow: width * 4)
        let l = DrawLayer(name: name ?? "Layer \(layers.count + 1)", texture: t)
        let i = index ?? (layers.isEmpty ? 0 : activeIndex + 1)
        layers.insert(l, at: min(i, layers.count))
        activeIndex = min(i, layers.count - 1)
        revision += 1
        return l
    }

    func deleteActiveLayer() {
        guard layers.count > 1, layers.indices.contains(activeIndex) else { return }
        layers.remove(at: activeIndex)
        activeIndex = max(0, activeIndex - 1)
        revision += 1
    }

    func duplicateActiveLayer() {
        guard let l = activeLayer else { return }
        let copy = addLayer(name: l.name + " copy", bytes: bytes(of: l))
        copy?.opacity = l.opacity; copy?.blend = l.blend
    }

    func moveActiveLayer(up: Bool) {
        let j = up ? activeIndex + 1 : activeIndex - 1
        guard layers.indices.contains(j) else { return }
        layers.swapAt(activeIndex, j)
        activeIndex = j
        revision += 1
    }

    /// Merges the active layer into the one below it.
    func mergeDown() {
        guard activeIndex > 0, let top = activeLayer else { return }
        let below = layers[activeIndex - 1]
        pushUndo(below)
        guard let cb = queue.makeCommandBuffer() else { return }
        composite(top, onto: below.texture, clipBase: below.texture, cb: cb)
        cb.commit(); cb.waitUntilCompleted()
        layers.remove(at: activeIndex)
        activeIndex -= 1
        revision += 1
    }

    func touch() { revision += 1 }

    // MARK: Pixels

    func bytes(of l: DrawLayer) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: width * height * 4)
        l.texture.getBytes(&b, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return b
    }

    func setBytes(_ b: [UInt8], of l: DrawLayer) {
        l.texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: b, bytesPerRow: width * 4)
    }

    private func selectionBytes() -> [UInt8] {
        var b = [UInt8](repeating: 0, count: width * height)
        selection.getBytes(&b, bytesPerRow: width, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        return b
    }

    // MARK: Undo

    private func pushUndo(_ l: DrawLayer) {
        undoStack.append((l.id, bytes(of: l)))
        if undoStack.count > Self.maxUndo { undoStack.removeFirst() }
        redoStack.removeAll()
        canUndo = true; canRedo = false
    }

    func undo() {
        guard let s = undoStack.popLast(), let l = layers.first(where: { $0.id == s.layer }) else { return }
        redoStack.append((l.id, bytes(of: l)))
        setBytes(s.bytes, of: l)
        canUndo = !undoStack.isEmpty; canRedo = true
        revision += 1
    }

    func redo() {
        guard let s = redoStack.popLast(), let l = layers.first(where: { $0.id == s.layer }) else { return }
        undoStack.append((l.id, bytes(of: l)))
        setBytes(s.bytes, of: l)
        canUndo = true; canRedo = !redoStack.isEmpty
        revision += 1
    }

    // MARK: Strokes

    func beginStroke(at p: SIMD2<Double>, pressure: Double) {
        guard let l = activeLayer else { return }
        pushUndo(l)
        lastPoint = p
        smoothed = p
        residual = 0
        stampBatch([p], pressure: pressure)
    }

    func continueStroke(to raw: SIMD2<Double>, pressure: Double) {
        guard let last = lastPoint, var s = smoothed else { return }
        // Lazy-mouse stabilizer.
        let k = 1 - min(0.92, brush.stabilizer * 0.92)
        s = s + (raw - s) * k
        smoothed = s
        let radius = radiusFor(pressure)
        let k2: Double
        switch brush.kind {
        case .airbrush, .glow, .watercolor: k2 = 0.12
        case .spray: k2 = 0.35
        case .screentone: k2 = 0.3
        default: k2 = 0.22
        }
        let spacing = max(0.75, radius * k2)
        let d = simd_length(s - last)
        var t = spacing - residual
        var dabs: [SIMD2<Double>] = []
        while t <= d {
            dabs.append(last + (s - last) * (t / max(d, 1e-9)))
            t += spacing
        }
        stampBatch(dabs, pressure: pressure)
        residual = d - (t - spacing)
        lastPoint = s
    }

    func endStroke() {
        lastPoint = nil; smoothed = nil
        revision += 1
    }

    private func radiusFor(_ pressure: Double) -> Double {
        let p = brush.pressureSize ? (0.25 + 0.75 * min(max(pressure, 0), 1)) : 1
        return max(0.5, brush.size / 2 * p)
    }

    /// Stamps every dab of a stroke segment in ONE command buffer (dabs stay in order, so overlaps build up right).
    private func stampBatch(_ points: [SIMD2<Double>], pressure: Double) {
        guard !points.isEmpty, let l = activeLayer, let cb = queue.makeCommandBuffer(), let enc = cb.makeComputeCommandEncoder() else { return }
        let r = radiusFor(pressure)
        let kind = brush.kind
        let flow: Double
        switch kind {
        case .airbrush: flow = 0.08
        case .glow: flow = 0.1
        case .watercolor: flow = 0.12
        case .marker: flow = 0.35
        case .charcoal: flow = 0.6
        default: flow = 1
        }
        var c = brush.color.simd
        c.w = Float(brush.opacity * flow)
        let texKind: Float
        switch kind {
        case .pencil: texKind = 1
        case .airbrush: texKind = 2
        case .spray: texKind = 3
        case .flat: texKind = 4
        case .glow: texKind = 5
        case .watercolor: texKind = 6
        case .screentone: texKind = 7
        case .charcoal: texKind = 8
        default: texKind = 0
        }
        let hard = kind == .ink ? 0.95 : (kind == .pencil ? 0.6 : brush.hardness)
        enc.setComputePipelineState(stampPSO)
        enc.setTexture(l.texture, index: 0)
        enc.setTexture(selection, index: 1)
        let tw = stampPSO.threadExecutionWidth, th = max(1, stampPSO.maxTotalThreadsPerThreadgroup / tw)
        for p in points {
            let x0 = max(0, Int(p.x - r - 1)), y0 = max(0, Int(p.y - r - 1))
            let x1 = min(width, Int(p.x + r + 2)), y1 = min(height, Int(p.y + r + 2))
            guard x1 > x0, y1 > y0 else { continue }
            var params = DabParams(color: c, dab: SIMD4(Float(p.x), Float(p.y), Float(r), Float(hard)),
                                   extra: SIMD4(kind == .eraser ? 1 : 0, l.alphaLock ? 1 : 0, texKind, Float.random(in: 0...100)),
                                   region: SIMD4(UInt32(x0), UInt32(y0), UInt32(x1 - x0), UInt32(y1 - y0)))
            enc.setBytes(&params, length: MemoryLayout<DabParams>.stride, index: 0)
            enc.dispatchThreadgroups(MTLSize(width: (x1 - x0 + tw - 1) / tw, height: (y1 - y0 + th - 1) / th, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
            // Each dab reads what the previous one wrote.
            enc.memoryBarrier(scope: .textures)
        }
        enc.endEncoding()
        cb.commit()
    }

    // MARK: Composite

    private func composite(_ l: DrawLayer, onto target: MTLTexture, clipBase: MTLTexture, cb: MTLCommandBuffer) {
        guard let enc = cb.makeComputeCommandEncoder() else { return }
        var p = LayerCompositeParams(info: SIMD4(Float(l.opacity), l.clipping ? 1 : 0, 0, 0), mode: SIMD4(l.blend.shaderIndex, 0, 0, 0))
        enc.setComputePipelineState(compositePSO)
        enc.setTexture(target, index: 0)
        enc.setTexture(l.texture, index: 1)
        enc.setTexture(clipBase, index: 2)
        enc.setBytes(&p, length: MemoryLayout<LayerCompositeParams>.stride, index: 0)
        dispatch(enc, compositePSO)
        enc.endEncoding()
    }

    private func dispatch(_ enc: MTLComputeCommandEncoder, _ pso: MTLComputePipelineState) {
        let tw = pso.threadExecutionWidth, th = max(1, pso.maxTotalThreadsPerThreadgroup / tw)
        enc.dispatchThreadgroups(MTLSize(width: (width + tw - 1) / tw, height: (height + th - 1) / th, depth: 1),
                                 threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
    }

    /// Flattens visible layers into `canvas` (transparent background).
    func encodeComposite(_ cb: MTLCommandBuffer) {
        if let enc = cb.makeComputeCommandEncoder() {
            var clear = SIMD4<Float>(0, 0, 0, 0)
            enc.setComputePipelineState(fillPSO)
            enc.setTexture(canvas, index: 0)
            enc.setBytes(&clear, length: 16, index: 0)
            dispatch(enc, fillPSO)
            enc.endEncoding()
        }
        // layers[0] is the bottom layer. Clipping layers clip to the nearest non-clipping layer below.
        var base: MTLTexture = canvas
        for l in layers where l.visible {
            if !l.clipping { base = l.texture }
            composite(l, onto: canvas, clipBase: base, cb: cb)
        }
    }

    // MARK: Selection

    func clearSelection() {
        let full = [UInt8](repeating: 255, count: width * height)
        selection.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: full, bytesPerRow: width)
        hasSelection = false
        revision += 1
    }

    /// Lasso selection from canvas-space points (antialiased).
    func selectLasso(_ pts: [SIMD2<Double>]) {
        guard pts.count >= 3 else { return }
        var mask = [UInt8](repeating: 0, count: width * height)
        mask.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return }
            // Flip so canvas y-down matches.
            ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: pts[0].x, y: pts[0].y))
            for p in pts.dropFirst() { ctx.addLine(to: CGPoint(x: p.x, y: p.y)) }
            ctx.closePath(); ctx.fillPath()
        }
        selection.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: mask, bytesPerRow: width)
        hasSelection = true
        revision += 1
    }

    /// Magic wand on the active layer: contiguous pixels within `tolerance` of the tapped color.
    func selectWand(at p: SIMD2<Double>, tolerance: Double) {
        guard let l = activeLayer else { return }
        let px = bytes(of: l)
        let mask = Self.floodMask(px, width, height, Int(p.x), Int(p.y), tolerance)
        selection.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: mask, bytesPerRow: width)
        hasSelection = true
        revision += 1
    }

    func invertSelection() {
        let s = selectionBytes().map { 255 - $0 }
        selection.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: s, bytesPerRow: width)
        hasSelection = true
        revision += 1
    }

    /// Selects everything the active layer covers (select by opacity).
    func selectOpaque() {
        guard let l = activeLayer else { return }
        let px = bytes(of: l)
        var m = [UInt8](repeating: 0, count: width * height)
        for i in 0..<(width * height) { m[i] = px[i * 4 + 3] }
        selection.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: m, bytesPerRow: width)
        hasSelection = true
        revision += 1
    }

    private var clipboard: [UInt8]?

    /// Copies the selected part of the active layer.
    func copySelection() {
        guard let l = activeLayer else { return }
        let px = bytes(of: l), sel = selectionBytes()
        var out = [UInt8](repeating: 0, count: px.count)
        for i in 0..<(width * height) {
            let m = UInt16(sel[i])
            for c in 0..<4 { out[i * 4 + c] = UInt8(UInt16(px[i * 4 + c]) * m / 255) }
        }
        clipboard = out
    }

    func deleteSelection() {
        guard let l = activeLayer else { return }
        pushUndo(l)
        var px = bytes(of: l)
        let sel = selectionBytes()
        for i in 0..<(width * height) {
            let keep = UInt16(255 - sel[i])
            for c in 0..<4 { px[i * 4 + c] = UInt8(UInt16(px[i * 4 + c]) * keep / 255) }
        }
        setBytes(px, of: l)
        revision += 1
    }

    func cutSelection() { copySelection(); deleteSelection() }

    var hasClipboard: Bool { clipboard != nil }

    /// Pastes the clipboard as a new layer, in place.
    func paste() {
        guard let c = clipboard else { return }
        addLayer(name: "Pasted", bytes: c)
        clearSelection()
    }

    /// Moves/scales/rotates the active layer's selected pixels (or the whole layer) around `pivot`.
    func transformActive(translate: SIMD2<Double>, scale: Double, rotation: Double, pivot: SIMD2<Double>) {
        guard let l = activeLayer, let src = cgImage(bytes(of: l)) else { return }
        pushUndo(l)
        var out = [UInt8](repeating: 0, count: width * height * 4)
        out.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .high
            ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            ctx.translateBy(x: CGFloat(pivot.x + translate.x), y: CGFloat(pivot.y + translate.y))
            ctx.rotate(by: CGFloat(rotation))
            ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            ctx.translateBy(x: CGFloat(-pivot.x), y: CGFloat(-pivot.y))
            // Draw flipped back so image rows stay top-down.
            ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
            ctx.draw(src, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        setBytes(out, of: l)
        revision += 1
    }

    // MARK: Fill

    /// Bucket fill on the active layer. Gaps up to `gapClose` px in line art are bridged by growing the boundary first.
    func fill(at p: SIMD2<Double>, tolerance: Double, gapClose: Int = 0) {
        guard let l = activeLayer else { return }
        pushUndo(l)
        var px = bytes(of: l)
        var mask = Self.floodMask(px, width, height, Int(p.x), Int(p.y), tolerance, gapClose: gapClose)
        let sel = selectionBytes()
        let c = brush.color
        for i in 0..<(width * height) {
            mask[i] = UInt8(UInt16(mask[i]) * UInt16(sel[i]) / 255)
            let a = Double(mask[i]) / 255 * c.a
            if a <= 0 { continue }
            for (k, v) in [c.r, c.g, c.b].enumerated() {
                px[i * 4 + k] = UInt8(min(255, v * a * 255 + Double(px[i * 4 + k]) * (1 - a)))
            }
            px[i * 4 + 3] = UInt8(min(255, a * 255 + Double(px[i * 4 + 3]) * (1 - a)))
        }
        setBytes(px, of: l)
        revision += 1
    }

    /// Scanline flood fill returning a 0/255 mask of the region connected to (x, y).
    static func floodMask(_ px: [UInt8], _ w: Int, _ h: Int, _ x: Int, _ y: Int, _ tolerance: Double, gapClose: Int = 0) -> [UInt8] {
        var mask = [UInt8](repeating: 0, count: w * h)
        guard x >= 0, y >= 0, x < w, y < h else { return mask }
        let seed = (y * w + x) * 4
        let target = (Int(px[seed]), Int(px[seed + 1]), Int(px[seed + 2]), Int(px[seed + 3]))
        let tol = Int(tolerance * 255)
        var blocked = [Bool](repeating: false, count: w * h)
        for i in 0..<(w * h) {
            let o = i * 4
            let d = max(abs(Int(px[o]) - target.0), abs(Int(px[o + 1]) - target.1), abs(Int(px[o + 2]) - target.2), abs(Int(px[o + 3]) - target.3))
            blocked[i] = d > tol
        }
        if gapClose > 0 {
            // Dilate boundaries so small gaps in line art don't leak.
            var grown = blocked
            for yy in 0..<h { for xx in 0..<w where blocked[yy * w + xx] {
                for dy in -gapClose...gapClose { for dx in -gapClose...gapClose {
                    let nx = xx + dx, ny = yy + dy
                    if nx >= 0, ny >= 0, nx < w, ny < h { grown[ny * w + nx] = true }
                } }
            } }
            grown[y * w + x] = false
            blocked = grown
        }
        var stack = [(x, y)]
        while let (sx, sy) = stack.popLast() {
            var lx = sx
            while lx > 0, !blocked[sy * w + lx - 1], mask[sy * w + lx - 1] == 0 { lx -= 1 }
            var rx = sx
            while rx < w - 1, !blocked[sy * w + rx + 1], mask[sy * w + rx + 1] == 0 { rx += 1 }
            for xx in lx...rx {
                let i = sy * w + xx
                if blocked[i] || mask[i] != 0 { continue }
                mask[i] = 255
                if sy > 0, !blocked[i - w], mask[i - w] == 0 { stack.append((xx, sy - 1)) }
                if sy < h - 1, !blocked[i + w], mask[i + w] == 0 { stack.append((xx, sy + 1)) }
            }
        }
        if gapClose > 0 {
            // Grow the fill back under the dilated boundary so it meets the line.
            var out = mask
            for yy in 0..<h { for xx in 0..<w where mask[yy * w + xx] == 255 {
                for dy in -gapClose...gapClose { for dx in -gapClose...gapClose {
                    let nx = xx + dx, ny = yy + dy
                    if nx >= 0, ny >= 0, nx < w, ny < h, out[ny * w + nx] == 0 {
                        let o = (ny * w + nx) * 4
                        if Int(px[o + 3]) < 200 { out[ny * w + nx] = 255 }
                    }
                } }
            } }
            return out
        }
        return mask
    }

    // MARK: Import / export

    func cgImage(_ b: [UInt8]) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(b) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }

    /// A traced-over video frame: shown while painting, left out of the saved drawing.
    var referenceLayerID: UUID?

    /// AI subject selection (Apple's on-device subject lift) on the active layer: people, animals, objects.
    @discardableResult
    func selectSubject() -> Bool {
        guard let l = activeLayer, let cg = cgImage(bytes(of: l)), let pb = CutoutEngine.mask(cg, mode: .object) else { return false }
        let ci = CIImage(cvPixelBuffer: pb)
        let sx = CGFloat(width) / ci.extent.width, sy = CGFloat(height) / ci.extent.height
        var mask = [UInt8](repeating: 0, count: width * height)
        let ctx = CIContext()
        // CIImage is y-up, the canvas is y-down.
        let img = ci.transformed(by: CGAffineTransform(scaleX: sx, y: -sy).translatedBy(x: 0, y: -ci.extent.height))
        ctx.render(img, toBitmap: &mask, rowBytes: width, bounds: CGRect(x: 0, y: 0, width: width, height: height),
                   format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
        guard mask.contains(where: { $0 > 128 }) else { return false }
        selection.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: mask, bytesPerRow: width)
        hasSelection = true
        revision += 1
        return true
    }

    /// Selection → its own layer (the subject lifted off its background, ready to redraw around).
    func liftSelectionToLayer() {
        copySelection()
        paste()
    }

    /// Flattened drawing as PNG (transparent background).
    func flattenedPNG() -> Data? {
        let ref = layers.first { $0.id == referenceLayerID }
        let wasVisible = ref?.visible ?? false
        ref?.visible = false
        defer { ref?.visible = wasVisible }
        guard let cb = queue.makeCommandBuffer() else { return nil }
        encodeComposite(cb)
        cb.commit(); cb.waitUntilCompleted()
        var b = [UInt8](repeating: 0, count: width * height * 4)
        canvas.getBytes(&b, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        guard let img = cgImage(b) else { return nil }
        return UIImage(cgImage: img).pngData()
    }

    /// Imports an image as a new layer, fitted to the canvas.
    func importImage(_ image: UIImage) {
        var out = [UInt8](repeating: 0, count: width * height * 4)
        out.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let cg = image.cgImage else { return }
            let s = min(Double(width) / Double(cg.width), Double(height) / Double(cg.height))
            let w = Double(cg.width) * s, h = Double(cg.height) * s
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: CGRect(x: (Double(width) - w) / 2, y: (Double(height) - h) / 2, width: w, height: h))
        }
        addLayer(name: "Image", bytes: out)
    }

    /// Saves the layered document next to the project media (for live re-editing).
    func save(doc id: UUID, folder: URL) throws -> DrawingDoc {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var infos: [DrawingDoc.LayerInfo] = []
        for l in layers {
            let file = "draw-\(id.uuidString)-\(l.id.uuidString).png"
            if let img = cgImage(bytes(of: l)), let data = UIImage(cgImage: img).pngData() {
                try data.write(to: folder.appendingPathComponent(file), options: .atomic)
            }
            infos.append(.init(id: l.id, name: l.name, opacity: l.opacity, blend: l.blend, visible: l.visible,
                               clipping: l.clipping, alphaLock: l.alphaLock, file: file))
        }
        let doc = DrawingDoc(id: id, width: width, height: height, layers: infos)
        try JSONEncoder().encode(doc).write(to: folder.appendingPathComponent("draw-\(id.uuidString).json"), options: .atomic)
        return doc
    }

    static func load(doc id: UUID, folder: URL) -> DrawEngine? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("draw-\(id.uuidString).json")),
              let doc = try? JSONDecoder().decode(DrawingDoc.self, from: data),
              let e = DrawEngine(width: doc.width, height: doc.height) else { return nil }
        e.layers.removeAll()
        for info in doc.layers {
            var bytes = [UInt8](repeating: 0, count: doc.width * doc.height * 4)
            if let img = UIImage(contentsOfFile: folder.appendingPathComponent(info.file).path)?.cgImage {
                bytes.withUnsafeMutableBytes { buf in
                    let ctx = CGContext(data: buf.baseAddress, width: doc.width, height: doc.height, bitsPerComponent: 8, bytesPerRow: doc.width * 4,
                                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                    ctx?.draw(img, in: CGRect(x: 0, y: 0, width: doc.width, height: doc.height))
                }
            }
            if let l = e.addLayer(name: info.name, bytes: bytes, at: e.layers.count) {
                l.opacity = info.opacity; l.blend = info.blend; l.visible = info.visible
                l.clipping = info.clipping; l.alphaLock = info.alphaLock
            }
        }
        e.activeIndex = max(0, e.layers.count - 1)
        return e
    }
}
