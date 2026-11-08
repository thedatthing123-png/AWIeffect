import XCTest
import simd
import Metal
@testable import AWIeffect

final class BoneMeshTests: XCTestCase {
    private func translation(_ x: Double, _ y: Double) -> simd_double3x3 {
        simd_double3x3(columns: (SIMD3(1,0,0), SIMD3(0,1,0), SIMD3(x,y,1)))
    }
    private func mesh() throws -> BoneMeshBinding {
        try XCTUnwrap(BoneMeshBinding.bind(halfSize: Vec2(100,100), detail: 8,
            bones: [BoneMeshSource(id: UUID(), matrix: matrix_identity_double3x3, tip: Vec2(80,0))]))
    }

    func testRestMeshAndTopologyAreAnExactIdentity() throws {
        let mesh = try mesh()
        XCTAssertTrue(mesh.isValid)
        XCTAssertEqual(mesh.vertices.count, 81)
        XCTAssertEqual(mesh.indices.count, 8*8*6)
        for vertex in mesh.vertices { XCTAssertEqual(mesh.deformed(vertex, matrices: [.identity]), vertex.rest) }
    }

    func testWeightsAreNormalizedDeterministicAndLimitedToFourBones() throws {
        let bones = (0..<8).map { BoneMeshSource(id: UUID(), matrix: translation(Double($0*10),0), tip: Vec2(0,80)) }
        let a = try XCTUnwrap(BoneMeshBinding.bind(halfSize: Vec2(100,100), detail: 8, bones: bones))
        let b = try XCTUnwrap(BoneMeshBinding.bind(halfSize: Vec2(100,100), detail: 8, bones: bones))
        XCTAssertEqual(a.vertices, b.vertices)
        for vertex in a.vertices {
            XCTAssertEqual(vertex.weights.count, 4)
            XCTAssertEqual(vertex.weights.reduce(0, { $0+$1.amount }), 1, accuracy: 1e-12)
            XCTAssertTrue(vertex.weights.allSatisfy { $0.amount >= 0 })
        }
    }

    func testForwardSkinningBlendsActualTransforms() throws {
        let mesh = try mesh()
        let vertex = BoneMeshVertex(rest: Vec2(10,0), weights: [BoneMeshWeight(bone: 0,amount: 0.25), BoneMeshWeight(bone: 1,amount: 0.75)])
        let actual = mesh.deformed(vertex, matrices: [.identity, RigAffine(translation(20,0))])
        XCTAssertEqual(actual, Vec2(25,0))
        let rotation = simd_double3x3(columns: (SIMD3(0,1,0), SIMD3(-1,0,0), SIMD3(0,0,1)))
        XCTAssertEqual(mesh.deformed(BoneMeshVertex(rest: Vec2(10,0), weights: [BoneMeshWeight(bone: 0,amount: 1)]), matrices: [RigAffine(rotation)]), Vec2(0,10))
    }

