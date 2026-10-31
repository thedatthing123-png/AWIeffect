import Foundation
import CoreText
import CoreGraphics
import Metal
import simd
import UIKit

/// One laid-out glyph in layer-local pixels (y down, block centered on the origin).
struct LaidGlyph {
    var glyph: CGGlyph
    var font: CTFont
    /// Glyph bounding box center (local px).
    var center: Vec2
    /// Half size of the glyph bounding box (local px), before padding.
    var halfSize: Vec2
    /// Baseline origin (local px).
    var origin: Vec2
    var charIndex: Int
    var charExSpaceIndex: Int
    var wordIndex: Int
    var lineIndex: Int
    var isSpace: Bool
}

struct TextLayout {
    var glyphs: [LaidGlyph]
    var bounds: CGRect
    var charCount: Int
    var charExSpaceCount: Int
    var wordCount: Int
    var lineCount: Int
    var lineWidths: [Double]
}

/// Lays out text with Core Text and renders glyphs as tinted alpha masks through the shared compositor.
final class TextEngine {
    static let shared = TextEngine()

    private var layoutCache: [String: TextLayout] = [:]
    private var glyphCache: [String: (tex: MTLTexture, pad: Double, scale: Double)] = [:]
    private let lock = NSLock()

    static func availableFonts() -> [String] {
        UIFont.familyNames.sorted().flatMap { UIFont.fontNames(forFamilyName: $0).sorted() }
    }

    func layout(_ t: TextData, time: Double) -> TextLayout {
        let tracking = t.tracking.value(at: time)
        let spacing = t.lineSpacing.value(at: time)
        let key = "\(t.string)|\(t.fontName)|\(t.fontSize)|\(tracking)|\(spacing)|\(t.alignment.rawValue)|\(t.spacingAnchor ?? -1)"
        lock.lock()
        if let l = layoutCache[key] { lock.unlock(); return l }
        lock.unlock()
        let l = Self.computeLayout(t, tracking: tracking, spacing: spacing)
        lock.lock()
        if layoutCache.count > 64 { layoutCache.removeAll() }
        layoutCache[key] = l
        lock.unlock()
        return l
    }

