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
        for (file, name, points) in [
            ("Resources/default-preview.jpg", "anime-hair", [CGPoint(x: 0.4, y: 0.18), CGPoint(x: 0.6, y: 0.20)]),
            ("Resources/default-preview.jpg", "anime-face", [CGPoint(x: 0.46, y: 0.62), CGPoint(x: 0.55, y: 0.72)]),
            ("Tests/Fixtures/segmentation/hokusai.jpg", "manga-left", [CGPoint(x: 0.20, y: 0.31), CGPoint(x: 0.22, y: 0.45)])
        ] {
            let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: file) as CFURL, nil)!
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
            let mask = try await session.region(image: image, points: points, width: image.width, height: image.height)
            let provider = CGDataProvider(data: Data(mask) as CFData)!
            let picture = CGImage(width: image.width, height: image.height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: image.width,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider,
                                  decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
            let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(name + ".png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
            CGImageDestinationAddImage(destination, picture, nil)
            guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
            print("PROBE \(name): \(mask.filter { $0 >= 128 }.count) foreground pixels")
        }
    }
}
