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
}
