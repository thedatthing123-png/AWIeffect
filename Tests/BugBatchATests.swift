import XCTest
@testable import AWIeffect

/// Regression tests for the R1 (timeline, keyframes, groups) and R3 (media, export, projects) audit bugs.
@MainActor final class BugBatchATests: XCTestCase {
    private var roots: [URL] = []

    override func tearDown() {
        for r in roots { try? FileManager.default.removeItem(at: r) }
        roots = []
        super.tearDown()
    }

    private func store() -> ProjectStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        roots.append(root)
        return ProjectStore(root: root)
    }

    private func project() -> Project {
        var p = Project.new(name: "batchA", width: 100, height: 100, fps: 30, duration: 10, background: .black)
        p.autoLength = false
        return p
    }

    private func solid(_ p: Project, _ name: String, _ a: Double, _ b: Double) -> Layer {
        var p = p
        var l = p.makeLayer(name: name, content: .solid, size: Vec2(10, 10))
        l.inPoint = a; l.outPoint = b
        return l
    }

    /// A project with one group holding two solids (0-4 and 2-8); returns (state, group id).
    private func grouped() throws -> (EditorState, UUID) {
        var p = project()
        p.layers = [solid(p, "a", 0, 4), solid(p, "b", 2, 8)]
        let s = EditorState(project: p, store: store())
        s.multiSelection = Set(p.layers.map(\.id)); s.groupSelected()
        let gid = try XCTUnwrap(s.selectedLayerID)
        XCTAssertTrue(s.project.layers.first { $0.id == gid }!.isGroup)
        return (s, gid)
    }

    // MARK: R1 undo across group / pre-comp

    func testEditsInsideGroupAreOneUndoStepAfterClosing() throws {
        let (s, gid) = try grouped()
        let before = s.project
        let historyBefore = s.undoStack.count
        s.select(gid); s.openGroup()
        s.mutate("Rename") { $0.layers[0].name = "inside" }
        s.mutate("Rename again") { $0.layers[0].name = "inside 2" }
        s.closePrecomp()
        XCTAssertEqual(s.undoStack.count, historyBefore + 1, "inside work becomes exactly one undo step")
        XCTAssertTrue(s.project.layers.contains { $0.name == "inside 2" })
        s.undo()
        XCTAssertEqual(s.project.layers.map(\.name), before.layers.map(\.name))
        s.redo()
        XCTAssertTrue(s.project.layers.contains { $0.name == "inside 2" })
        // Earlier history (the grouping) survives.
        s.undo(); s.undo()
        XCTAssertFalse(s.project.layers.contains(where: \.isGroup))
    }

    func testOpeningAndClosingWithoutEditsAddsNoUndoStep() throws {
        let (s, gid) = try grouped()
        let count = s.undoStack.count
        s.select(gid); s.openGroup(); s.closePrecomp()
        XCTAssertEqual(s.undoStack.count, count)
    }

    func testGroupUsesLocalTimelineAndMapsEditsBackToRootTime() throws {
        var p = project()
        var a = solid(p, "a", 2, 5)
        let b = solid(p, "b", 4, 8)
        a.transform.position.insertKeyframe(Keyframe(time: 3, value: Vec2(20, 20)))
        p.layers = [a, b]
        p.markers = [1, 3, 7, 9]
        let s = EditorState(project: p, store: store())
        s.multiSelection = Set(p.layers.map(\.id)); s.groupSelected()
        let gid = try XCTUnwrap(s.selectedLayerID)
        s.currentTime = 5
        s.openGroup()

        XCTAssertEqual(s.project.duration, 6, accuracy: 1e-9)
        XCTAssertEqual(s.currentTime, 3, accuracy: 1e-9)
        XCTAssertEqual(s.rootTime(s.currentTime), 5, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.project.layers.first { $0.id == a.id }).inPoint, 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.project.layers.first { $0.id == b.id }).inPoint, 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.project.layers.first { $0.id == a.id }?.transform.position.keyframes.first).time, 1, accuracy: 1e-9)
        XCTAssertEqual(s.project.markers, [1, 5])

        s.mutate("Move local key") { child in
            child.layers[0].transform.position.keyframes[0].time = 2
        }
        s.closePrecomp()
        XCTAssertEqual(try XCTUnwrap(s.project.layers.first { $0.id == a.id }).inPoint, 2, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.project.layers.first { $0.id == b.id }).inPoint, 4, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(s.project.layers.first { $0.id == a.id }?.transform.position.keyframes.first).time, 4, accuracy: 1e-9)
        XCTAssertEqual(s.project.markers, [1, 3, 7, 9])
        XCTAssertEqual(s.selectedLayerID, gid)
    }

    // MARK: R1 group split / trim

    func testSplittingGroupSplitsItsChildren() throws {
        let (s, gid) = try grouped()
        s.select(gid); s.currentTime = 3; s.splitSelected()
        let groups = s.project.layers.filter(\.isGroup)
        XCTAssertEqual(groups.count, 2)
        let second = try XCTUnwrap(groups.first { $0.id != gid })
        XCTAssertEqual(second.inPoint, 3, accuracy: 1e-9)
        let firstParts = s.project.layers.filter { $0.groupID == gid }
        let secondParts = s.project.layers.filter { $0.groupID == second.id }
        XCTAssertEqual(firstParts.count, 2)
        XCTAssertEqual(secondParts.count, 2, "the second half isn't empty")
        XCTAssertTrue(firstParts.allSatisfy { $0.outPoint <= 3 + 1e-9 })
        XCTAssertTrue(secondParts.allSatisfy { $0.inPoint >= 3 - 1e-9 })
        XCTAssertEqual(Set(secondParts.map(\.name)), ["a", "b"])
        s.undo()
        XCTAssertEqual(s.project.layers.filter(\.isGroup).count, 1, "one undo restores the group")
    }

    func testSplitGroupMovesLaterPartsWholly() throws {
        var p = project()
        p.layers = [solid(p, "early", 0, 2), solid(p, "late", 5, 8)]
        let s = EditorState(project: p, store: store())
        s.multiSelection = Set(p.layers.map(\.id)); s.groupSelected()
        let gid = try XCTUnwrap(s.selectedLayerID)
        s.currentTime = 3; s.splitSelected()
        let second = try XCTUnwrap(s.project.layers.first { $0.isGroup && $0.id != gid })
        XCTAssertEqual(s.project.layers.filter { $0.groupID == gid }.map(\.name), ["early"])
        XCTAssertEqual(s.project.layers.filter { $0.groupID == second.id }.map(\.name), ["late"])
        XCTAssertEqual(s.project.layers.filter { $0.name == "late" }.count, 1, "no empty duplicate")
    }

    func testTrimmingGroupTrimsChildrenAndDragBackRestores() throws {
        let (s, gid) = try grouped()
        let group = s.project.layers.first { $0.id == gid }!
        s.beginEdit("Trim Clip")
        s.trimClip(group, start: false, by: -5)   // group ends at 3
        let b = s.project.layers.first { $0.name == "b" }!
        XCTAssertEqual(b.outPoint, 3, accuracy: 1e-6)
        s.trimClip(group, start: false, by: 0)    // dragged back out within the same drag
        s.endEdit()
        XCTAssertEqual(s.project.layers.first { $0.name == "b" }!.outPoint, 8, accuracy: 1e-6)
        s.trimClip(s.project.layers.first { $0.id == gid }!, start: true, by: 1)
        let a = s.project.layers.first { $0.name == "a" }!
        XCTAssertEqual(a.inPoint, 1, accuracy: 1e-6)
    }

    func testTrimStopsAtMediaStartAndEnd() {
        var p = project()
        var l = p.makeLayer(name: "song", content: .audio(fileName: "s.m4a", duration: 5), size: Vec2(1, 1))
        l.inPoint = 2; l.outPoint = 4; l.sourceStart = 1
        p.layers = [l]
        let s = EditorState(project: p, store: store())
        s.trimClip(l, start: true, by: -5)
        XCTAssertEqual(s.project.layers[0].inPoint, 1, accuracy: 1e-6, "source starts at 0, one second before")
        XCTAssertEqual(s.project.layers[0].sourceStart, 0, accuracy: 1e-6)
        s.trimClip(s.project.layers[0], start: false, by: 10)
        XCTAssertEqual(s.project.layers[0].outPoint, 6, accuracy: 1e-6, "the 5 s source ends at comp time 6")
    }

    // MARK: R1 keyframes

    func testMovingKeyOntoSamePropertyKeyIsRejectedNotDestructive() {
        var p = project()
        var l = solid(p, "k", 0, 10)
        for t in [1.0, 2] { l.transform.rotation.insertKeyframe(Keyframe(time: t, value: t * 10)) }
        p.layers = [l]
        let s = EditorState(project: p, store: store())
        s.selectedLayerID = l.id
        XCTAssertNil(s.moveKeyframeSelection(of: l, times: [1], by: 1))
        XCTAssertEqual(s.project.layers[0].transform.rotation.keyframes.map(\.value), [10, 20])
        var r = l; r.retimeKeys(at: 1, to: 2)
        XCTAssertEqual(r.transform.rotation.keyframes.count, 2, "retime never overwrites")
    }

    func testCopyPasteKeysCopiesRealKeyframesWithEasingEffectsAndRelativeTiming() {
        var p = project()
        var src = solid(p, "src", 0, 10)
        src.transform.position.insertKeyframe(Keyframe(time: 2, value: Vec2(0, 0), interpolation: .bezier, easeOut: EaseHandle(x: 0.2, y: 0.7), easeIn: .easyIn))
        src.transform.position.insertKeyframe(Keyframe(time: 3, value: Vec2(50, 0)))
        src.size.insertKeyframe(Keyframe(time: 2.5, value: Vec2(5, 5)))
        var blur = EffectRegistry.gaussianBlur.makeInstance()
        var a = Animated(0.0); a.insertKeyframe(Keyframe(time: 4, value: 9))
        blur.params["blurriness"] = .number(a)
        src.effects = [blur]
        let dst = solid(p, "dst", 0, 10)
        p.layers = [src, dst]
        let s = EditorState(project: p, store: store())
        s.selectedLayerID = src.id
        s.copyKeyframes()
        s.selectedLayerID = dst.id; s.currentTime = 6
        s.pasteKeyframes()
        let out = s.project.layers.first { $0.id == dst.id }!
        XCTAssertEqual(out.transform.position.keyframeTimes, [6, 7])
        XCTAssertEqual(out.transform.position.keyframes[0].easeOut, EaseHandle(x: 0.2, y: 0.7))
        XCTAssertEqual(out.transform.position.value(at: 7), Vec2(50, 0))
        XCTAssertEqual(out.size.keyframeTimes, [6.5])
        guard case .number(let pasted)? = out.effects.first(where: { $0.typeID == blur.typeID })?.params["blurriness"] else {
            return XCTFail("effect keys pasted")
        }
        XCTAssertEqual(pasted.keyframeTimes, [8])
        XCTAssertNotEqual(out.transform.position.keyframes[0].id, src.transform.position.keyframes[0].id)
    }

    func testKeyframeVelocityAllCoversSizeFillCornerAndEffects() {
        var p = project()
        var l = solid(p, "v", 0, 10)
        for t in [1.0, 2] {
            l.size.insertKeyframe(Keyframe(time: t, value: Vec2(t, t), interpolation: .linear))
            l.fill.insertKeyframe(Keyframe(time: t, value: .white, interpolation: .linear))
            l.cornerRadius.insertKeyframe(Keyframe(time: t, value: t, interpolation: .linear))
        }
        var blur = EffectRegistry.gaussianBlur.makeInstance()
        var a = Animated(0.0)
        for t in [1.0, 2] { a.insertKeyframe(Keyframe(time: t, value: t, interpolation: .linear)) }
        blur.params["blurriness"] = .number(a); l.effects = [blur]
        p.layers = [l]
        let s = EditorState(project: p, store: store())
        s.selectedLayerID = l.id; s.currentTime = 1
        XCTAssertTrue(s.hasKeyframeAtPlayhead)
        s.applyKeyframeVelocity(inInfluence: 0.5, inSpeed: 0, outInfluence: 0.5, outSpeed: 0)
        let out = s.project.layers[0]
        XCTAssertEqual(out.size.keyframes[0].interpolation, .bezier)
        XCTAssertEqual(out.fill.keyframes[0].interpolation, .bezier)
        XCTAssertEqual(out.cornerRadius.keyframes[0].interpolation, .bezier)
        guard case .number(let b)? = out.effects[0].params["blurriness"] else { return XCTFail() }
        XCTAssertEqual(b.keyframes[0].interpolation, .bezier)
        XCTAssertEqual(b.keyframes[0].easeOut, EaseHandle(x: 0.5, y: 0))
    }

    func testGroupMemberBarUsesGroupTagAlsoInsideOpenGroup() throws {
        let (s, gid) = try grouped()
        let tag = s.project.layers.first { $0.id == gid }!.tag
        XCTAssertNil(s.groupMemberTag(of: s.project.layers.first { $0.id == gid }!))
        XCTAssertEqual(s.groupMemberTag(of: s.project.layers.first { $0.name == "a" }!), tag)
        s.select(gid); s.openGroup()
        XCTAssertEqual(s.groupMemberTag(of: s.project.layers[0]), tag)
    }

    // MARK: R3 beats

    func testPunchOnBeatsAddsOnTopOfExistingScaleAnimation() {
        var scale = Animated(Vec2(100, 100))
        scale.insertKeyframe(Keyframe(time: 0, value: Vec2(100, 100), interpolation: .linear))
        scale.insertKeyframe(Keyframe(time: 4, value: Vec2(200, 200), interpolation: .linear))
        let out = EditorState.punched(scale, beats: [2], inPoint: 0, outPoint: 4, amount: 20, decay: 0.5)
        XCTAssertEqual(out.value(at: 2).x, 150 * 1.2, accuracy: 1e-6, "punch scales the animated value, not a flat base")
        XCTAssertEqual(out.value(at: 2.5).x, scale.value(at: 2.5).x, accuracy: 1e-6)
        XCTAssertEqual(out.value(at: 4).x, 200, accuracy: 1e-6, "later scale keys survive")
        let soft = EditorState.punched(scale, beats: [2], inPoint: 0, outPoint: 4, amount: 5, decay: 0.5)
        XCTAssertEqual(soft.value(at: 2).x, 150 * 1.05, accuracy: 1e-6, "strength is adjustable")
    }

    // MARK: R3 export

    func testExportEstimateUsesEncoderBitrateAndGifCaps() {
        var p = project(); p.width = 1920; p.height = 1080; p.fps = 60; p.duration = 10
        var settings = ExportSettings(); settings.format = .mp4; settings.bitrateMbps = 20
        let bytes = Exporter.estimatedBytes(p, settings: settings)
        let encoderBps = Double(Exporter.videoBitrate(settings, width: 1920, height: 1080, fps: 60))
        XCTAssertEqual(encoderBps, 40_000_000, accuracy: 1, "60 fps doubles the 1080p30 rate")
        XCTAssertGreaterThan(bytes, encoderBps * 10 / 8 * 0.99, "estimate follows what the encoder writes")
        settings.format = .gif; settings.fps = 60
        let g = Exporter.gifOutput(p, settings: settings)
        XCTAssertEqual(g.fps, Exporter.gifMaxFPS)
        XCTAssertEqual(Double(max(g.width, g.height)), Exporter.gifMaxDimension)
    }

    func testRootTimeMapsPrecompTimeForExport() {
        var p = project()
        let child = project()
        p.precomps = [child]
        var pl = p.makeLayer(name: "pc", content: .precomp(id: child.id), size: Vec2(100, 100))
        pl.inPoint = 2; pl.outPoint = 8; pl.sourceStart = 0
        p.layers = [pl]
        let s = EditorState(project: p, store: store())
        s.select(pl.id); s.currentTime = 3; s.openPrecomp()
        XCTAssertEqual(s.rootTime(s.currentTime), 3, accuracy: 1e-6)
        XCTAssertEqual(s.rootProject.id, p.id)
    }

    // MARK: R3 projects

    func testRestoreVersionKeepsCurrentStateAsVersion() throws {
        let st = store()
        var p = project(); p.name = "v1"
        try st.save(p, snapshotVersion: true)
        p.name = "unsaved work"; try st.save(p)
        let old = try XCTUnwrap(st.versions(for: p.id).first)
        try st.restoreVersion(old, for: p.id)
        XCTAssertEqual(try st.load(p.id).name, "v1")
        let names = try st.versions(for: p.id).map { try st.loadVersion($0).name }
        XCTAssertTrue(names.contains("unsaved work"), "the state before restoring is kept")
    }

    func testDeleteGoesToRecentlyDeletedAndRestores() throws {
        let st = store()
        let p = project()
        try st.save(p)
        st.delete(p.id)
        XCTAssertEqual(st.list().count, 0)
        XCTAssertEqual(st.deletedProjects().map(\.id), [p.id])
        try st.restoreDeleted(p.id)
        XCTAssertEqual(st.list().map(\.id), [p.id])
        XCTAssertTrue(st.deletedProjects().isEmpty)
        st.delete(p.id)
        st.purgeDeleted(now: Date().addingTimeInterval(ProjectStore.deletedRetention + 60))
        XCTAssertTrue(st.deletedProjects().isEmpty, "gone after 30 days")
    }

    func testProjectListReadsLightweightMetadata() throws {
        let st = store()
        var p = project(); p.name = "meta"
        try st.save(p)
        let meta = st.folder(for: p.id).appendingPathComponent("meta.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: meta.path))
        XCTAssertEqual(st.list().first?.name, "meta")
        // An old project without meta.json still lists (and gets one).
        try FileManager.default.removeItem(at: meta)
        XCTAssertEqual(st.list().first?.name, "meta")
        XCTAssertTrue(FileManager.default.fileExists(atPath: meta.path))
    }

    func testThumbnailTimeStaysInsideComp() {
        var p = project(); p.duration = 4
        XCTAssertLessThan(EditorState.thumbnailTime(current: 4, project: p), 4)
        XCTAssertEqual(EditorState.thumbnailTime(current: 1, project: p), 1)
    }

    func testVideoImportCopiesFileAndReportsFailure() throws {
        let st = store()
        let p = project()
        try st.save(p)
        let src = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
        roots.append(src)
        try Data("not a movie".utf8).write(to: src)
        let name = try st.importMedia(fileAt: src, ext: "mov", into: p.id)
        XCTAssertTrue(FileManager.default.fileExists(atPath: st.mediaURL(name, projectID: p.id).path))
        let s = EditorState(project: p, store: st)
        XCTAssertFalse(s.addVideo(from: src))
        XCTAssertNotNil(s.recoveryNotice, "failure is shown to the user")
        XCTAssertTrue(s.project.layers.isEmpty)
    }
}
