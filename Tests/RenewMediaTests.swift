import XCTest
@testable import AWIeffect

/// R3 renewal: clip timing tools, audio effects, beat grid, export formats, project versions and backups.
@MainActor
final class RenewMediaTests: XCTestCase {
    private func tempRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true) }
    private func project() -> Project { Project.new(name: "renew", width: 1080, height: 1920, fps: 30, duration: 10) }
    private func clipState() -> (EditorState, UUID) {
        var p = project()
        var l = p.makeLayer(name: "clip", content: .audio(fileName: "a.m4a", duration: 20), size: Vec2(1, 1))
        l.inPoint = 1; l.outPoint = 5; l.sourceStart = 2
        p.layers = [l]
        let s = EditorState(project: p, store: ProjectStore(root: tempRoot()))
        s.selectedLayerID = l.id
        return (s, l.id)
    }

    // MARK: Model compatibility

    func testOldLayersDecodeWithoutAudioFXAndEmptyFXDecodesDefaults() throws {
        var p = project()
        p.layers = [p.makeLayer(name: "x", content: .solid, size: Vec2(10, 10))]
        let data = try JSONEncoder().encode(p)
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var layers = obj["layers"] as! [[String: Any]]
        layers[0].removeValue(forKey: "audioFX")
        obj["layers"] = layers
        let back = try JSONDecoder().decode(Project.self, from: JSONSerialization.data(withJSONObject: obj))
        XCTAssertNil(back.layers[0].audioFX)
        let fx = try JSONDecoder().decode(LayerAudioFX.self, from: Data("{}".utf8))
        XCTAssertEqual(fx, LayerAudioFX())
        XCTAssertTrue(fx.isNeutral)
    }

    func testFadeShapesReachEdgesAndMultiply() {
        for shape in LayerAudioFX.FadeShape.allCases {
            XCTAssertEqual(shape.gain(0), 0, accuracy: 1e-9)
            XCTAssertEqual(shape.gain(1), 1, accuracy: 1e-9)
        }
        var fx = LayerAudioFX(); fx.fadeIn = 1; fx.fadeOut = 1; fx.fadeShape = .linear
        XCTAssertEqual(fx.fadeGain(at: 0.5, inPoint: 0, outPoint: 4), 0.5, accuracy: 1e-9)
        XCTAssertEqual(fx.fadeGain(at: 2, inPoint: 0, outPoint: 4), 1, accuracy: 1e-9)
        XCTAssertEqual(fx.fadeGain(at: 3.75, inPoint: 0, outPoint: 4), 0.25, accuracy: 1e-9)
        XCTAssertTrue(fx.needsEnvelope)
    }

    func testDuckingDropsWhileKeySoundsAndRecovers() {
        let levels: [Float] = Array(repeating: -10, count: 20) + Array(repeating: -90, count: 60)
        let g = AudioDucking.gains(levelsDB: levels, amountDB: -12, release: 0.3)
        XCTAssertEqual(g[19], Float(pow(10, -12.0 / 20)), accuracy: 0.01)
        XCTAssertGreaterThan(g[79], 0.95)
        XCTAssertLessThan(g[22], g[40])
    }

    // MARK: Clip tools

    func testSpeedCurveKeepsSourceEndpointsAndShapesSpeed() throws {
        let (remap, speeds) = try XCTUnwrap(SpeedCurve.remap(speeds: [2.5, 1.6, 0.25, 1.6, 2.5], start: 1, end: 5, sourceStart: 2, sourceEnd: 6))
        XCTAssertEqual(remap.value(at: 1), 2, accuracy: 1e-9)
        XCTAssertEqual(remap.value(at: 5), 6, accuracy: 1e-9)
        XCTAssertLessThan(speeds[2], speeds[0])
        let constant = try XCTUnwrap(SpeedCurve.remap(speeds: [1, 1, 1], start: 0, end: 2, sourceStart: 0, sourceEnd: 4))
        XCTAssertEqual(constant.1[0], 2, accuracy: 1e-9)
        XCTAssertEqual(constant.0.value(at: 1), 2, accuracy: 1e-6)
    }

    func testApplySpeedCurveIsOneUndoStep() {
        let (s, id) = clipState()
        s.applySpeedCurve(SpeedCurve.presets[1].speeds)
        XCTAssertNotNil(s.project.layers.first { $0.id == id }?.timeRemap)
        s.undo()
        XCTAssertNil(s.project.layers.first { $0.id == id }?.timeRemap)
    }

    func testTrimStartKeepsOutPointAndSlipKeepsPosition() {
        let (s, id) = clipState()
        s.trimClipStart(toSource: 3)
        var l = s.project.layers.first { $0.id == id }!
        XCTAssertEqual(l.inPoint, 2, accuracy: 1e-9)
        XCTAssertEqual(l.outPoint, 5, accuracy: 1e-9)
        XCTAssertEqual(l.sourceTime(at: 5), 6, accuracy: 1e-9)
        s.slipClip(toSource: 7)
        l = s.project.layers.first { $0.id == id }!
        XCTAssertEqual(l.inPoint, 2, accuracy: 1e-9)
        XCTAssertEqual(l.sourceStart, 7, accuracy: 1e-9)
        s.trimClipEnd(toSource: 8)
        XCTAssertEqual(s.project.layers.first { $0.id == id }!.outPoint, 3, accuracy: 1e-9)
    }

    func testFreezeFrameHoldsThenContinues() throws {
        let (s, id) = clipState()
        s.currentTime = 2
        s.freezeFrame(hold: 1.5)
        XCTAssertEqual(s.project.layers.count, 3)
        let first = try XCTUnwrap(s.project.layers.first { $0.id == id })
        XCTAssertEqual(first.outPoint, 2, accuracy: 1e-9)
        let freeze = try XCTUnwrap(s.project.layers.first { $0.timeFX?.freezeAt != nil })
        XCTAssertEqual(freeze.inPoint, 2, accuracy: 1e-9)
        XCTAssertEqual(freeze.outPoint, 3.5, accuracy: 1e-9)
        let rest = try XCTUnwrap(s.project.layers.first { $0.id != id && $0.timeFX?.freezeAt == nil })
        XCTAssertEqual(rest.inPoint, 3.5, accuracy: 1e-9)
        XCTAssertEqual(rest.outPoint, 6.5, accuracy: 1e-9)
        // Continues from the frozen source frame.
        XCTAssertEqual(rest.sourceTime(at: 3.5), first.sourceTime(at: 2), accuracy: 1e-9)
        s.undo()
        XCTAssertEqual(s.project.layers.count, 1)
    }

    // MARK: Beats

    func testBeatGridSubdivisionsAndQuantize() {
        let t = BeatGrid.times(bpm: 120, offset: 0.25, subdivision: 2, duration: 2)
        XCTAssertEqual(t.first ?? -1, 0, accuracy: 1e-9)
        XCTAssertEqual(t[1], 0.25, accuracy: 1e-9)
        XCTAssertEqual(t.count, 9)
        let q = BeatGrid.quantize([0.49, 0.52, 1.01], bpm: 120, offset: 0, subdivision: 1)
        XCTAssertEqual(q, [0.5, 1.0])
    }

    // MARK: Export

    func testFormatsHaveCodecNamesAndPlausibleEstimates() {
        let p = project()
        for f in ExportFormat.allCases { XCTAssertFalse(f.codecName(.h264).isEmpty) }
        func bytes(_ f: ExportFormat) -> Double { var s = ExportSettings(); s.format = f; return Exporter.estimatedBytes(p, settings: s) }
        XCTAssertGreaterThan(bytes(.prores4444), bytes(.prores422))
        XCTAssertGreaterThan(bytes(.prores422), bytes(.mp4))
        XCTAssertGreaterThan(bytes(.audioWAV), bytes(.audioM4A))
        XCTAssertEqual(ExportFormat.pngSequence.fileExtension, "zip")
        XCTAssertTrue(ExportFormat.prores4444.keepsAlpha)
        XCTAssertFalse(ExportFormat.prores422.keepsAlpha)
    }

    func testPresetsTargetPlatformSize() {
        let p = Project.new(name: "w", width: 720, height: 1280, fps: 60, duration: 4)
        let tiktok = ExportPreset.all.first { $0.name == "TikTok" }!.apply(to: ExportSettings(), project: p)
        XCTAssertEqual(Exporter.outputSize(p, scale: tiktok.scale).0, 1080)
        XCTAssertEqual(tiktok.format, .mp4)
        let reels = ExportPreset.all.first { $0.name == "Reels" }!.apply(to: ExportSettings(), project: p)
        XCTAssertEqual(reels.fps, 30)
        XCTAssertFalse(ExportPreset.all[0].aspectMismatch(p))
        XCTAssertTrue(ExportPreset.all[0].aspectMismatch(Project.new(name: "l", width: 1920, height: 1080, fps: 30, duration: 1)))
    }

    func testZipRoundTrip() throws {
        let dir = tempRoot()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("big.bin")
        let payload = Data((0..<300_000).map { UInt8($0 % 251) })
        try payload.write(to: file)
        let zipURL = dir.appendingPathComponent("t.zip")
        let w = try ZipArchive.Writer(url: zipURL)
        try w.add("a/hello.txt", data: Data("hello".utf8))
        try w.add("b/big.bin", file: file)
        try w.finish()
        XCTAssertEqual(try ZipArchive.entries(of: zipURL).map(\.name), ["a/hello.txt", "b/big.bin"])
        let out = dir.appendingPathComponent("out")
        try ZipArchive.extract(zipURL, to: out)
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("a/hello.txt")), Data("hello".utf8))
        XCTAssertEqual(try Data(contentsOf: out.appendingPathComponent("b/big.bin")), payload)
        XCTAssertEqual(ZipArchive.crc32(Data("123456789".utf8)), 0xCBF4_3926)
    }

    // MARK: Projects

    func testNamedVersionsSurvivePruningAndCarryNames() throws {
        let store = ProjectStore(root: tempRoot())
        let p = project()
        try store.save(p)
        let named = try store.saveNamedVersion(p, name: "Before drop", thumbnail: nil)
        for _ in 0..<(ProjectStore.maxVersions + 3) { try store.save(p, snapshotVersion: true) }
        let versions = store.versions(for: p.id)
        XCTAssertTrue(versions.contains(named))
        XCTAssertEqual(versions.count, ProjectStore.maxVersions + 1)
        XCTAssertTrue(versions.allSatisfy { $0.pathExtension == "json" })
        XCTAssertEqual(store.versionName(named), "Before drop")
    }

    func testBackupRestoresIntoAnotherStoreAndSkipsExisting() throws {
        let a = ProjectStore(root: tempRoot())
        let p = project()
        try a.save(p)
        _ = try a.importMedia(data: Data("media".utf8), ext: "txt", into: p.id)
        let zip = try a.backupAll()
        let b = ProjectStore(root: tempRoot())
        let r = try b.restoreBackup(zip)
        XCTAssertEqual(r.restored, 1)
        XCTAssertEqual(try b.load(p.id).name, p.name)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: b.mediaFolder(for: p.id).path).count, 1)
        XCTAssertEqual(try b.restoreBackup(zip).skipped, 1)
    }

    func testProjectSearchAndSort() {
        func s(_ n: String, _ d: Double) -> ProjectSummary {
            ProjectSummary(id: UUID(), name: n, width: 10, height: 10, fps: 30, duration: d, modifiedAt: Date(), thumbnail: nil)
        }
        let list = [s("Zoro AMV", 3), s("naruto edit", 9), s("Édit Luffy", 1)]
        XCTAssertEqual(ProjectSort.apply(.name, to: list, search: "").map(\.name), ["Édit Luffy", "naruto edit", "Zoro AMV"].sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        XCTAssertEqual(ProjectSort.apply(.duration, to: list, search: "edit").map(\.name), ["naruto edit", "Édit Luffy"])
    }
}
