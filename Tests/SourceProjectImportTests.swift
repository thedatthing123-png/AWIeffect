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
        XCTAssertEqual(project.name, fixture.deletingPathExtension().lastPathComponent)
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

    func testAMTextTransformAndDeepGlowKeepSourceIdentityAndKeys() throws {
        let xml = """
        <scene title="Titles" width="200" height="120" fps="30" totalTime="2000">
          <text label="Title" startTime="0" endTime="2000">
            <effect id="com.alightcreative.effects.texttransform">
              <property name="start" type="float"><kf t="0" v="0"/><kf t="1" v="1"/></property>
              <property name="offset" type="vec2" value="12,8"/>
              <property name="overlap" type="float" value="4"/>
            </effect>
            <effect id="com.alightcreative.effects.deepglow">
              <property name="rrr" type="float"><kf t="0" v="1"/><kf t="1" v="2"/></property>
            </effect>
            <content>Title</content>
          </text>
        </scene>
        """
        let result = try AMImporter.load(data: Data(xml.utf8), fallbackName: "Titles")
        let text = try XCTUnwrap(result.project.layers.first)
        let animator = try XCTUnwrap(text.text?.animators.first)
        XCTAssertEqual(animator.selector.start.keyframeTimes, [0, 2])
        XCTAssertEqual(animator.properties.position?.staticValue, Vec2(12, 8))
        XCTAssertEqual(text.effects.first?.imported?.support, .layerSettings)
        XCTAssertEqual(text.effects.first?.imported?.properties.first?.children.last?.attributes?["name"], "overlap")
        let glow = try XCTUnwrap(text.effects.last)
        XCTAssertNotNil(EffectRegistry.definition(glow.typeID))
        XCTAssertEqual(glow.imported?.matchName, "com.alightcreative.effects.deepglow")
        XCTAssertEqual(try XCTUnwrap(glow.params["rrr"]).number(at: 2), 200, accuracy: 0.00001)
        XCTAssertEqual(result.report.missingCount, 0)
    }

    @MainActor
    func testSourceShaderSurvivesCopyAndEditsBesideSameNamedEffect() throws {
        let xml = """
        <scene title="Source Colors" width="80" height="80" fps="30" totalTime="1000">
          <shape s="rect" startTime="0" endTime="1000">
            <effect id="com.alightcreative.effects.tritone">
              <property name="highlights" type="color">
                <kf t="0" v="#FFFF0000"/><kf t="1" v="#FF0000FF" e="cubicBezier 0.25 0 0.75 1"/>
              </property>
            </effect>
            <effect id="com.customfx.effects.tritone"/>
            <effect id="com.customfx.effects.shake2"/>
          </shape>
        </scene>
        """
        let source = try AMImporter.load(data: Data(xml.utf8), fallbackName: "Imported").project
        XCTAssertEqual(source.name, "Source Colors")
        XCTAssertEqual(source.importedFormat, .alightMotion)
        let layer = try XCTUnwrap(source.layers.first)
        let original = try XCTUnwrap(layer.effects.first)
        let reference = try XCTUnwrap(ReferenceFragmentCatalog.bySourceID["com.alightcreative.effects.tritone"])
        XCTAssertEqual(original.typeID, reference.id)
        XCTAssertEqual(layer.effects.dropFirst().map { $0.imported?.support }, [.unavailable, .unavailable])
        let native = EffectRegistry.tritone
        XCTAssertEqual(EffectRegistry.definition(original.typeID)?.name, native.name)
        XCTAssertNotEqual(original.typeID, native.id)
        var report = ImportReport()
        let ae = AEPImporter.importEffect(AEProp(matchName: "ADBE Tritone", kind: .group([])),
                                          timebase: 24576, layerStart: 0, layer: "Art", report: &report)
        XCTAssertEqual(ae.imported?.sourceID, "afterEffects:ADBE Tritone")
        XCTAssertEqual(ae.typeID, "source.ae.v1.ADBE Tritone")
        XCTAssertEqual(EffectRegistry.definition(ae.typeID)?.id, native.id)
        XCTAssertNotEqual(ae.typeID, original.typeID)
        guard case .color(let colors)? = original.params["highlights"] else { return XCTFail("Missing source color track") }
        XCTAssertEqual(colors.keyframeTimes, [0, 1])
        XCTAssertEqual(colors.keyframes.first?.interpolation, .bezier)

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("source-shader-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ProjectStore(root: root)
        let sourceEditor = EditorState(project: source, store: store)
        sourceEditor.select(layer.id)
        sourceEditor.copyEffects([original.id])

        var project = Project.new(name: "Destination", width: 80, height: 80, fps: 30, duration: 3)
        var art = project.makeLayer(name: "Art", content: .solid, size: Vec2(80, 80))
        art.inPoint = 1
        art.outPoint = 3
        art.effects = [native.makeInstance()]
        art.effects[0].isEnabled = false
        project.layers = [art]
        let editor = EditorState(project: project, store: store)
        editor.select(art.id)
        editor.pasteEffects()
        let pasted = try XCTUnwrap(editor.selectedLayer?.effects.last)
        XCTAssertEqual(pasted.typeID, original.typeID)
        XCTAssertEqual(pasted.imported?.sourceID, original.imported?.sourceID)
        XCTAssertEqual(pasted.keyframeTimes, [1, 3])

        guard let renderer = Renderer.shared else { return XCTFail("Metal renderer unavailable") }
        func frame(_ project: Project) throws -> [UInt8] {
            try XCTUnwrap(renderer.renderPixels(project: project, time: 1.5, mediaURL: { store.mediaURL($0, projectID: project.id) })).rgba
        }
        let before = try frame(editor.project)
        editor.setEffectParam(pasted.id, "highlights") { value, _ in
            value = .color(Animated(RGBA(0, 1, 0)))
        }
        let reopened = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(editor.project))
        XCTAssertEqual(reopened.layers.first?.effects.last?.typeID, reference.id)
        XCTAssertEqual(reopened.layers.first?.effects.last?.imported?.properties, original.imported?.properties)
        XCTAssertNotEqual(try frame(reopened), before)
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