    private static func computeLayout(_ t: TextData, tracking: Double, spacing: Double) -> TextLayout {
        let font = CTFontCreateWithName(t.fontName as CFString, CGFloat(max(1, t.fontSize)), nil)
        let chars = Array(t.string)
        // UTF16 offset -> Character index.
        var utf16ToChar: [Int] = []
        for (ci, ch) in chars.enumerated() { for _ in 0..<String(ch).utf16.count { utf16ToChar.append(ci) } }
        // Per-character unit indices.
        var exIdx = [Int](repeating: 0, count: chars.count), wordIdx = [Int](repeating: 0, count: chars.count)
        var ex = 0, word = -1, inWord = false
        for (i, ch) in chars.enumerated() {
            let space = ch.isWhitespace
            exIdx[i] = space ? max(0, ex - 1) : ex
            if !space { ex += 1 }
            if !space && !inWord { word += 1 }
            inWord = !space
            wordIdx[i] = max(0, word)
        }

        let lines = t.string.components(separatedBy: "\n")
        let ascent = Double(CTFontGetAscent(font)), descent = Double(CTFontGetDescent(font))
        let lineHeight = (ascent + descent) * spacing
        var glyphs: [LaidGlyph] = []
        var lineWidths: [Double] = []
        var charBase = 0
        var utf16Base = 0
        for (li, lineStr) in lines.enumerated() {
            let attr = NSAttributedString(string: lineStr, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTKernAttributeName as String): NSNumber(value: tracking),
            ])
            let line = CTLineCreateWithAttributedString(attr)
            let width = Double(CTLineGetTypographicBounds(line, nil, nil, nil))
            lineWidths.append(width)
            var x0: Double
            let al: Double
            switch t.alignment {
            case .left: al = 0
            case .center: al = 0.5
            case .right: al = 1
            }
            x0 = -width * al
            // Spacing anchor: extra space from tracking grows away from the chosen side.
            if let anchor = t.spacingAnchor, tracking != 0 {
                let plain = CTLineCreateWithAttributedString(NSAttributedString(string: lineStr, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): font]))
                let w0 = Double(CTLineGetTypographicBounds(plain, nil, nil, nil))
                x0 = -w0 * al - (width - w0) * Double(anchor) / 2
            }
            let baseline = Double(li) * lineHeight
            for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
                let n = CTRunGetGlyphCount(run)
                guard n > 0 else { continue }
                var gl = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n), idx = [CFIndex](repeating: 0, count: n)
                CTRunGetGlyphs(run, CFRange(location: 0, length: n), &gl)
                CTRunGetPositions(run, CFRange(location: 0, length: n), &pos)
                CTRunGetStringIndices(run, CFRange(location: 0, length: n), &idx)
                let attrs = CTRunGetAttributes(run) as NSDictionary
                let runFont = (attrs[kCTFontAttributeName] as! CTFont?) ?? font
                var rects = [CGRect](repeating: .zero, count: n)
                CTFontGetBoundingRectsForGlyphs(runFont, .horizontal, gl, &rects, n)
                for k in 0..<n {
                    let u = utf16Base + idx[k]
                    let ci = u < utf16ToChar.count ? utf16ToChar[u] : max(0, chars.count - 1)
                    let r = rects[k]
                    let ox = x0 + Double(pos[k].x), oy = baseline
                    let cx = ox + Double(r.midX), cy = oy - Double(r.midY)
                    let space = ci < chars.count ? chars[ci].isWhitespace : true
                    glyphs.append(LaidGlyph(glyph: gl[k], font: runFont, center: Vec2(cx, cy),
                                            halfSize: Vec2(Double(r.width) / 2, Double(r.height) / 2),
                                            origin: Vec2(ox, oy), charIndex: ci,
                                            charExSpaceIndex: ci < exIdx.count ? exIdx[ci] : 0,
                                            wordIndex: ci < wordIdx.count ? wordIdx[ci] : 0, lineIndex: li, isSpace: space))
                }
            }
            charBase += lineStr.count + 1
            utf16Base += lineStr.utf16.count + 1
        }
        _ = charBase
        // Center the block vertically around the origin (AE-like default anchor for our text layers).
        let totalH = Double(max(1, lines.count - 1)) * lineHeight
        let top = -ascent, bottom = totalH + descent
        let shiftY = -(top + bottom) / 2
        for i in glyphs.indices {
            glyphs[i].center.y += shiftY
            glyphs[i].origin.y += shiftY
        }
        let maxW = lineWidths.max() ?? 0
        let bx: Double = t.alignment == .left ? 0 : (t.alignment == .center ? -maxW / 2 : -maxW)
        let bounds = CGRect(x: bx, y: top + shiftY, width: max(1, maxW), height: max(1, bottom - top))
        return TextLayout(glyphs: glyphs, bounds: bounds, charCount: chars.count, charExSpaceCount: max(1, ex),
                          wordCount: max(1, word + 1), lineCount: max(1, lines.count), lineWidths: lineWidths)
    }

    /// Rasterized alpha mask for a glyph at `scale` device px per local px (bucketed for caching).
    func glyphTexture(_ g: LaidGlyph, scale: Double, blur rawBlur: Double = 0, device: MTLDevice) -> (tex: MTLTexture, pad: Double, scale: Double)? {
        // Bucket scales to powers of 2^(1/4) so zooming doesn't re-rasterize every frame.
        let b = pow(2, (log2(max(scale, 0.05)) * 4).rounded(.up) / 4)
        // Blur (local px) in half-pixel steps, so animated blur reuses rasters.
        let blur = min(200, (max(0, rawBlur) * 2).rounded() / 2)
        let fontName = CTFontCopyPostScriptName(g.font) as String
        let size = Double(CTFontGetSize(g.font))
        let key = "\(fontName)|\(size)|\(g.glyph)|\(b)|\(blur)"
        lock.lock()
        if let c = glyphCache[key] { lock.unlock(); return c }
        lock.unlock()

        let blurPx = blur * b
        let pad = 2.0 + blurPx * 2.5
        let w = max(1, Int(ceil(g.halfSize.x * 2 * b + pad * 2))), h = max(1, Int(ceil(g.halfSize.y * 2 * b + pad * 2)))
        guard w < 4096, h < 4096 else { return nil }
        var pixels = [UInt8](repeating: 0, count: w * h)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setAllowsFontSmoothing(false)
        ctx.setShouldAntialias(true)
        ctx.setFillColor(gray: 1, alpha: 1)
        var rect = CGRect.zero
        var glyph = g.glyph
        CTFontGetBoundingRectsForGlyphs(g.font, .horizontal, &glyph, &rect, 1)
        if blurPx > 0.25 {
            // Real gaussian: draw the glyph off-canvas and keep only its blurred shadow on the canvas.
            ctx.setShadow(offset: CGSize(width: -CGFloat(w * 2), height: 0), blur: CGFloat(blurPx * 2), color: CGColor(gray: 1, alpha: 1))
            ctx.translateBy(x: CGFloat(w * 2), y: 0)
        }
        ctx.scaleBy(x: CGFloat(b), y: CGFloat(b))
        var pos = CGPoint(x: -rect.minX + CGFloat(pad / b), y: -rect.minY + CGFloat(pad / b))
        CTFontDrawGlyphs(g.font, &glyph, &pos, 1, ctx)
        // A bitmap context's first memory row is already the TOP of the image (user space is y-up, but
        // memory is stored top-down), so the bytes are in texture order as-is. Flipping here turned letters upside-down.
        let flipped = pixels

        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: flipped, bytesPerRow: w)
        let entry = (tex: tex, pad: pad, scale: b)
        lock.lock()
        if glyphCache.count > 4000 { glyphCache.removeAll() }
        glyphCache[key] = entry
        lock.unlock()
        return entry
    }
}

