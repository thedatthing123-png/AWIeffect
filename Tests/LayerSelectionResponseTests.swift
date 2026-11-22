import XCTest
@testable import AWIeffect

@MainActor final class LayerSelectionResponseTests:XCTestCase {
    private func editor()->EditorState {
        var p=Project.new(name:"Selection",width:640,height:360,fps:60,duration:3)
        p.layers=[p.makeLayer(name:"First",content:.shape(.rectangle),size:Vec2(100,100)),
                  p.makeLayer(name:"Second",content:.shape(.star),size:Vec2(100,100))]
        return EditorState(project:p)
    }
    func testSingleTapOpensImmediatelyWithoutChangingProjectOrUndo() {
        let state=editor(),original=state.project,id=original.layers[1].id
        state.tapTimelineLayer(id,timestamp:1)
        XCTAssertEqual(state.selectedLayerID,id)
        XCTAssertEqual(state.panel,.layerHome)
        XCTAssertEqual(state.project,original)
        XCTAssertFalse(state.canUndo)
        state.tapTimelineLayer(original.layers[0].id,timestamp:1.1)
        XCTAssertEqual(state.selectedLayerID,original.layers[0].id)
        XCTAssertEqual(state.panel,.layerHome)
    }
    func testMultiSelectionStillTogglesOnlyOncePerTap() {
        let state=editor(),a=state.project.layers[0].id,b=state.project.layers[1].id
        state.beginMultiSelect(a)
        state.tapTimelineLayer(b,timestamp:1)
        XCTAssertTrue(state.multiSelection?.contains(b) == true)
        state.tapTimelineLayer(b,timestamp:1.1)
        XCTAssertFalse(state.multiSelection?.contains(b) == true)
    }
    func testDoubleTapStillOpensGroupButOneTapDoesNot() {
        let state=editor()
        state.beginMultiSelect(state.project.layers[0].id)
        state.toggleInMulti(state.project.layers[1].id)
        state.groupSelected()
        guard let group=state.project.layers.first(where:{$0.isGroup}) else { return XCTFail("Group fixture failed") }
        let rootID=state.project.id
        state.select(nil)
        state.tapTimelineLayer(group.id,timestamp:1)
        XCTAssertEqual(state.project.id,rootID)
        XCTAssertEqual(state.panel,.layerHome)
        state.tapTimelineLayer(group.id,timestamp:1.12)
        XCTAssertEqual(state.project.id,group.id)
        XCTAssertNil(state.selectedLayerID)
    }
    func testStableSurfaceCompletesContainerDoubleTapAfterTheRowMoves() {
        let state=editor()
        state.select(state.project.layers[0].id);state.groupSelected()
        guard let group=state.project.layers.first(where:{$0.isGroup}) else { return XCTFail("Missing group") }
        state.select(nil);state.tapTimelineLayer(group.id,timestamp:1)
        XCTAssertEqual(state.panel,.layerHome)
        // The second touch may hit empty canvas after the first opened a panel.
        state.select(nil)
        state.finishTimelineContainerDoubleTap(timestamp:1.25)
        XCTAssertEqual(state.project.id,group.id)
    }
    func testStableSurfaceDoesNotOpenAnExpiredTapOrAnOrdinaryLayer() {
        let state=editor(),root=state.project.id
        state.tapTimelineLayer(state.project.layers[0].id,timestamp:1)
        state.finishTimelineContainerDoubleTap(timestamp:1.2)
        XCTAssertEqual(state.project.id,root)
        state.groupSelected();let group=state.selectedLayerID!
        state.select(nil);state.tapTimelineLayer(group,timestamp:2)
        state.finishTimelineContainerDoubleTap(timestamp:3)
        XCTAssertEqual(state.project.id,root)
    }
    func testWindowTapHistorySurvivesRowReflowAndCallbackOrdering() throws {
        let state = editor()
        state.select(state.project.layers[0].id); state.groupSelected()
        let group = try XCTUnwrap(state.project.layers.first(where: { $0.isGroup }))
        let root = state.project.id
        state.select(nil)
        let point = Vec2(230, 500)
        // The UIKit observation may arrive before the SwiftUI row action.
        state.observeTimelineWindowTap(point: point, timestamp: 1, container: group.id)
        state.tapTimelineLayer(group.id, timestamp: 1.01)
        XCTAssertEqual(state.project.id, root, "One tap must select immediately without opening")
        // Reflow loses the second row event, but not window-touch history.
        state.observeTimelineWindowTap(point: point, timestamp: 1.18)
        XCTAssertEqual(state.project.id, group.id)
        state.observeTimelineWindowTap(point: point, timestamp: 1.181)
        XCTAssertEqual(state.project.id, group.id, "Duplicate observations must not open another level")
    }
    func testUnrelatedAndExpiredWindowTapsCannotOpenAContainer() throws {
        for distant in [false, true] {
            let state = editor()
            state.select(state.project.layers[0].id); state.groupSelected()
            let group = try XCTUnwrap(state.project.layers.first(where: { $0.isGroup }))
            let root = state.project.id
            state.select(nil); state.tapTimelineLayer(group.id, timestamp: 1)
            state.observeTimelineWindowTap(point: Vec2(100, 100), timestamp: 1.001, container: group.id)
            state.observeTimelineWindowTap(point: distant ? Vec2(200, 100) : Vec2(100, 100), timestamp: distant ? 1.2 : 2)
            XCTAssertEqual(state.project.id, root)
        }
    }

    func testRawContainerTouchDoesNotDependOnDelayedRowCallback() throws {
        let state = editor()
        state.select(state.project.layers[0].id); state.groupSelected()
        let group = try XCTUnwrap(state.project.layers.first(where: { $0.isGroup }))
        state.select(nil)
        state.observeTimelineWindowTap(point: Vec2(200, 400), timestamp: 1, container: group.id)
        state.observeTimelineWindowTap(point: Vec2(200, 400), timestamp: 1.05)
        XCTAssertEqual(state.project.id, group.id)
    }
    func testStartingADragCancelsPendingContainerTaps() throws {
        let state=editor()
        state.select(state.project.layers[0].id);state.groupSelected()
        let group=try XCTUnwrap(state.project.layers.first(where:{$0.isGroup})),root=state.project.id
        state.select(nil)
        state.tapTimelineLayer(group.id,timestamp:1)
        state.observeTimelineWindowTap(point:Vec2(200,400),timestamp:1,container:group.id)
        state.cancelTimelineWindowTap()
        state.observeTimelineWindowTap(point:Vec2(200,400),timestamp:1.15)
        XCTAssertEqual(state.project.id,root)
        state.tapTimelineLayer(group.id,timestamp:1.2)
        XCTAssertEqual(state.project.id,root)
    }

}
