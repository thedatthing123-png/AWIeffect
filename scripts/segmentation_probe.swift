import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

@main struct SegmentationProbe {
    static func main() async throws {
        let models = URL(fileURLWithPath: CommandLine.arguments[1])
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let session = InteractiveSelection(modelDirectory: models)
        let inspector = try PromptSegmentationModel(modelDirectory: models)
        var lastFile = ""
        for (file, name, points) in [
            ("Resources/default-preview.jpg", "anime-hair", [CGPoint(x: 0.4, y: 0.18), CGPoint(x: 0.6, y: 0.20)]),
            ("Resources/default-preview.jpg", "anime-face", [CGPoint(x: 0.46, y: 0.62), CGPoint(x: 0.55, y: 0.72)]),
            ("Resources/default-preview.jpg", "anime-face-one", [CGPoint(x: 0.50, y: 0.65)]),
            ("Resources/default-preview.jpg", "anime-hair-one", [CGPoint(x: 0.50, y: 0.20)]),
            ("Tests/Fixtures/segmentation/hokusai.jpg", "manga-left", [CGPoint(x: 0.20, y: 0.31), CGPoint(x: 0.22, y: 0.45)])
        ] {
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            if file != lastFile { try inspector.setImage(image); lastFile = file }
            for (index, candidate) in try inspector.predict(points.map { SegmentationPrompt(point: $0, positive: true) }).enumerated() {
                let expanded = InteractiveSelection.resample(candidate.bytes, fromWidth: candidate.width, fromHeight: candidate.height, width: image.width, height: image.height)
                try save(InteractiveSelection.fitEdge(expanded, tolerance: 0.18), width: image.width, height: image.height,
                         to: output.appendingPathComponent(name + "-candidate-\(index)-\(candidate.score).png"))
            }
            let mask = try await session.region(image: image, points: points, width: image.width, height: image.height)
            try save(mask, width: image.width, height: image.height, to: output.appendingPathComponent(name + ".png"))
            print("PROBE \(name): \(mask.filter { $0 >= 128 }.count) foreground pixels")
            if name == "anime-face" {
                var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
                let context = CGContext(data: &rgba, width: image.width, height: image.height, bitsPerComponent: 8,
                                        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
                var ink = 0, retained = 0
                for y in 780..<920 { for x in 480..<700 {
                    let i = y * image.width + x, p = i * 4
                    if max(rgba[p], max(rgba[p + 1], rgba[p + 2])) < 95 {
                        ink += 1; if mask[i] >= 128 { retained += 1 }
                    }
                } }
                let coverage = Double(retained) / Double(max(1, ink))
                print("PROBE internal ink coverage: \(coverage)")
                guard ink > 100, coverage > 0.95 else { throw InteractiveSelection.SelectionError.modelOutput("Internal ink coverage \(coverage)") }
            }
        }
    }
    static func save(_ mask: [UInt8], width: Int, height: Int, to url: URL) throws {
        let provider = CGDataProvider(data: Data(mask) as CFData)!
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                            decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
