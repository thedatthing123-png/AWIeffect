import XCTest
@testable import AWIeffect

final class SurfaceEffectTests:XCTestCase {
    private func render(_ effect:EffectInstance?,adjustment:Bool) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:DataEffectTests.scene(effect,onAdjustment:adjustment),
            time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    func testSurfaceUniformLayoutAndBrowserPlacement() {
        XCTAssertEqual(MemoryLayout<SurfaceParams40>.stride,128)
        XCTAssertEqual(EffectRegistry.surfaces40.count,21)
        for definition in EffectRegistry.surfaces40 { XCTAssertEqual(EffectSection.of(definition),.threeD) }
    }
    func testSurfaceDefaultsFallbacksAndBypassOnLayersAndAdjustments() throws {
        for adjustment in [false,true] {
            let original=try render(nil,adjustment:adjustment)
            for definition in EffectRegistry.surfaces40 {
                var effect=definition.makeInstance()
                let output=try render(effect,adjustment:adjustment)
                XCTAssertGreaterThan(zip(original,output).filter{abs(Int($0.0)-Int($0.1))>2}.count,50,definition.name)
                XCTAssertEqual(output,try render(EffectInstance(typeID:definition.id,params:[:]),adjustment:adjustment),definition.name)
                effect.params["blend"] = .number(Animated(0))
                XCTAssertEqual(original,try render(effect,adjustment:adjustment),definition.name)
            }
        }
    }
}
