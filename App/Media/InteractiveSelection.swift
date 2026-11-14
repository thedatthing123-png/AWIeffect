import Foundation
import CoreGraphics
import CryptoKit
import SAMKit

/// One image embedding per open tool, reused as selection strokes change. All Core ML work
/// stays on this actor, never in the drawing gesture or the main-actor view model.
actor InteractiveSelection {
    private var session: SamSession?
    private var imageKey: Data?

    func region(image: CGImage, points: [CGPoint], width: Int, height: Int, negative: [CGPoint] = []) throws -> [UInt8] {
        try Task.checkCancellation()
        guard !points.isEmpty, width > 0, height > 0,
              let data = image.dataProvider?.data else { throw SelectionError.invalidImage }
        var hasher = SHA256()
        hasher.update(data: data as Data)
        hasher.update(data: Data("\(image.width)x\(image.height):\(image.bytesPerRow)".utf8))
        let key = Data(hasher.finalize())
        if session == nil { session = try SamSession(model: .bundled(.mobileSam)) }
        guard let session else { throw SelectionError.invalidImage }
        if key != imageKey {
            try session.setImage(image)
            imageKey = key
        }
        try Task.checkCancellation()
        let negativeSamples = Self.samples(negative, limit: 5)
        let samples = Self.samples(points, limit: PromptEncoder.maxPoints - negativeSamples.count)
        let prompts = samples.map { SamPoint(x: $0.x * CGFloat(image.width), y: $0.y * CGFloat(image.height), label: .positive) }
            + negativeSamples.map { SamPoint(x: $0.x * CGFloat(image.width), y: $0.y * CGFloat(image.height), label: .negative) }
        let result = try session.predict(points: prompts, options: SamOptions(multimaskOutput: true, maxMasks: 3))
        try Task.checkCancellation()
        let candidates = result.masks.map { mask in
            (Self.resample(Array(mask.alpha), fromWidth: mask.width, fromHeight: mask.height, width: width, height: height), mask.score)
        }
        guard let chosen = Self.choose(candidates, points: samples, width: width, height: height, negative: negativeSamples) else {
            throw SelectionError.noRegion
        }
        return chosen
    }

    func selection(image: CGImage, points: [CGPoint], width: Int, height: Int,
                   painted: [UInt8], previous: [UInt8], subtract: Bool) throws -> [UInt8] {
        // Remove strokes are negative prompts on the existing selection, with positive anchors
        // in its retained interior. This lets a correction exclude one limb without erasing
        // the enclosing character simply because SAM also offered a whole-character mask.
        let anchors = subtract ? Self.anchors(previous, width: width, height: height, avoiding: points) : []
        if subtract, !anchors.isEmpty {
            let refined = try region(image: image, points: anchors, width: width, height: height, negative: points)
            return previous.indices.map { min(previous[$0], min(refined[$0], 255 - painted[$0])) }
        }
        let inferred = try region(image: image, points: points, width: width, height: height)
        return Self.combine(region: inferred, painted: painted, previous: previous, subtract: subtract)
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
        case invalidImage, noRegion
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
            return (mask, Double(covered) / Double(points.count) * 4 - Double(leaks) / Double(max(1, negative.count)) * 4 + Double(confidence) - area * 0.2)
        }
        return scored.max { $0.1 < $1.1 }?.0
    }

    static func resample(_ bytes: [UInt8], fromWidth: Int, fromHeight: Int, width: Int, height: Int) -> [UInt8] {
        guard fromWidth > 0, fromHeight > 0, bytes.count == fromWidth * fromHeight else { return [] }
        if fromWidth == width && fromHeight == height { return bytes }
        var result = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height { for x in 0..<width {
            // SAMKit removes padding and returns top-down alpha at resized image resolution.
            let sx = min(fromWidth - 1, x * fromWidth / width), sy = min(fromHeight - 1, y * fromHeight / height)
            result[y * width + x] = bytes[sy * fromWidth + sx]
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
