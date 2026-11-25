import XCTest
@testable import AWIeffect

final class ArtworkRigTests: XCTestCase {
    func testArtworkRigRoundTripsWithoutAddingTimelineLayers() throws {
        var project = Project.new(name: "Rig", width: 200, height: 200, fps: 30, duration: 2)
        var artwork = project.makeLayer(name: "Artwork", content: .image(fileName: "arm.png", pixelWidth: 200, pixelHeight: 200), size: Vec2(200, 200))
        let upper = ArtworkBone(name: "Upper arm", start: Vec2(0, 0), end: Vec2(0, 40))
        let lower = ArtworkBone(name: "Forearm", start: Vec2(0, 40), end: Vec2(20, 70))
        var rig = ArtworkRig(bones: [upper, lower])
        rig.reparent(lower.id, to: upper.id)
        XCTAssertFalse(rig.canParent(upper.id, to: lower.id))
        artwork.artworkRig = rig
        project.layers = [artwork]
        let restored = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(restored.layers.count, 1)
        XCTAssertEqual(restored.layers.first?.artworkRig, rig)
    }
}
