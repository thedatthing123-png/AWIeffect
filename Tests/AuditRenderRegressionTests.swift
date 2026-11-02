import XCTest
import Metal
import UIKit
@testable import AWIeffect

final class AuditRenderRegressionTests: XCTestCase {
    private func renderer() throws -> Renderer {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        return r
    }
    private func cube(domain: String = "") -> String {
        var text = "TITLE \"Audit\"\nLUT_3D_SIZE\t2\n" + domain
        for b in 0...1 { for g in 0...1 { for r in 0...1 { text += "\(r)\t\(g) \(b) # entry\n" } } }
        return text
    }
    func testCubeWhitespaceDomainAndNonfiniteValidation() throws {
        let (n, identity) = try LUTLibrary.parse(cube())
        XCTAssertEqual(n, 2); XCTAssertEqual(Array(identity.suffix(3)), [1, 1, 1])
        let (_, domain) = try LUTLibrary.parse(cube(domain: "DOMAIN_MIN 0 0 0\nDOMAIN_MAX 2 2 2\n"))
        XCTAssertEqual(Array(domain.suffix(3)), [0.5, 0.5, 0.5])
        XCTAssertThrowsError(try LUTLibrary.parse(cube().replacingOccurrences(of: "0\t0 0", with: "nan 0 0")))
        XCTAssertThrowsError(try LUTLibrary.parse(cube(domain: "DOMAIN_MIN 1 1 1\nDOMAIN_MAX 0 0 0\n")))
    }
    func testBadLUTReplacementKeepsExistingFile() throws {
        let name = UUID().uuidString + ".cube"
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let dest = LUTLibrary.folder.appendingPathComponent(name)
        defer { try? FileManager.default.removeItem(at: source); LUTLibrary.shared.remove(name) }
        try cube().write(to: source, atomically: true, encoding: .utf8)
        try LUTLibrary.shared.importFile(source)
        let before = try Data(contentsOf: dest)
        try "invalid".write(to: source, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try LUTLibrary.shared.importFile(source))
        XCTAssertEqual(try Data(contentsOf: dest), before)
        // Reimporting the library file itself must also be safe.
        try LUTLibrary.shared.importFile(dest)
        XCTAssertEqual(try Data(contentsOf: dest), before)
    }
    func testMalformedPackageLengthsThrowInsteadOfTrapping() {
        var data = Data(ProjectPackage.magic)
        data.append(contentsOf: [1, 0, 0, 0, 1, 0, 0, 0, 97])
        data.append(contentsOf: [UInt8](repeating: 255, count: 8))
        XCTAssertThrowsError(try ProjectPackage.importPackage(data))
    }
    func testPackageStreamsMediaAndRoundTripsWithoutOverwritingSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectStore(root: root)
        let p = Project.new(name: "package", width: 100, height: 100, fps: 30, duration: 1, background: .black)
        let data = Data((0..<2_100_000).map { UInt8($0 % 251) })
        let file = try store.importMedia(data: data, ext: "bin", into: p.id)
        try store.save(p)
        let url = try ProjectPackage.export(p, store: store)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let imported = try ProjectPackage.importPackage(Data(contentsOf: url, options: .mappedIfSafe), store: store)
        XCTAssertNotEqual(imported.id, p.id)
        XCTAssertEqual(try Data(contentsOf: store.mediaURL(file, projectID: imported.id)), data)
        XCTAssertEqual(try store.load(p.id).id, p.id)
    }
    func testTexturePoolSeparatesFormatsAndInFlightTargets() throws {
        let r = try renderer(), pool = TexturePool(device: r.device)
        let a = pool.acquire(width: 64, height: 64, format: .bgra8Unorm)
        let b = pool.acquire(width: 64, height: 64, format: .bgra8Unorm)
        XCTAssertFalse(a === b)
        pool.recycle()
        XCTAssertEqual(pool.acquire(width: 64, height: 64).pixelFormat, .rgba16Float)
        XCTAssertEqual(pool.acquire(width: 64, height: 64, format: .bgra8Unorm).pixelFormat, .bgra8Unorm)
    }
    func testPortraitModelCameraFitsBoundingSphere() {
        let radius = 1.4
        for aspect in [0.3, 1.0, 3.0] {
            let distance = ModelRenderer.cameraDistance(radius: radius, aspect: aspect)
            let halfFOV = min(35 * Double.pi / 360, atan(tan(35 * Double.pi / 360) * aspect))
            XCTAssertGreaterThan(distance * sin(halfFOV), radius)
        }
    }
    func testPageCurlEndpointsAndNoShadowFromTransparentPixels() throws {
        let r = try renderer()
        var p = Project.new(name: "curl", width: 64, height: 64, fps: 30, duration: 1, background: RGBA(0, 0, 0, 0))
        var layer = p.makeLayer(name: "paper", content: .solid, size: Vec2(64, 64))
        layer.fill = Animated(.white)
        var effect = EffectRegistry.pageCurl14.makeInstance()
        effect.params["progress"] = .number(Animated(0)); layer.effects = [effect]; p.layers = [layer]
        func pixels() throws -> [UInt8] { try XCTUnwrap(r.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba }
        XCTAssertGreaterThan(try pixels()[(32 * 64 + 32) * 4 + 3], 250)
        p.layers[0].effects[0].params["progress"] = .number(Animated(100))
        XCTAssertTrue(try pixels().enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 0 })
        p.layers[0].effects[0].params["progress"] = .number(Animated(46))
        p.layers[0].fill = Animated(RGBA(0, 0, 0, 0))
        XCTAssertTrue(try pixels().allSatisfy { $0 == 0 }, "Curl must not invent a gray shadow over empty pixels")
    }
    func testAdjustmentGrainPreservesBackdropAndAlpha() throws {
        let r = try renderer()
        var p = Project.new(name: "grain", width: 64, height: 64, fps: 30, duration: 1, background: RGBA(1, 0, 0, 1))
        var layer = p.makeLayer(name: "grain", content: .adjustment, size: Vec2(64, 64))
        layer.effects = [EffectRegistry.grain.makeInstance()]; p.layers = [layer]
        let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        let i = (32 * 64 + 32) * 4
        XCTAssertGreaterThan(Int(px[i]) - Int(px[i + 1]), 150, "Grain replaced red backdrop with gray")
        XCTAssertEqual(px[i + 3], 255)
        p.background = RGBA(0, 0, 0, 0)
        let empty = try XCTUnwrap(r.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertTrue(empty.enumerated().filter { $0.offset % 4 == 3 }.allSatisfy { $0.element == 0 })
    }
    func testMotionTileRepeatsWholeImageBeyondOriginalLayerBounds() throws {
        let r = try renderer()
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 64))
            UIColor.blue.setFill(); context.fill(CGRect(x: 32, y: 0, width: 32, height: 64))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTUnwrap(image.pngData()).write(to: url)
        var p = Project.new(name: "tiles", width: 128, height: 128, fps: 30, duration: 1, background: .black)
        var l = p.makeLayer(name: "image", content: .image(fileName: "test.png", pixelWidth: 64, pixelHeight: 64), size: Vec2(64, 64))
        var effect = EffectRegistry.motionTile.makeInstance()
        for key in ["tileW", "tileH"] { effect.params[key] = .number(Animated(50)) }
        for key in ["outW", "outH"] { effect.params[key] = .number(Animated(400)) }
        effect.params["mirror"] = .toggle(false); l.effects = [effect]; p.layers = [l]
        let pixels = try XCTUnwrap(r.renderPixels(project: p, time: 0, mediaURL: { _ in url })).rgba
        // Each 32px tile must contain BOTH halves of the source, including outside its original 32...96 bounds.
        for start in [16, 48, 80] {
            let left = (64 * 128 + start + 8) * 4, right = (64 * 128 + start + 24) * 4
            XCTAssertGreaterThan(pixels[left], 220, "Missing red half at \(start)")
            XCTAssertGreaterThan(pixels[right + 2], 220, "Missing blue half at \(start)")
        }
    }

    func testPackageRenamesConflictingLUTAndRelinksNestedComp() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectStore(root: root), name = UUID().uuidString + ".cube"
        let old = Data(cube().utf8), newer = Data(cube().replacingOccurrences(of: "1\t1 1", with: "0.8 0.8 0.8").utf8)
        try LUTLibrary.shared.importData(old, named: name)
        var p = Project.new(name: "LUT", width: 16, height: 16, fps: 30, duration: 1, background: .black)
        var child = p
        var layer = child.makeLayer(name: "grade", content: .solid, size: Vec2(16, 16))
        var effect = EffectRegistry.grade.makeInstance(); effect.text = ["lut": name]
        layer.effects = [effect]; child.layers = [layer]; p.precomps = [child]
        try store.save(p)
        let package = try ProjectPackage.export(p, store: store)
        defer { try? FileManager.default.removeItem(at: package.deletingLastPathComponent()); LUTLibrary.shared.remove(name) }
        try LUTLibrary.shared.importData(newer, named: name)
        let imported = try ProjectPackage.importPackage(Data(contentsOf: package), store: store)
        let importedName = try XCTUnwrap(imported.precomps.first?.layers.first?.effects.first?.text?["lut"])
        defer { LUTLibrary.shared.remove(importedName) }
        XCTAssertNotEqual(importedName, name)
        XCTAssertEqual(try Data(contentsOf: LUTLibrary.folder.appendingPathComponent(name)), newer)
        XCTAssertEqual(try Data(contentsOf: LUTLibrary.folder.appendingPathComponent(importedName)), old)
    }

    func testBackdropDisplacementMovesSceneAndDoesNotDuplicateAlpha() throws {
        let r = try renderer()
        var p = Project.new(name: "displace", width: 64, height: 64, fps: 30, duration: 1, background: RGBA(0, 0, 0, 0))
        var map = p.makeLayer(name: "map", content: .solid, size: Vec2(64, 64))
        map.fill = Animated(.white)
        var effect = EffectRegistry.displacementMap18.makeInstance()
        effect.params["target"] = .choice(1); effect.params["h"] = .number(Animated(16))
        map.effects = [effect]
        var red = p.makeLayer(name: "red", content: .solid, size: Vec2(16, 64))
        red.fill = Animated(RGBA(1, 0, 0, 0.5)); red.transform.position = Animated(Vec2(40, 32))
        p.layers = [map, red]
        func pixels() throws -> [UInt8] { try XCTUnwrap(r.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba }
        let displaced = try pixels()
        XCTAssertGreaterThan(displaced[(32 * 64 + 24) * 4], 240, "Backdrop did not move under the map")
        XCTAssertEqual(Double(displaced[(32 * 64 + 24) * 4 + 3]), 128, accuracy: 3)
        XCTAssertLessThan(displaced[(32 * 64 + 40) * 4 + 3], 3, "Original backdrop was alpha-overlaid instead of replaced")
        // Neutral map / zero offset must be an exact alpha-preserving identity.
        p.layers[0].effects[0].params["h"] = .number(Animated(0))
        let identity = try pixels()
        XCTAssertEqual(Double(identity[(32 * 64 + 40) * 4 + 3]), 128, accuracy: 3)
        XCTAssertEqual(identity[(32 * 64 + 24) * 4 + 3], 0)
    }

    func testBlackOpaqueImageExtrusionUsesAlphaAndPreservesHole() throws {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64), format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(x: 16, y: 16, width: 32, height: 32))
            context.cgContext.clear(CGRect(x: 28, y: 28, width: 8, height: 8))
        }
        let result = try XCTUnwrap(Extrude3D.alphaOutline(try XCTUnwrap(image.cgImage)))
        XCTAssertTrue(result.path.contains(CGPoint(x: 10, y: 10)), "Opaque black was treated as empty")
        XCTAssertFalse(result.path.contains(.zero), "The alpha hole was filled")
        XCTAssertEqual(result.crop.width, 32, accuracy: 1)
    }
    func testModelMaterialsAndTargetsRemainIndependentWithinFrame() throws {
        let r = try renderer(), pool = TexturePool(device: try renderer().device)
        let command = try XCTUnwrap(r.queue.makeCommandBuffer())
        var options = Model3DOptions(); options.text = "I"; options.yaw = Animated(0); options.pitch = Animated(0)
        options.color = Animated(RGBA(1, 0, 0)); options.metalness = 0
        let models = ModelRenderer(device: r.device)
        let a = try XCTUnwrap(models.render(options, time: 0, width: 64, height: 64, cb: command, pool: pool, mediaURL: { URL(fileURLWithPath: $0) }))
        options.color = Animated(RGBA(0, 1, 0))
        let b = try XCTUnwrap(models.render(options, time: 0, width: 64, height: 64, cb: command, pool: pool, mediaURL: { URL(fileURLWithPath: $0) }))
        XCTAssertFalse(a === b)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 64, height: 64, mipmapped: false)
        descriptor.storageMode = .shared
        let readA = try XCTUnwrap(r.device.makeTexture(descriptor: descriptor)), readB = try XCTUnwrap(r.device.makeTexture(descriptor: descriptor))
        let blit = try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from: a, to: readA); blit.copy(from: b, to: readB); blit.endEncoding()
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(command.status, .completed)
        func channels(_ texture: MTLTexture) -> [Int] {
            var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
            texture.getBytes(&bytes, bytesPerRow: 256, from: MTLRegionMake2D(0, 0, 64, 64), mipmapLevel: 0)
            return (0..<3).map { channel in stride(from: channel, to: bytes.count, by: 4).reduce(0) { $0 + Int(bytes[$1]) } }
        }
        let red = channels(readA), green = channels(readB)
        print("AUDIT-MODEL BGRA red=\(red) green=\(green)")
        XCTAssertGreaterThan(red[2], red[1] + 1000)
        XCTAssertGreaterThan(green[1], green[2] + 1000)
    }

    func testBackdropDisplacementEdgeModesHaveDistinctDefinedResults() throws {
        let r = try renderer()
        var p = Project.new(name: "edges", width: 64, height: 64, fps: 30, duration: 1, background: RGBA(0, 0, 0, 0))
        var map = p.makeLayer(name: "map", content: .solid, size: Vec2(64, 64)); map.fill = Animated(.white)
        var effect = EffectRegistry.displacementMap18.makeInstance(); effect.params["target"] = .choice(1); effect.params["h"] = .number(Animated(80)); map.effects = [effect]
        var left = p.makeLayer(name: "left", content: .solid, size: Vec2(32, 64)); left.fill = Animated(RGBA(1, 0, 0)); left.transform.position = Animated(Vec2(16, 32))
        var right = left; right.id = UUID(); right.fill = Animated(RGBA(0, 0, 1)); right.transform.position = Animated(Vec2(48, 32))
        p.layers = [map, left, right]
        var colors: [[Int]] = []
        for mode in 0..<4 {
            p.layers[0].effects[0].params["edges"] = .choice(mode)
            let px = try XCTUnwrap(r.renderPixels(project: p, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
            colors.append([0, 32].map { x in
                let i = (32 * 64 + x) * 4
                if px[i + 3] < 10 { return -1 }
                return px[i] > px[i + 2] ? 0 : 1 // red=0, blue=1
            })
        }
        XCTAssertEqual(colors, [[1, 1], [1, 0], [-1, -1], [0, 1]])
    }

}
