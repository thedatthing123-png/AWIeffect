import XCTest
import SceneKit
@testable import AWIeffect

final class PriorityEditingTests: XCTestCase {
    private func scene() -> Project {
        var project = Project.new(name: "editing", width: 128, height: 128, fps: 30, duration: 3, background: RGBA(0,0,0,0))
        var first = project.makeLayer(name: "first", content: .solid, size: Vec2(20,20))
        first.transform.position = Animated(Vec2(40,64)); first.fill = Animated(.white)
        var second = first; second.id = UUID(); second.name = "second"; second.transform.position = Animated(Vec2(80,64))
        project.layers = [first,second]; return project
    }
    @MainActor private func editor(_ project: Project) -> EditorState {
        EditorState(project: project, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }

    @MainActor func testMultiScaleResizesBothLayersAndTheirSpacing() {
        let state = editor(scene())
        state.selectedLayerID = state.project.layers[0].id
        state.multiSelection = Set(state.project.layers.map(\.id))
        state.beginEdit("scale")
        state.mutateLayer { $0.transform.scale.set(Vec2(200,200), at: 0) }
        state.endEdit()
        XCTAssertEqual(state.project.layers[0].transform.scale.value(at: 0), Vec2(200,200))
        XCTAssertEqual(state.project.layers[1].transform.scale.value(at: 0), Vec2(200,200))
        XCTAssertEqual(state.project.layers[1].transform.position.value(at: 0).x, 120, accuracy: 0.01)
    }

    @MainActor func testPositionAndDepthShareKeyframeTimesAndUndo() {
        let state = editor(scene()); state.selectedLayerID = state.project.layers[0].id
        state.currentTime = 0; state.toggleKeyframe(.position)
        state.currentTime = 1
        state.beginEdit("depth"); state.mutateLayer { $0.transform.positionZ.set(120, at: 1) }; state.endEdit()
        let transform = state.project.layers[0].transform
        XCTAssertEqual(transform.position.keyframeTimes, transform.positionZ.keyframeTimes)
        XCTAssertEqual(transform.positionZ.value(at: 0), 0)
        XCTAssertEqual(transform.positionZ.value(at: 1), 120)
        state.toggleKeyframe(.position)
        XCTAssertFalse(state.project.layers[0].transform.position.hasKeyframe(at: 1))
        XCTAssertFalse(state.project.layers[0].transform.positionZ.hasKeyframe(at: 1))
    }

    @MainActor func testMoveToPlayheadPreservesLengthAndMovesAnimation() {
        var project = scene(); project.layers[0].inPoint = 1; project.layers[0].outPoint = 3
        project.layers[0].transform.position.insertKeyframe(Keyframe(time: 2, value: Vec2(60,64), interpolation: .linear))
        let state = editor(project); state.selectedLayerID = project.layers[0].id
        state.moveClip(project.layers[0], by: 3)
        XCTAssertEqual(state.project.layers[0].inPoint, 4)
        XCTAssertEqual(state.project.layers[0].outPoint, 6)
        XCTAssertEqual(state.project.layers[0].transform.position.keyframeTimes, [5])
    }

    func testPreRenderSignatureIgnoresCacheMetadataButInvalidatesOnEdits() {
        var comp = scene(); let signature = PrecompRenderCache.signature(comp, library: [comp])
        comp.preRenderProxy = PrecompProxy(file: "cached.mov", signature: signature)
        XCTAssertEqual(PrecompRenderCache.signature(comp, library: [comp]), signature)
        comp.layers[0].transform.position.staticValue.x += 1
        XCTAssertNotEqual(PrecompRenderCache.signature(comp, library: [comp]), signature)
    }

    @MainActor func testSelectedParentAndChildScaleOnlyOnce() throws {
        var project = scene()
        project.layers[1].parentID = project.layers[0].id
        project.layers[1].transform.position = Animated(Vec2(20,0))
        let state = editor(project); state.selectedLayerID = project.layers[0].id
        state.multiSelection = Set(project.layers.map(\.id))
        state.mutateLayer { $0.transform.scale.set(Vec2(200,200), at: 0) }
        XCTAssertEqual(state.project.layers[1].transform.scale.value(at: 0), Vec2(100,100))
        let resolved = Renderer.resolveParenting(state.project, time: 0)
        XCTAssertEqual(resolved.layers[1].transform.scale.value(at: 0), Vec2(200,200))
    }

    func testLayerScratchReuseDoesNotChangePreviouslyCompositedPixels() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var project = scene()
        project.layers[0].fill = Animated(RGBA(1,0,0))
        project.layers[1].fill = Animated(RGBA(0,0,1))
        var blur = EffectRegistry.gaussianBlur.makeInstance()
        blur.params["blurriness"] = .number(Animated(1))
        project.layers[0].effects = [blur]; project.layers[1].effects = [blur]
        let pixels = try XCTUnwrap(renderer.renderPixels(project: project, time: 0, preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
        XCTAssertGreaterThan(pixels[(64 * 128 + 40) * 4], 240)
        XCTAssertLessThan(pixels[(64 * 128 + 40) * 4 + 2], 10)
        XCTAssertGreaterThan(pixels[(64 * 128 + 80) * 4 + 2], 240)
    }

    @MainActor func testUnpackPrecompRestoresEditableMembersWithoutLosingContainerEffects() throws {
        let state = editor(scene()); state.selectedLayerID = state.project.layers[0].id
        state.multiSelection = Set(state.project.layers.map(\.id)); state.precomposeMulti()
        guard let container = state.selectedLayer else { return XCTFail("No precomp") }
        XCTAssertTrue(container.name.contains("Precomp"))
        state.unpackSelectedPrecomp()
        let group = try XCTUnwrap(state.selectedLayer)
        XCTAssertTrue(group.isGroup)
        XCTAssertEqual(state.project.layers.filter { $0.groupID == group.id }.count, 2)
        XCTAssertEqual(group.groupCanvasSize, Vec2(128,128))
        let bytes = try JSONEncoder().encode(state.project)
        XCTAssertEqual(try JSONDecoder().decode(Project.self, from: bytes), state.project)
    }

    func testGLTFAndFBXImportRealMeshGeometry() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var binary = Data()
        for value: Float in [-1,-1,0, 1,-1,0, 0,1,0] {
            var bits = value.bitPattern.littleEndian; withUnsafeBytes(of: &bits) { binary.append(contentsOf: $0) }
        }
        let json = """
        {"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[0]}],"nodes":[{"mesh":0}],"meshes":[{"primitives":[{"attributes":{"POSITION":0}}]}],"buffers":[{"byteLength":36,"uri":"data:application/octet-stream;base64,\(binary.base64EncodedString())"}],"bufferViews":[{"buffer":0,"byteLength":36}],"accessors":[{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3","min":[-1,-1,0],"max":[1,1,0]}]}
        """
        let gltf = directory.appendingPathComponent("triangle.gltf"); try Data(json.utf8).write(to: gltf)
        let fbx = directory.appendingPathComponent("triangle.fbx")
        try Data("""
        ; FBX 7.4.0 project file
        FBXHeaderExtension: { FBXHeaderVersion: 1003
            FBXVersion: 7400
        }
        Objects: {
            Geometry: 1, "Geometry::Triangle", "Mesh" {
                Vertices: *9 { a: -1,-1,0,1,-1,0,0,1,0 }
                PolygonVertexIndex: *3 { a: 0,1,-3 }
            }
            Model: 2, "Model::Triangle", "Mesh" { Version: 232 }
        }
        Connections: { C: "OO",1,2
            C: "OO",2,0
        }
        """.utf8).write(to: fbx)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String:Any])
        object["buffers"] = [["byteLength":36]]
        var chunk = try JSONSerialization.data(withJSONObject: object)
        while chunk.count % 4 != 0 { chunk.append(32) }
        var glbData = Data()
        func append(_ number: UInt32) { var value = number.littleEndian; withUnsafeBytes(of: &value) { glbData.append(contentsOf: $0) } }
        append(0x46546c67); append(2); append(UInt32(12 + 8 + chunk.count + 8 + binary.count))
        append(UInt32(chunk.count)); append(0x4e4f534a); glbData.append(chunk)
        append(UInt32(binary.count)); append(0x004e4942); glbData.append(binary)
        let glb = directory.appendingPathComponent("triangle.glb"); try glbData.write(to: glb)
        for file in [gltf,glb,fbx] {
            let scene = try ModelImport.load(url: file)
            var count = 0
            scene.rootNode.enumerateHierarchy { node, _ in count += node.geometry?.sources(for: .vertex).first?.vectorCount ?? 0 }
            XCTAssertGreaterThanOrEqual(count, 3, "\(file.pathExtension) imported a blank scene")
        }
    }
}