    func testFramePalettesAreNotSavedAsEditableProjectData() throws {
        var original = try mesh()
        original.frameMatrices = [RigAffine(translation(20,30))]; original.frameTime = 12
        let data = try JSONEncoder().encode(original)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("frameMatrices")); XCTAssertFalse(json.contains("frameTime")); XCTAssertFalse(json.contains("frameSource"))
        let copy = try JSONDecoder().decode(BoneMeshBinding.self, from: data)
        XCTAssertEqual(copy, original)
        XCTAssertNil(copy.frameMatrices)
    }

    func testPaintingNormalizesWeightsAndPreservesLockedInfluences() throws {
        let sources = (0..<3).map { _ in BoneMeshSource(id: UUID(),matrix: matrix_identity_double3x3,tip: Vec2(80,0)) }
        var mesh = try XCTUnwrap(BoneMeshBinding.bind(halfSize: Vec2(100,100),detail: 8,bones: sources))
        let original = mesh.vertices
        mesh.lockedBoneIDs = [sources[2].id]
        XCTAssertTrue(mesh.paint([BoneWeightDab(center: .zero,amount: 0.9)],selected: 0,radius: 100,mode: .paint))
        for (before,after) in zip(original,mesh.vertices) {
            XCTAssertEqual(before.weights.first { $0.bone == 2 }?.amount,after.weights.first { $0.bone == 2 }?.amount)
            XCTAssertEqual(after.weights.reduce(0) { $0+$1.amount },1,accuracy: 1e-12)
        }
        XCTAssertFalse(mesh.paint([BoneWeightDab(center: .zero,amount: 1)],selected: 2,radius: 100,mode: .erase))
        XCTAssertTrue(mesh.isValid)
        _ = mesh.paint([BoneWeightDab(center: .zero,amount: 0.5)],selected: 0,radius: 100,mode: .smooth)
        _ = mesh.paint([BoneWeightDab(center: .zero,amount: 0.8)],selected: 0,radius: 100,mode: .erase)
        XCTAssertTrue(mesh.isValid)
        for vertex in mesh.vertices { XCTAssertEqual(vertex.weights.reduce(0) { $0+$1.amount },1,accuracy: 1e-12) }
    }

    func testMetalSkinningMovesPixelsAndRefreshesImportedWeights() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 64, height: 64, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let input = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let output = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        let pixels = (0..<64*64).flatMap { _ in [Float16(1),Float16(0.5),Float16(0),Float16(1)] }
        pixels.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0,0,64,64), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 64*8) }
        let sources = (0..<2).map { _ in BoneMeshSource(id: UUID(), matrix: matrix_identity_double3x3, tip: Vec2(20,0)) }
        let original = try XCTUnwrap(BoneMeshBinding.bind(halfSize: Vec2(32,32), detail: 8, bones: sources))
        let matrices: [RigAffine] = [.identity, RigAffine(translation(16,0))]
        func render(_ mesh: BoneMeshBinding) throws -> [Float16] {
            let cb = try XCTUnwrap(queue.makeCommandBuffer())
            XCTAssertTrue(BoneMeshGPU.encode(mesh, matrices: matrices, input: input, output: output, unit: 1, commandBuffer: cb, device: device))
            cb.commit(); cb.waitUntilCompleted()
            XCTAssertEqual(cb.status, .completed)
            var bytes = [Float16](repeating: 0, count: 64*64*4)
            bytes.withUnsafeMutableBytes { output.getBytes($0.baseAddress!, bytesPerRow: 64*8, from: MTLRegionMake2D(0,0,64,64), mipmapLevel: 0) }
            return bytes
        }
        let first = try render(original)
        XCTAssertEqual(Float(first[(32*64+12)*4+3]), 1, accuracy: 0.001)
        XCTAssertEqual(Float(first[(32*64+2)*4+3]), 0, accuracy: 0.001)
        var imported = try JSONDecoder().decode(BoneMeshBinding.self, from: JSONEncoder().encode(original))
        for i in imported.vertices.indices { imported.vertices[i].weights = [BoneMeshWeight(bone: 1,amount: 1)] }
        XCTAssertEqual(imported.revision, original.revision)
        let second = try render(imported)
        XCTAssertEqual(Float(second[(32*64+12)*4+3]), 0, accuracy: 0.001, "Imported weights must not reuse stale cached vertex buffers")
        XCTAssertEqual(Float(second[(32*64+24)*4]), 1, accuracy: 0.001)
    }

    func testMalformedWeightsAndIndicesAreRejected() throws {
        var mesh = try mesh()
        mesh.vertices[0].weights[0].amount = .nan
        XCTAssertFalse(mesh.isValid)
        mesh.vertices[0].weights[0].amount = 1
        mesh.indices[0] = UInt32.max
        XCTAssertFalse(mesh.isValid)
        XCTAssertNil(BoneMeshBinding.bind(halfSize: .zero, detail: 8, bones: []))
    }
}