extension Renderer {
    /// Per-glyph animated state after applying all animators.
    struct GlyphState {
        var offset = Vec2.zero
        var scale = Vec2(1, 1)
        var rotation = 0.0
        var skew = 0.0
        var opacity = 1.0
        var color = RGBA.white
        var tracking = 0.0
        var blur = 0.0
        var charOffset = 0.0
        var rotX = 0.0
        var rotY = 0.0
        var z = 0.0
    }

    static func glyphStates(_ text: TextData, layout: TextLayout, time: Double) -> [GlyphState] {
        var states = layout.glyphs.map { g -> GlyphState in
            var s = GlyphState()
            s.color = text.baseColor(forCharacter: g.charIndex, time: time)
            return s
        }
        for a in text.animators where a.isEnabled {
            let sel = a.selector
            let count: Int
            switch sel.basedOn {
            case .characters: count = layout.charCount
            case .charactersExcludingSpaces: count = layout.charExSpaceCount
            case .words: count = layout.wordCount
            case .lines: count = layout.lineCount
            }
            let p = a.properties
            let pos = p.position?.value(at: time), sc = p.scale?.value(at: time), rot = p.rotation?.value(at: time)
            let op = p.opacity?.value(at: time), col = p.fill?.value(at: time), tr = p.tracking?.value(at: time)
            let sk = p.skew?.value(at: time)
            let bl = p.blur?.value(at: time), co = p.characterOffset?.value(at: time)
            let rx = p.rotationX?.value(at: time), ry = p.rotationY?.value(at: time), pz = p.positionZ?.value(at: time)
            for (gi, g) in layout.glyphs.enumerated() {
                let unit: Int
                switch sel.basedOn {
                case .characters: unit = g.charIndex
                case .charactersExcludingSpaces: unit = g.charExSpaceIndex
                case .words: unit = g.wordIndex
                case .lines: unit = g.lineIndex
                }
                let amt = SelectorMath.amount(sel, index: unit, count: count, time: time)
                if amt == 0 { continue }
                if let pos { states[gi].offset = states[gi].offset + pos * amt }
                if let sc { states[gi].scale = Vec2(states[gi].scale.x * (1 + (sc.x / 100 - 1) * amt), states[gi].scale.y * (1 + (sc.y / 100 - 1) * amt)) }
                if let rot { states[gi].rotation += rot * amt }
                if let sk { states[gi].skew += sk * amt }
                if let op { states[gi].opacity *= max(0, 1 + (op / 100 - 1) * amt) }
                if let col { states[gi].color = RGBA.lerp(states[gi].color, col, min(1, max(0, amt))) }
                if let tr { states[gi].tracking += tr * amt }
                if let bl { states[gi].blur += max(0, bl * amt) }
                if let co { states[gi].charOffset += co * amt }
                if let rx { states[gi].rotX += rx * amt }
                if let ry { states[gi].rotY += ry * amt }
                if let pz { states[gi].z += pz * amt }
            }
        }
        // Tracking accumulates along each line, then the line is re-centered for the alignment.
        var lineTotals: [Int: Double] = [:]
        var running: [Int: Double] = [:]
        for (gi, g) in layout.glyphs.enumerated() {
            let r = running[g.lineIndex, default: 0]
            states[gi].offset.x += r
            running[g.lineIndex] = r + states[gi].tracking
            lineTotals[g.lineIndex] = r + states[gi].tracking
        }
        if text.alignment != .left {
            for (gi, g) in layout.glyphs.enumerated() {
                let total = lineTotals[g.lineIndex, default: 0]
                states[gi].offset.x -= text.alignment == .center ? total / 2 : total
            }
        }
        return states
    }

