import XCTest
@testable import AWIeffect

final class SourceProjectImportTests: XCTestCase {
    func testAEAttachmentsKeepOriginalMatchNamesAndUnresolvedPluginSlots() throws {
        var report = ImportReport()
        let unknown = AEProp(matchName: "PEDG2", kind: .effect(
            RIFXChunk(id: "LIST", listType: "sspc", data: Data([1, 3, 5, 7]), children: [])))
        let instance = AEPImporter.importEffect(unknown, timebase: 24576, layerStart: 0, layer: "Art", report: &report)
        XCTAssertEqual(instance.imported?.sourceID, "afterEffects:PEDG2")
        XCTAssertEqual(instance.imported?.support, .unavailable)
        XCTAssertEqual(instance.imported?.properties.first?.bytes, Data([1, 3, 5, 7]))
        XCTAssertNil(EffectRegistry.definition(instance.typeID))
        XCTAssertNotEqual(instance.typeID, EffectRegistry.deepGlow.id)
        XCTAssertEqual(report.missingCount, 1)
        XCTAssertEqual(try JSONDecoder().decode(EffectInstance.self, from: JSONEncoder().encode(instance)), instance)

        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "2_gaussian_animated", withExtension: "aep"))
        let project = try AEPImporter.load(url: fixture).project
        XCTAssertEqual(project.importedFormat, .afterEffects)
        XCTAssertFalse(project.autoLength)
        let effect = try XCTUnwrap(project.layers.flatMap(\.effects).first { !$0.keyframeTimes.isEmpty })
        XCTAssertTrue(effect.imported?.sourceID.hasPrefix("afterEffects:ADBE Gaussian Blur") == true)
        XCTAssertFalse(effect.imported?.properties.isEmpty ?? true)
    }

    func testAMKeepsUnknownEffectBetweenSupportedEffects() throws {
        let xml = """
        <scene title="Slots" width="200" height="120" fps="30" totalTime="2000">
          <shape s="rect" startTime="0" endTime="2000">
            <effect id="com.alightcreative.effects.invert"/>
            <effect id="com.customfx.effects.unknown">
              <property name="amount" type="float"><kf t="0" v="1"/><kf t="1" v="4" e="hold"/></property>
            </effect>
            <effect id="com.alightcreative.effects.oscillate3">
              <property name="angle" value="0"/><property name="freq" value="1"/><property name="mag" value="20"/>
            </effect>
          </shape>
        </scene>
        """
        let project = try AMImporter.load(data: Data(xml.utf8), fallbackName: "Slots").project
        let effects = try XCTUnwrap(project.layers.first?.effects)
        XCTAssertEqual(effects.count, 3)
        XCTAssertEqual(effects[1].imported?.support, .unavailable)
        XCTAssertEqual(effects[1].imported?.properties.first?.children.first?.children.last?.attributes?["e"], "hold")
        XCTAssertEqual(effects[2].imported?.sourceID, "alightMotion:com.alightcreative.effects.oscillate3")
        let layer = try XCTUnwrap(project.layers.first)
        XCTAssertEqual(Renderer.transformOffsets(layer, time: 0.25).dx, 20, accuracy: 1e-7)
    }

    @MainActor
    func testPasteSourceMotionIntoAnotherProjectAndReopen() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "am_shakes", withExtension: "xml"))
        let source = try AMImporter.load(data: Data(contentsOf: url), fallbackName: "Shake").project
        let sourceLayer = try XCTUnwrap(source.layers.first { layer in
            layer.effects.contains { $0.typeID == EffectRegistry.importedOscillate.id && !$0.keyframeTimes.isEmpty }
        })
        let original = try XCTUnwrap(sourceLayer.effects.first { $0.typeID == EffectRegistry.importedOscillate.id && !$0.keyframeTimes.isEmpty })
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("source-import-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectStore(root: root)
        let sourceEditor = EditorState(project: source, store: store)
        sourceEditor.select(sourceLayer.id)
        sourceEditor.copyEffects([original.id])

        var destination = Project.new(name: "Destination", width: 200, height: 120, fps: 30, duration: 4)
        var artwork = destination.makeLayer(name: "Art", content: .solid, size: Vec2(24, 24))
        artwork.inPoint = 0.5
        artwork.outPoint = 3.5
        destination.layers = [artwork]
        let editor = EditorState(project: destination, store: store)
        editor.select(artwork.id)
        editor.pasteEffects()
        let restored = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(editor.project))
        let pasted = try XCTUnwrap(restored.layers.first?.effects.first)
        XCTAssertNotEqual(pasted.id, original.id)
        XCTAssertEqual(pasted.imported?.sourceID, original.imported?.sourceID)
        XCTAssertEqual(pasted.imported?.properties, original.imported?.properties)
        XCTAssertNil(restored.importedFormat)
        var carrier = sourceLayer
        carrier.effects = [original]
        for progress in [0.0, 0.17, 0.36, 0.72, 0.9] {
            let sourceTime = sourceLayer.inPoint + progress * (sourceLayer.outPoint - sourceLayer.inPoint)
            let targetTime = artwork.inPoint + progress * (artwork.outPoint - artwork.inPoint)
            let before = Renderer.transformOffsets(carrier, time: sourceTime)
            let after = Renderer.transformOffsets(restored.layers[0], time: targetTime)
            XCTAssertEqual(before.dx, after.dx, accuracy: 1e-5)
            XCTAssertEqual(before.dy, after.dy, accuracy: 1e-5)
        }

        if Renderer.shared != nil {
            let output = URL(fileURLWithPath: "/tmp/awi-authoring/source-import", isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let export = try await Exporter().export(project: restored, settings: ExportSettings(format: .mp4),
                                                     mediaURL: { store.mediaURL($0, projectID: restored.id) }) { _ in }
            defer { try? FileManager.default.removeItem(at: export) }
            try Data(contentsOf: export).write(to: output.appendingPathComponent("alight-oscillate-pasted.mp4"), options: .atomic)
        }
    }
}
