import Foundation
import CoreGraphics
import CryptoKit

/// One image embedding per open tool, reused as selection strokes change. All Core ML work
/// stays on this actor, never in the drawing gesture or the main-actor view model.
actor InteractiveSelection {
    private var session: PromptSegmentationModel?
    private var imageKey: Data?
    private let modelDirectory: URL?

    init(modelDirectory: URL? = nil) { self.modelDirectory = modelDirectory }

    func region(image: CGImage, points: [CGPoint], width: Int, height: Int, negative: [CGPoint] = [], edgeTolerance: Double = 0.18) throws -> [UInt8] {
        try Task.checkCancellation()
        guard !points.isEmpty, width > 0, height > 0,
              let data = image.dataProvider?.data else { throw SelectionError.invalidImage }
        var hasher = SHA256()
        hasher.update(data: data as Data)
        hasher.update(data: Data("\(image.width)x\(image.height):\(image.bytesPerRow)".utf8))
        let key = Data(hasher.finalize())
        if session == nil { session = try PromptSegmentationModel(modelDirectory: modelDirectory) }
        guard let session else { throw SelectionError.invalidImage }
        if key != imageKey {
            try session.setImage(image)
            imageKey = key
        }
        try Task.checkCancellation()
        // A stroke is a region hint, not a dense set of independent classification points.
        // Dense positive sampling over-fitted skin/color regions and punched out internal ink.
        let negativeSamples = Self.samples(negative, limit: 3)
        let samples = Self.samples(points, limit: 2)
        let prompts = samples.map { SegmentationPrompt(point: $0, positive: true) }
            + negativeSamples.map { SegmentationPrompt(point: $0, positive: false) }
        let masks = try session.predict(prompts)
        try Task.checkCancellation()
        guard let first = masks.first else { throw SelectionError.noRegion }
        // Rank at the model's resolution. Expanding all three masks to a 4K painting would
        // triple temporary mask memory and make every candidate scan needlessly expensive.
        let candidates = masks.filter { $0.width == first.width && $0.height == first.height }.map { ($0.bytes, $0.score) }
        guard let chosen = Self.choose(candidates, points: samples, width: first.width, height: first.height, negative: negativeSamples) else {
            throw SelectionError.noRegion
        }
        let expanded = Self.resample(chosen, fromWidth: first.width, fromHeight: first.height, width: width, height: height)
        return Self.fitEdge(expanded, tolerance: edgeTolerance)
    }

    func selection(image: CGImage, points: [CGPoint], width: Int, height: Int,
                   painted: [UInt8], previous: [UInt8], subtract: Bool, edgeTolerance: Double = 0.18) throws -> [UInt8] {
        guard previous.count == width * height, painted.count == previous.count else { throw SelectionError.invalidImage }
        // Remove strokes are negative prompts on the existing selection, with positive anchors
        // in its retained interior. This lets a correction exclude one limb without erasing
        // the enclosing character simply because SAM also offered a whole-character mask.
        let affected = subtract ? Self.touchedComponents(previous, painted: painted, width: width, height: height) : []
        if subtract, !affected.contains(true) { return previous }
        let component = subtract ? previous.indices.map { affected[$0] ? previous[$0] : 0 } : previous
        let anchors = subtract ? Self.anchors(component, width: width, height: height, avoiding: points) : []
        if subtract, !anchors.isEmpty {
            let refined = try region(image: image, points: anchors, width: width, height: height, negative: points, edgeTolerance: edgeTolerance)
            return previous.indices.map { min(previous[$0], min(affected[$0] ? refined[$0] : previous[$0], 255 - painted[$0])) }
        }
        let inferred = try region(image: image, points: points, width: width, height: height, edgeTolerance: edgeTolerance)
        return Self.combine(region: inferred, painted: painted, previous: previous, subtract: subtract)
    }

    /// A correction to one cutout piece must not erase other disconnected selected pieces.
    static func touchedComponents(_ mask: [UInt8], painted: [UInt8], width: Int, height: Int) -> [Bool] {
        guard mask.count == width * height, painted.count == mask.count else { return [] }
        var seen = [Bool](repeating: false, count: mask.count), stack: [Int] = []
        for i in mask.indices where mask[i] > 0 && painted[i] > 0 { seen[i] = true; stack.append(i) }
        while let i = stack.popLast() {
            let x = i % width, y = i / width
            for next in [x > 0 ? i - 1 : -1, x + 1 < width ? i + 1 : -1, y > 0 ? i - width : -1, y + 1 < height ? i + width : -1] {
                if next >= 0, !seen[next], mask[next] > 0 { seen[next] = true; stack.append(next) }
            }
        }
        return seen
    }

    /// Narrow the model's probability band to a real matte: solid interiors and transparent
    /// exteriors, retaining a small antialiased boundary. The existing Edge tolerance remains wired.
    static func fitEdge(_ bytes: [UInt8], tolerance: Double) -> [UInt8] {
        let threshold = min(0.75, max(0.25, 0.5 + (0.18 - tolerance) * 0.6))
        return bytes.map { value in
            let t = min(1, max(0, (Double(value) / 255 - threshold + 0.06) / 0.12))
            return UInt8((t * t * (3 - 2 * t) * 255).rounded())
        }
    }

    static func anchors(_ mask: [UInt8], width: Int, height: Int, avoiding points: [CGPoint]) -> [CGPoint] {
        guard mask.count == width * height, width > 0, height > 0, !points.isEmpty else { return [] }
        var candidates: [(CGPoint, CGFloat)] = []
        let step = max(1, min(width, height) / 24)
        for y in stride(from: step, to: height - step, by: step) {
            for x in stride(from: step, to: width - step, by: step) {
                guard mask[y * width + x] > 240,
                      mask[(y - step) * width + x] > 240, mask[(y + step) * width + x] > 240,
                      mask[y * width + x - step] > 240, mask[y * width + x + step] > 240 else { continue }
                let p = CGPoint(x: CGFloat(x) / CGFloat(width), y: CGFloat(y) / CGFloat(height))
                let distance = points.map { hypot(p.x - $0.x, p.y - $0.y) }.min() ?? 0
                if distance > 0.06 { candidates.append((p, distance)) }
            }
        }
        var chosen: [CGPoint] = []
        for candidate in candidates.sorted(by: { $0.1 > $1.1 }) {
            if chosen.allSatisfy({ hypot($0.x - candidate.0.x, $0.y - candidate.0.y) > 0.12 }) { chosen.append(candidate.0) }
            if chosen.count == 4 { break }
        }
        return chosen
    }

    enum SelectionError: LocalizedError {
        case invalidImage, noRegion, modelOutput(String)
        var errorDescription: String? { "Could not infer this region. Your brush stroke is kept; add another stroke or turn off Smart Edges for exact painting." }
    }

    /// Arc-length sampling keeps slow gestures and fast gestures equally weighted and limits decoder cost.
    static func samples(_ points: [CGPoint], limit: Int) -> [CGPoint] {
        guard points.count > 1, limit > 1 else { return Array(points.prefix(1)) }
        var lengths = [CGFloat](repeating: 0, count: points.count)
        for i in 1..<points.count { lengths[i] = lengths[i - 1] + hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y) }
        guard let total = lengths.last, total > 0 else { return [points[0]] }
        let count = min(limit, max(2, Int(total * 128) + 1))
        var result: [CGPoint] = [], segment = 1
        for n in 0..<count {
            let d = total * CGFloat(n) / CGFloat(count - 1)
            while segment < points.count - 1 && lengths[segment] < d { segment += 1 }
            let t = (d - lengths[segment - 1]) / max(0.000001, lengths[segment] - lengths[segment - 1])
            let a = points[segment - 1], b = points[segment]
            result.append(CGPoint(x: min(1, max(0, a.x + (b.x - a.x) * t)), y: min(1, max(0, a.y + (b.y - a.y) * t))))
        }
        return result
    }

    /// Prefer a confident part mask over the enclosing whole character when both satisfy the stroke.
    /// Internal ink lines remain foreground; no color flood or unconditional hole filling is used.
    static func choose(_ candidates: [([UInt8], Float)], points: [CGPoint], width: Int, height: Int, negative: [CGPoint] = []) -> [UInt8]? {
        let valid = candidates.filter { $0.0.count == width * height && $0.0.contains { $0 >= 128 } }
        guard !valid.isEmpty, !points.isEmpty else { return nil }
        let scored = valid.map { mask, confidence -> ([UInt8], Double) in
            let covered = points.filter { p in
                let x = min(width - 1, max(0, Int(p.x * CGFloat(width))))
                let y = min(height - 1, max(0, Int(p.y * CGFloat(height))))
                return mask[y * width + x] >= 128
            }.count
            let area = Double(mask.filter { $0 >= 128 }.count) / Double(mask.count)
            let leaks = negative.filter { p in
                let x = min(width - 1, max(0, Int(p.x * CGFloat(width))))
                let y = min(height - 1, max(0, Int(p.y * CGFloat(height))))
                return mask[y * width + x] >= 128
            }.count
            let fragments = Self.inkHolePenalty(mask, width: width, height: height, protected: negative)
            return (mask, Double(covered) / Double(points.count) * 4 - Double(leaks) / Double(max(1, negative.count)) * 4 + Double(confidence) - area * 0.35 - fragments)
        }
        return scored.max { $0.1 < $1.1 }?.0
    }

    /// Rank a complete part above a skin/color-only proposal riddled with tiny ink holes.
    /// This does not fill or alter any holes. Large gaps, one or two real holes, and holes
    /// explicitly marked as background receive no fragmentation penalty.
    static func inkHolePenalty(_ mask: [UInt8], width: Int, height: Int, protected: [CGPoint]) -> Double {
        let foreground = mask.filter { $0 >= 128 }.count
        guard foreground > 0 else { return 0 }
        let protectedPixels = Set(protected.map { p in
            min(height - 1, max(0, Int(p.y * CGFloat(height)))) * width + min(width - 1, max(0, Int(p.x * CGFloat(width))))
        })
        var seen = [Bool](repeating: false, count: mask.count), holes = 0
        for start in mask.indices where mask[start] < 128 && !seen[start] {
            var stack = [start], count = 0, exterior = false, marked = false
            seen[start] = true
            while let i = stack.popLast() {
                count += 1; marked = marked || protectedPixels.contains(i)
                let x = i % width, y = i / width
                if x == 0 || y == 0 || x == width - 1 || y == height - 1 { exterior = true }
                for next in [x > 0 ? i - 1 : -1, x + 1 < width ? i + 1 : -1, y > 0 ? i - width : -1, y + 1 < height ? i + width : -1] {
                    if next >= 0, !seen[next], mask[next] < 128 { seen[next] = true; stack.append(next) }
                }
            }
            if !exterior && !marked && count <= max(4, foreground / 20) { holes += 1 }
        }
        return min(1, Double(max(0, holes - 2)) * 2.5 / sqrt(Double(foreground)))
    }

    static func resample(_ bytes: [UInt8], fromWidth: Int, fromHeight: Int, width: Int, height: Int) -> [UInt8] {
        guard fromWidth > 0, fromHeight > 0, bytes.count == fromWidth * fromHeight else { return [] }
        if fromWidth == width && fromHeight == height { return bytes }
        var result = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height { for x in 0..<width {
            let sx = max(0, min(Double(fromWidth - 1), (Double(x) + 0.5) * Double(fromWidth) / Double(width) - 0.5))
            let sy = max(0, min(Double(fromHeight - 1), (Double(y) + 0.5) * Double(fromHeight) / Double(height) - 0.5))
            let x0 = Int(sx), y0 = Int(sy), x1 = min(fromWidth - 1, x0 + 1), y1 = min(fromHeight - 1, y0 + 1)
            let fx = sx - Double(x0), fy = sy - Double(y0)
            let top = Double(bytes[y0 * fromWidth + x0]) * (1 - fx) + Double(bytes[y0 * fromWidth + x1]) * fx
            let bottom = Double(bytes[y1 * fromWidth + x0]) * (1 - fx) + Double(bytes[y1 * fromWidth + x1]) * fx
            result[y * width + x] = UInt8((top * (1 - fy) + bottom * fy).rounded())
        } }
        return result
    }

    /// Explicit paint is a hard constraint. Subtraction never restores a pixel outside the old selection.
    static func combine(region: [UInt8], painted: [UInt8], previous: [UInt8], subtract: Bool) -> [UInt8] {
        guard region.count == painted.count, previous.count == painted.count else { return previous }
        return region.indices.map { i in
            let coverage = max(region[i], painted[i])
            return subtract ? min(previous[i], 255 - coverage) : max(previous[i], coverage)
        }
    }
}