    /// AE Character Offset: letters move through A-Z / a-z, digits through 0-9; other characters stay.
    static func offsetCharacter(_ c: Character, by n: Int) -> Character? {
        guard let v = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1 else { return nil }
        func wrap(_ base: UInt32, _ count: Int) -> Character? {
            let i = ((Int(v - base) + n) % count + count) % count
            return UnicodeScalar(base + UInt32(i)).map(Character.init)
        }
        switch v {
        case 65...90: return wrap(65, 26)
        case 97...122: return wrap(97, 26)
        case 48...57: return wrap(48, 10)
        default: return nil
        }
    }

    /// Draws a text layer. `M` maps layer-local px -> target px; `density` = target px per local px.
    func drawText(cb: MTLCommandBuffer, target: MTLTexture, matrix M: simd_double3x3, density: Double,
                  layer: Layer, time: Double, opacity: Double, blend: BlendMode) {
        guard let text = layer.text?.resolved(at: time) else { return }
        let lay = TextEngine.shared.layout(text, time: time)
        let states = Self.glyphStates(text, layout: lay, time: time)
        let chars = Array(text.string)
        // Path for text-on-path (the layer's first mask), measured once per frame.
        let pathTrack: PathTrack? = (text.onPath ?? false) ? layer.masks.first.map {
            PathTrack($0.path.value(at: time), offsetPercent: text.pathOffset?.value(at: time) ?? 0)
        } : nil
        for (gi, g0) in lay.glyphs.enumerated() where !g0.isSpace {
            let st = states[gi]
            var g = g0
            // Character Offset: swap in the shifted letter's glyph (same spot, its own size).
            let shift = Int(st.charOffset.rounded())
            if shift != 0, g.charIndex < chars.count, let shifted = Self.offsetCharacter(chars[g.charIndex], by: shift) {
                var u = Array(String(shifted).utf16), gl = [CGGlyph](repeating: 0, count: u.count)
                if CTFontGetGlyphsForCharacters(g.font, &u, &gl, u.count), gl[0] != 0 {
                    var r = CGRect.zero
                    CTFontGetBoundingRectsForGlyphs(g.font, .horizontal, &gl, &r, 1)
                    g.glyph = gl[0]
                    g.halfSize = Vec2(Double(r.width) / 2, Double(r.height) / 2)
                    g.center = Vec2(g.origin.x + Double(r.midX), g.origin.y - Double(r.midY))
                }
            }
            let a = opacity * st.opacity * st.color.a
            if a <= 0.001 { continue }
            let glyphScale = density * max(abs(st.scale.x), abs(st.scale.y), 0.05)
            guard let gt = TextEngine.shared.glyphTexture(g, scale: glyphScale, blur: st.blur, device: device) else { continue }
            // Glyph quad half-size including raster padding (local px).
            let hs = Vec2(g.halfSize.x + gt.pad / gt.scale, g.halfSize.y + gt.pad / gt.scale)
            var rot = st.rotation * .pi / 180
            let skew = tan(st.skew * .pi / 180)
            var c = g.center + st.offset
            // Characters scale/rotate around their baseline center like AE's default anchor.
            var pivot = Vec2(g.center.x, g.origin.y) + st.offset
            // Text on path: slide each letter along the mask path and turn it with the curve.
            if let track = pathTrack {
                let along = track.offset + (g.center.x - lay.bounds.minX) + st.offset.x
                let (pt, ang) = track.point(at: along)
                let nrm = Vec2(-sin(ang), cos(ang))
                let lift = g.origin.y - lay.bounds.maxY
                let base = pt + nrm * (lift + st.offset.y)
                pivot = base
                c = base + nrm * (g.center.y - g.origin.y)
                rot += ang
            }
            let toPivot = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(c.x - pivot.x, c.y - pivot.y, 1)))
            let T = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(pivot.x, pivot.y, 1)))
            let R = simd_double3x3(columns: (SIMD3(cos(rot), sin(rot), 0), SIMD3(-sin(rot), cos(rot), 0), SIMD3(0, 0, 1)))
            let K = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(-skew, 1, 0), SIMD3(0, 0, 1)))
            // Per-character 3D: flips foreshorten the letter, depth shrinks / grows it (1000 px focal length).
            let depth = 1000 / max(50, 1000 + st.z)
            let S = simd_double3x3(diagonal: SIMD3(st.scale.x * cos(st.rotY * .pi / 180) * depth, st.scale.y * cos(st.rotX * .pi / 180) * depth, 1))
            let G = M * T * R * K * S * toPivot
            let det = G[0][0] * G[1][1] - G[1][0] * G[0][1]
            if abs(det) < 1e-12 { continue }
            let inv = G.inverse
            let pxPerLocal = max(1e-4, density * min(abs(st.scale.x), abs(st.scale.y)))
            var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
            for cx in [-hs.x - 2, hs.x + 2] { for cy in [-hs.y - 2, hs.y + 2] {
                let p = G * SIMD3(cx, cy, 1)
                let z = max(p.z, 1e-6)
                minX = min(minX, p.x / z); maxX = max(maxX, p.x / z); minY = min(minY, p.y / z); maxY = max(maxY, p.y / z)
            } }
            let x0 = max(0, Int(floor(minX))), y0 = max(0, Int(floor(minY)))
            let x1 = min(target.width, Int(ceil(maxX))), y1 = min(target.height, Int(ceil(maxY)))
            if x1 <= x0 || y1 <= y0 { continue }
            var params = LayerParams(
                invRow0: SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0),
                invRow1: SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0),
                invRow2: SIMD4(Float(inv[0][2]), Float(inv[1][2]), Float(inv[2][2]), 0),
                color: st.color.simd,
                geom: SIMD4(Float(hs.x), Float(hs.y), Float(opacity * st.opacity), 0),
                geom2: SIMD4(0, 0, Float(1 / pxPerLocal), 0),
                modes: SIMD4(0, blend.shaderIndex, 3, 0),
                region: SIMD4(UInt32(x0), UInt32(y0), UInt32(x1 - x0), UInt32(y1 - y0)))
            guard let enc = cb.makeComputeCommandEncoder() else { return }
            enc.setComputePipelineState(drawPSO)
            enc.setTexture(target, index: 0)
            enc.setTexture(gt.tex, index: 1)
            enc.setBytes(&params, length: MemoryLayout<LayerParams>.stride, index: 0)
            dispatch(enc, pso: drawPSO, width: x1 - x0, height: y1 - y0)
            enc.endEncoding()
        }
    }

    /// Local bounds of a text layer (unanimated layout).
    static func textBounds(_ layer: Layer, time: Double) -> CGRect? {
        guard let t = layer.text?.resolved(at: time) else { return nil }
        return TextEngine.shared.layout(t, time: time).bounds
    }
}


