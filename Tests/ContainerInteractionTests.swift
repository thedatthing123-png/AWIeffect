import XCTest
@testable import AWIeffect

final class ContainerInteractionTests: XCTestCase {
    @MainActor private func editor() -> EditorState {
        var p = Project.new(name: "containers", width: 128, height: 128, fps: 30, duration: 3)
        for name in ["A", "B", "C", "D"] {
            p.layers.append(p.makeLayer(name: name, content: .solid, size: Vec2(20, 20)))
        }
        return EditorState(project: p, store: ProjectStore(root: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)))
    }

    @MainActor func testGroupIsOneRowAndInsideEditsReturnToParent() throws {
        let s = editor(), original = s.project.layers
        s.multiSelection = Set(original.prefix(2).map(\.id)); s.groupSelected()
        let group = try XCTUnwrap(s.selectedLayer)
        XCTAssertEqual(s.project.timelineLayers.map(\.id), [group.id, original[2].id, original[3].id])
        s.openGroup()
        XCTAssertEqual(s.project.timelineLayers.map(\.id), Array(original.prefix(2)).map(\.id))
        XCTAssertEqual(s.project.background.a, 0)
        s.selectedLayerID = original[0].id
        s.mutate("Rename") { $0.layers[0].name = "edited" }
        s.closePrecomp()
        XCTAssertEqual(s.project.layers.first(where: { $0.id == original[0].id })?.name, "edited")
        XCTAssertEqual(s.project.timelineLayers.count, 3)
    }

    @MainActor func testUngroupDropsContainerTreatmentsKeepsChildEffectsAndUndo() throws {
        let s = editor(), first = s.project.layers[0].id
        let childEffect = EffectRegistry.deepGlow.makeInstance()
        s.project.layers[0].effects = [childEffect]
        s.multiSelection = Set(s.project.layers.prefix(2).map(\.id)); s.groupSelected()
        let index = try XCTUnwrap(s.selectedIndex), gid = s.project.layers[index].id
        s.project.layers[index].effects = [EffectRegistry.lightSweep10.makeInstance()]
        s.project.layers[index].blendMode = .screen
        let grouped = s.project
        s.ungroupSelected()
        XCTAssertNil(s.recoveryNotice)
        XCTAssertFalse(s.project.layers.contains(where: { $0.id == gid }))
        XCTAssertEqual(s.project.layers.first(where: { $0.id == first })?.effects, [childEffect])
        XCTAssertEqual(s.project.timelineLayers.count, 4)
        s.undo()
        XCTAssertEqual(s.project.layers, grouped.layers)
    }

    @MainActor func testRangeSelectionUsesVisibleRowsAndDeleteCarriesChildren() throws {
        let s = editor(), original = s.project.layers
        s.multiSelection = Set(original.prefix(2).map(\.id)); s.groupSelected()
        let group = try XCTUnwrap(s.selectedLayer)
        s.beginMultiSelect(group.id); s.extendMultiSelect(toRow: 1)
        XCTAssertEqual(s.multiSelection, Set([group.id, original[2].id]))
        s.deleteMulti()
        XCTAssertEqual(s.project.layers.map(\.id), [original[3].id])
        s.undo()
        XCTAssertEqual(s.project.layers.count, 5)
    }

    @MainActor func testReorderAndDuplicateCarryGroupSubtreeAndUseDifferentTag() throws {
        let s = editor(), original = s.project.layers
        s.multiSelection = Set(original.prefix(2).map(\.id)); s.groupSelected()
        let group = try XCTUnwrap(s.selectedLayer)
        s.reorderTimelineLayer(group.id, to: 2)
        XCTAssertEqual(s.project.timelineLayers.map(\.id), [original[2].id, original[3].id, group.id])
        s.multiSelection = [group.id]; s.duplicateMulti()
        let copyID = try XCTUnwrap(s.multiSelection?.first)
        let copy = try XCTUnwrap(s.project.layers.first(where: { $0.id == copyID }))
        XCTAssertNotEqual(copy.tag, group.tag)
        XCTAssertEqual(s.parts(of: copy).count, 2)
        XCTAssertEqual(s.project.timelineLayers.count, 4)
    }

    @MainActor func testPrecomposingGroupIncludesItsHiddenChildren() throws {
        let s = editor(), original = s.project.layers
        s.multiSelection = Set(original.prefix(2).map(\.id)); s.groupSelected()
        let group = try XCTUnwrap(s.selectedLayer)
        s.multiSelection = [group.id]; s.precomposeMulti()
        guard case .precomp(let id) = s.selectedLayer?.content else { return XCTFail("Expected precomp") }
        let comp = try XCTUnwrap(s.project.precomps.first(where: { $0.id == id }))
        XCTAssertEqual(comp.layers.count, 3)
        XCTAssertEqual(comp.timelineLayers.count, 1)
        XCTAssertEqual(s.project.layers.count, 3)
    }

    func testOldContainerColorsAreDistinctStableAndSaved() throws {
        var p = Project.new(name: "old", width: 32, height: 32, fps: 30)
        for i in 0..<6 {
            var l = p.makeLayer(name: "Group \(i)", content: .solid, size: Vec2(32, 32))
            l.isGroup = true; l.tag = .teal; p.layers.append(l)
        }
        p.distinguishContainerTags()
        XCTAssertEqual(Set(p.layers.map(\.tag)).count, 6)
        let tags = p.layers.map(\.tag)
        p.distinguishContainerTags()
        XCTAssertEqual(p.layers.map(\.tag), tags)
        let decoded = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.layers.map(\.tag), tags)
    }
}
