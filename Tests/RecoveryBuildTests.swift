import XCTest
@testable import AWIeffect

final class RecoveryBuildTests:XCTestCase {
    func testCatalogReturnsToPreExpansionToolsAndPremades() {
        for definition in EffectRegistry.all {
            XCTAssertFalse((30...48).contains{definition.id.hasPrefix("awi\($0).")},definition.id)
        }
        XCTAssertNotNil(EffectRegistry.definition("awi.deepGlow"))
        XCTAssertNotNil(EffectRegistry.definition("ae.gaussianBlur"))
        XCTAssertFalse(TextPresetLibrary.animations.contains{$0.id.hasPrefix("craft33.")})
        XCTAssertFalse(PresetLibrary.all.contains{$0.id.hasPrefix("craft33.")})
        XCTAssertNil(Bundle.main.url(forResource:"text-premades33",withExtension:"json"))
        XCTAssertNil(Bundle.main.url(forResource:"SAM2_1TinyImageEncoderFLOAT16",withExtension:"mlmodelc"))
    }
    func testUnsupportedArchivedEffectDataIsNotDiscardedOnSave()throws {
        let archived=EffectInstance(typeID:"awi48.craft.junctions",params:["first":.number(Animated(24))])
        let data=try JSONEncoder().encode(archived)
        let decoded=try JSONDecoder().decode(EffectInstance.self,from:data)
        XCTAssertEqual(decoded,archived)
        XCTAssertNil(EffectRegistry.definition(decoded.typeID))
    }
}