/// A path measured by length: point + direction at any distance along it (for text on path).
struct PathTrack {
    private var pts: [Vec2] = []
    private var cum: [Double] = [0]
    let offset: Double
    var length: Double { cum.last ?? 0 }

    init(_ path: BezierPath, offsetPercent: Double) {
        let segs = path.segments(stepsPerCurve: 24)
        if let f = segs.first { pts.append(Vec2(Double(f.x), Double(f.y))) }
        for s in segs {
            let p = Vec2(Double(s.z), Double(s.w))
            cum.append(cum.last! + hypot(p.x - pts.last!.x, p.y - pts.last!.y))
            pts.append(p)
        }
        let total = cum.last ?? 0
        offset = total * offsetPercent / 100
    }

    /// Point and angle (radians) at `d` px along the path (clamped to the ends, extended along the end tangents).
    func point(at d: Double) -> (Vec2, Double) {
        guard pts.count >= 2 else { return (pts.first ?? .zero, 0) }
        var i = 1
        while i < cum.count - 1 && cum[i] < d { i += 1 }
        let a = pts[i - 1], b = pts[i]
        let segLen = max(1e-9, cum[i] - cum[i - 1])
        let f = (d - cum[i - 1]) / segLen
        return (a + (b - a) * f, atan2(b.y - a.y, b.x - a.x))
    }
}
