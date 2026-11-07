import XCTest
import CoreText
import Metal
import simd
@testable import AWIeffect

final class Text3DTests: XCTestCase {
    private func glyph(_ character: String, font: String = "Helvetica-Bold", size: Double = 100) throws -> CGGlyph {
        let f = CTFontCreateWithName(font as CFString, CGFloat(size), nil)
        var chars = Array(character.utf16), glyphs = [CGGlyph](repeating: 0, count: chars.count)
        XCTAssertTrue(CTFontGetGlyphsForCharacters(f, &chars, &glyphs, chars.count))
        return try XCTUnwrap(glyphs.first)
    }

    private func triangles(_ mesh: Text3DMesh, _ indices: [UInt32]) -> [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] {
        stride(from: 0, to: indices.count, by: 3).map { t in
            let a = mesh.positions[Int(indices[t])], b = mesh.positions[Int(indices[t + 1])], c = mesh.positions[Int(indices[t + 2])]
            let n = (mesh.normals[Int(indices[t])] + mesh.normals[Int(indices[t + 1])] + mesh.normals[Int(indices[t + 2])]) / 3
            return (a, b, c, n)
        }
    }

    func testMeshHasAllPartsWithOutwardNormals() throws {
        let mesh = try XCTUnwrap(Text3DMesh.mesh(glyph: try glyph("I"), fontName: "Helvetica-Bold", fontSize: 100,
                                                 extrusion: 30, bevelSize: 4, bevelSegments: 4, profile: .round))
        XCTAssertFalse(mesh.front.isEmpty, "front cap"); XCTAssertFalse(mesh.back.isEmpty, "back cap")
        XCTAssertFalse(mesh.side.isEmpty, "sides"); XCTAssertFalse(mesh.bevel.isEmpty, "bevel rings")
        let center = (mesh.bounds.0 + mesh.bounds.1) / 2
        for (a, _, _, n) in triangles(mesh, mesh.front) { XCTAssertGreaterThan(n.z, 0.9); XCTAssertGreaterThan(a.z, 0) }
        for (a, _, _, n) in triangles(mesh, mesh.back) { XCTAssertLessThan(n.z, -0.9); XCTAssertLessThan(a.z, 0) }
        for part in [mesh.front, mesh.back, mesh.bevel, mesh.side] {
            for (a, b, c, n) in triangles(mesh, part) {
                let geometric = simd_cross(b - a, c - a)
                guard simd_length(geometric) > 1e-5 else { continue }
                XCTAssertGreaterThan(simd_dot(simd_normalize(geometric), simd_normalize(n)), 0, "winding agrees with the normal")
            }
        }
        // "I" is a convex bar: side and bevel normals point away from its center.
        for part in [mesh.side, mesh.bevel] {
            for (a, b, c, n) in triangles(mesh, part) {
                let centroid = (a + b + c) / 3
                XCTAssertGreaterThan(simd_dot(SIMD2(centroid.x - center.x, centroid.y - center.y), SIMD2(n.x, n.y)), -1e-3)
            }
        }
    }

    func testGlyphWithHoleTriangulates() throws {
        let mesh = try XCTUnwrap(Text3DMesh.mesh(glyph: try glyph("O"), fontName: "Helvetica-Bold", fontSize: 100,
                                                 extrusion: 20, bevelSize: 0, bevelSegments: 1, profile: .flat))
        XCTAssertTrue(mesh.bevel.isEmpty)
        // Front cap area must be the ring only (outer minus counter), not the full disc.
        var area: Float = 0
        for (a, b, c, _) in triangles(mesh, mesh.front) { area += simd_length(simd_cross(b - a, c - a)) / 2 }
        let w = mesh.bounds.1.x - mesh.bounds.0.x, h = mesh.bounds.1.y - mesh.bounds.0.y
        XCTAssertGreaterThan(area, 0)
        XCTAssertLessThan(area, Float.pi * w * h / 4 * 0.85, "the counter of the O stays open")
    }

    func testOptionsDecodeFromEmptyJSON() throws {
        let o = try JSONDecoder().decode(Text3DOptions.self, from: Data("{}".utf8))
        XCTAssertEqual(o, Text3DOptions())
        let round = try JSONDecoder().decode(Text3DOptions.self, from: JSONEncoder().encode(Text3DOptions(material: .gold)))
        XCTAssertEqual(round.front, Text3DMaterial.gold)
        XCTAssertEqual(Text3DMaterial.presets.count, 7)
    }

    // MARK: Rendering

    private func pixels(_ options: Text3DOptions, text: String = "A") throws -> [UInt8] {
        guard let r = Renderer.shared, let t3 = Text3DRenderer.shared else { throw XCTSkip("SKIP-GPU") }
        let glyphs = Text3DGlyph.line(text, fontName: "Helvetica-Bold", fontSize: 100, unitsPerPoint: 1.0 / 45)
        XCTAssertFalse(glyphs.isEmpty)
        var placement = Text3DRenderer.defaultPlacement()
        // Turn the letter so the bevel and sides catch the light.
        let turn = simd_float4x4(simd_quatf(angle: 0.45, axis: SIMD3(0, 1, 0)) * simd_quatf(angle: 0.25, axis: SIMD3(1, 0, 0)))
        placement.modelToCamera = placement.modelToCamera * turn
        let tex = try XCTUnwrap(t3.render(glyphs: glyphs, options: options, time: 0, placement: placement, size: CGSize(width: 96, height: 96)))
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 96, height: 96, mipmapped: false)
        d.storageMode = .shared
        let read = try XCTUnwrap(r.device.makeTexture(descriptor: d))
        let queue = try XCTUnwrap(r.device.makeCommandQueue()), cb = try XCTUnwrap(queue.makeCommandBuffer())
        let blit = try XCTUnwrap(cb.makeBlitCommandEncoder())
        blit.copy(from: tex, to: read); blit.endEncoding()
        cb.commit(); cb.waitUntilCompleted()
        var bytes = [UInt8](repeating: 0, count: 96 * 96 * 4)
        read.getBytes(&bytes, bytesPerRow: 96 * 4, from: MTLRegionMake2D(0, 0, 96, 96), mipmapLevel: 0)
        return bytes
    }

    private func difference(_ a: [UInt8], _ b: [UInt8]) -> Int { zip(a, b).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) } }

    func testChromeLetterRendersLitAndDiffersFromPlastic() throws {
        let chrome = try pixels(Text3DOptions(material: .chrome))
        var lit = 0
        for i in stride(from: 0, to: chrome.count, by: 4) {
            let brightest: UInt8 = max(chrome[i], max(chrome[i + 1], chrome[i + 2]))
            if chrome[i + 3] > 0 && brightest > 40 { lit += 1 }
        }
        XCTAssertGreaterThan(lit, 100, "the chrome A shows lit pixels")
        let plastic = try pixels(Text3DOptions(material: .plastic))
        XCTAssertGreaterThan(difference(chrome, plastic), 96 * 96 * 2, "chrome and plastic look different")
    }

    func testBevelChangesTheLetter() throws {
        let none = try pixels(Text3DOptions(material: .gold, bevelSize: 0))
        let deep = try pixels(Text3DOptions(material: .gold, bevelSize: 10))
        XCTAssertGreaterThan(difference(none, deep), 1000, "bevel 10 changes the rendered edges")
    }
}
