import UIKit
import XCTest
@testable import AWIeffect

final class RelightStudioTests: XCTestCase {
    private let width = 160
    private let height = 112

    private func fixture(in folder: URL) throws -> Project {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func write(_ name: String, pixel: (Double, Double) -> SIMD3<Double>) throws {
            var data: [UInt8] = []
            data.reserveCapacity(width * height * 4)
            for y in 0..<height {
                for x in 0..<width {
                    let c = pixel((Double(x) + 0.5) / Double(width), (Double(y) + 0.5) / Double(height))
                    func byte(_ n: Double) -> UInt8 { UInt8((255 * min(1, max(0, n))).rounded()) }
                    data += [byte(c.x), byte(c.y), byte(c.z), 255]
                }
            }
            let provider = try XCTUnwrap(CGDataProvider(data: Data(data) as CFData))
            let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                             bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                             bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                                             decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            try XCTUnwrap(UIImage(cgImage: image).pngData()).write(to: folder.appendingPathComponent(name))
        }

        func field(_ x: Double, _ y: Double) -> Double {
            func dome(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Double {
                let r = pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2)
                return max(0, 1 - r)
            }
            let palm = dome(0.46, 0.60, 0.25, 0.31)
            let index = dome(0.64, 0.37, 0.09, 0.28)
            let middle = dome(0.51, 0.32, 0.09, 0.28)
            let ring = dome(0.375, 0.34, 0.085, 0.24)
            let thumb = dome(0.70, 0.62, 0.17, 0.10)
            return min(1, palm * 0.60 + index * 0.46 + middle * 0.55 + ring * 0.4 + thumb * 0.42)
        }

        try write("plate.png") { _, _ in SIMD3(0.68, 0.31, 0.20) }
        try write("base.png") { x, y in
            let crease = y > 0.45 && abs(y - (0.48 + (x - 0.47) * 0.6)) < 0.012
            return crease ? SIMD3(0.29, 0.10, 0.14) : SIMD3(0.75, 0.40, 0.27)
        }
        try write("alpha.png") { x, y in SIMD3(repeating: min(1, field(x, y) * 55)) }
        try write("depth.png") { x, y in SIMD3(repeating: field(x, y)) }
        try write("normal.png") { x, y in
            let d = 0.004
            let nx = (field(x - d, y) - field(x + d, y)) * 35
            let ny = (field(x, y + d) - field(x, y - d)) * 40
            let norm = sqrt(nx * nx + ny * ny + 1)
            return SIMD3(0.5 + nx / norm * 0.5, 0.5 + ny / norm * 0.5, 0.5 + 0.5 / norm)
        }

        var project = Project.new(name: "Relight pass review", width: 200, height: 140, fps: 30, duration: 1.6, background: RGBA(0, 0, 0, 0))
        var layer = project.makeLayer(name: "Relief", content: .image(fileName: "plate.png", pixelWidth: width, pixelHeight: height),
                                      size: Vec2(Double(width), Double(height)))
        var material = RelightSurface()
        for (pass, name) in [(RelightPass.baseColor, "base.png"), (.alpha, "alpha.png"), (.normal, "normal.png"), (.depth, "depth.png")] {
            material.maps[pass] = RelightMedia(file: name, name: name, isVideo: false)
        }
        material.depth = 25
        layer.relight = material
        var light = project.makeLayer(name: "Blue sweep", content: .light, size: Vec2(1, 1))
        light.light = LightOptions(type: .point, color: Animated(RGBA(0.42, 0.70, 1)), intensity: Animated(200))
        light.transform.positionZ = Animated(-48)
        light.transform.position.keyframes = [Keyframe(time: 0, value: Vec2(21, 51), interpolation: .bezier),
                                              Keyframe(time: 1.5, value: Vec2(180, 79))]
        var bounce = project.makeLayer(name: "Fill", content: .light, size: Vec2(1, 1))
        bounce.light = LightOptions(type: .ambient, color: Animated(RGBA(1, 0.85, 0.82)), intensity: Animated(27))
        project.layers = [light, bounce, layer]
        return project
    }

    @MainActor
    func testImportedReliefRespondsToTheSceneLightAndPreservesAlpha() async throws {
        guard let render = Renderer.shared else { throw XCTSkip("Metal unavailable") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("relight-tests-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var project = try fixture(in: root)
        let media: (String) -> URL = { root.appendingPathComponent($0) }
        func pixels(_ project: Project, at time: Double) throws -> [UInt8] {
            try XCTUnwrap(render.renderPixels(project: project, time: time, preserveAlpha: true, mediaURL: media)).rgba
        }
        func difference(_ a: [UInt8], _ b: [UInt8]) -> Double {
            zip(a, b).reduce(0.0) { $0 + Double(abs(Int($1.0) - Int($1.1))) } / Double(a.count)
        }
        let early = try pixels(project, at: 0.25)
        let late = try pixels(project, at: 1.25)
        XCTAssertGreaterThan(difference(early, late), 1)
        XCTAssertEqual(early[(30 * 200 + 24) * 4 + 3], 0)
        XCTAssertGreaterThan(early[(85 * 200 + 95) * 4 + 3], 240)
        XCTAssertEqual(stride(from: 3, to: early.count, by: 4).filter { early[$0] != late[$0] }.count, 0)
        var withoutNormals = project
        withoutNormals.layers[2].relight?.maps[.normal] = nil
        XCTAssertGreaterThan(difference(early, try pixels(withoutNormals, at: 0.25)), 0.15)
        var withoutDepth = project
        withoutDepth.layers[2].relight?.depth = 0
        XCTAssertGreaterThan(difference(early, try pixels(withoutDepth, at: 0.25)), 0.10)

        let output = URL(fileURLWithPath: "/tmp/awi-authoring/relight-studio", isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        project.background = RGBA(0.16, 0.13, 0.18)
        for (i, time) in [0.12, 0.42, 0.78, 1.12, 1.45].enumerated() {
            let shot = try XCTUnwrap(render.renderImage(project: project, time: time, maxDimension: 200, mediaURL: media))
            try XCTUnwrap(shot.pngData()).write(to: output.appendingPathComponent("relight-\(i).png"))
        }
        let video = try await Exporter().export(project: project, settings: ExportSettings(format: .mp4), mediaURL: media) { _ in }
        defer { try? FileManager.default.removeItem(at: video) }
        try Data(contentsOf: video).write(to: output.appendingPathComponent("blue-light-sweep.mp4"), options: .atomic)
    }

    func testRelightMapsSurviveProjectCodingAndClipboardTransfer() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("relight-clipboard-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = try fixture(in: root)
        let restored = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(project.layers[2].relight, restored.layers[2].relight)
        let original = restored.layers[2]
        let payload = try LayerClipboardFiles.snapshot(layers: [original], precomps: [], source: root)
        let destination = root.appendingPathComponent("pasted", isDirectory: true)
        let pasted = try XCTUnwrap(LayerClipboardFiles.imported(payload, destination: destination).layers.first)
        for pass in RelightPass.allCases {
            let old = try XCTUnwrap(original.relight?.maps[pass])
            let new = try XCTUnwrap(pasted.relight?.maps[pass])
            XCTAssertNotEqual(old.file, new.file)
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(old.file)), try Data(contentsOf: destination.appendingPathComponent(new.file)))
        }
    }
}
