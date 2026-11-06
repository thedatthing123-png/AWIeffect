import XCTest
@testable import AWIeffect

/// A slider drag cancelled by a scroll view must never leave edits trapped in the live copy.
@MainActor final class GestureSyncTests: XCTestCase {
    private func editor() -> EditorState {
        var p = Project.new(name: "sync", width: 100, height: 100, fps: 30, duration: 2, background: .black)
        p.layers = [p.makeLayer(name: "a", content: .solid, size: Vec2(50, 50))]
        let s = EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
        s.selectedLayerID = p.layers[0].id
        return s
    }

    func testAddingAnEffectAfterAStuckDragLandsInTheProject() throws {
        let s = editor()
        s.beginScrub()          // a slider drag whose end never arrived
        s.beginEdit("Edit")
        let def = try XCTUnwrap(EffectRegistry.all.first { $0.name == "Halftone" })
        s.addEffect(def)
        XCTAssertFalse(s.isLiveGesture)
        XCTAssertEqual(s.project.layers[0].effects.count, 1, "the panel reads the project, so the effect must be there")
        XCTAssertNil(s.live.project)
    }

    func testChangingPanelsFinishesAStuckDrag() {
        let s = editor()
        s.beginScrub()
        s.mutateLayer { $0.transform.positionZ.set(120, at: 0) }
        s.panel = .transform
        XCTAssertFalse(s.isLiveGesture)
        XCTAssertEqual(s.project.layers[0].transform.positionZ.value(at: 0), 120, accuracy: 1e-9)
    }

    func testNumberDragIsOneUndoStepAndUpdatesLive() {
        let s = editor()
        s.beginPanelGesture("Edit Z")
        for z in stride(from: 10.0, through: 90, by: 10) { s.mutateLayer { $0.transform.positionZ.set(z, at: 0) } }
        XCTAssertEqual(s.canvasProject.layers[0].transform.positionZ.value(at: 0), 90, accuracy: 1e-9)
        s.endPanelGesture()
        XCTAssertEqual(s.project.layers[0].transform.positionZ.value(at: 0), 90, accuracy: 1e-9)
        s.undo()
        XCTAssertEqual(s.project.layers[0].transform.positionZ.value(at: 0), 0, accuracy: 1e-9)
    }
}
