import XCTest
@testable import AWIeffect

final class ResponsivePreviewTests:XCTestCase {
    func testEditorRevisionInvalidatesOnlyChangedContentAndExplicitRedraws() {
        let coordinator=MetalPreview.Coordinator()
        var project=Project.new(name:"Responsiveness",width:160,height:160,fps:60,duration:2)
        var layer=project.makeLayer(name:"Shape",content:.shape(.rectangle),size:Vec2(80,80))
        layer.effects=Array(repeating:EffectRegistry.deepGlow.makeInstance(),count:8)
        project.layers=[layer]
        coordinator.updateProject(project,redrawToken:0,contentRevision:1)
        let revision=coordinator.renderRevision
        for _ in 0..<240 { coordinator.updateProject(project,redrawToken:0,contentRevision:1) }
        XCTAssertEqual(coordinator.renderRevision,revision,"Playback ticks must not invalidate content caches")
        project.layers[0].transform.position=Animated(Vec2(30,40))
        coordinator.updateProject(project,redrawToken:0,contentRevision:2)
        XCTAssertEqual(coordinator.renderRevision,revision+1)
        coordinator.updateProject(project,redrawToken:1,contentRevision:2)
        XCTAssertEqual(coordinator.renderRevision,revision+2)
        coordinator.updateProject(project,redrawToken:1)
        XCTAssertEqual(coordinator.renderRevision,revision+3,"Derived views must return to safe equality checks")
    }
    func testRevisionFastPathCostOnLargeAnimatedComposition() {
        var project=Project.new(name:"Heavy project",width:1080,height:1920,fps:60,duration:10)
        for index in 0..<32 {
            var layer=project.makeLayer(name:"Layer \(index)",content:.shape(.rectangle),size:Vec2(200,200))
            layer.effects=[EffectRegistry.deepGlow.makeInstance(),EffectRegistry.gaussianBlur.makeInstance()]
            for key in 0..<50 { layer.transform.rotation.insertKeyframe(Keyframe(time:Double(key)/5,value:Double(key)*12)) }
            project.layers.append(layer)
        }
        let coordinator=MetalPreview.Coordinator();coordinator.updateProject(project,redrawToken:0,contentRevision:1)
        measure { for _ in 0..<1000 { coordinator.updateProject(project,redrawToken:0,contentRevision:1) } }
    }
    func testSupersededPreviewRequestsStayCancelled() {
        let old=TextPresetPreviewRequest(),current=TextPresetPreviewRequest()
        old.cancel();old.cancel()
        XCTAssertTrue(old.isCancelled);XCTAssertFalse(current.isCancelled)
    }
}
