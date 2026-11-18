import XCTest
@testable import AWIeffect

final class CraftPresets33Tests:XCTestCase {
    private func layer()->(Project,Layer) {
        let p=Project.new(name:"Premade test",width:640,height:360,fps:60,duration:6)
        var l=p.makeLayer(name:"User text",content:.text,size:Vec2(640,360))
        l.text=TextData(string:"Keep my words",fontSize:60)
        return (p,l)
    }
    func testBundledCountsAndRecipesAreNotDuplicatePayloads() throws {
        XCTAssertEqual(CraftPresets33.textRecipes.count,240)
        XCTAssertEqual(CraftPresets33.lookRecipes.count,60)
        XCTAssertEqual(CraftPresets33.layerRecipes.count,100)
        func check<T:Encodable>(_ entries:[T]) throws {
            var signatures=Set<Data>()
            for entry in entries {
                var payload=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(entry)) as? [String:Any])
                payload.removeValue(forKey:"id");payload.removeValue(forKey:"name")
                let signature=try JSONSerialization.data(withJSONObject:payload,options:.sortedKeys)
                XCTAssertTrue(signatures.insert(signature).inserted,"Duplicate functional recipe: \(entry)")
            }
        }
        try check(CraftPresets33.textRecipes);try check(CraftPresets33.lookRecipes);try check(CraftPresets33.layerRecipes)
    }
    func testEveryEffectAndParameterActuallyExists() throws {
        let specs=CraftPresets33.textRecipes.flatMap(\.effects)+CraftPresets33.lookRecipes.flatMap(\.effects)+CraftPresets33.layerRecipes.flatMap(\.effects)
        for spec in specs {
            let definition=try XCTUnwrap(EffectRegistry.definition(spec.id),spec.id)
            XCTAssertFalse(EffectRegistry.layerRefIDs.contains(spec.id),"Recipe needs a real reference layer: \(spec.id)")
            for (key,value) in spec.values {
                let param=try XCTUnwrap(definition.params.first{$0.id==key},"\(spec.id).\(key)")
                switch param.kind {
                case .number(let min,let max,_,_):XCTAssertTrue(value>=min && value<=max,"\(spec.id).\(key)=\(value) outside \(min)...\(max)")
                case .angle:XCTAssertTrue(value.isFinite)
                default:XCTFail("Numeric recipe supplied for nonnumeric \(spec.id).\(key)")
                }
            }
        }
        for recipe in CraftPresets33.textRecipes {
            XCTAssertTrue(["characters","words","lines"].contains(recipe.unit),recipe.id)
            XCTAssertTrue(["forward","reverse","random"].contains(recipe.order),recipe.id)
            XCTAssertTrue(["rise","drop","slide","whip","scale","slam","fold","rotate","skew","tracking","focus","baseline","scatter","decode","shutter","orbit","roll","perspective","depth","flip","hinge","fan","stretch","arc","elastic","bounce","wave","breath","pendulum","rubber","depthWave","spin","twist","hue","flicker","punch","rattle","squash","focusPulse","trackingWave","type"].contains(recipe.motion),recipe.id)
            XCTAssertTrue(["none","rebound","counter","squeeze","focus","lift","trail","edge"].contains(recipe.accent),recipe.id)
            if let material=recipe.material { XCTAssertNotNil(Text3DMaterial.preset(named:material),recipe.id) }
        }
        for recipe in CraftPresets33.lookRecipes {
            if let material=recipe.material { XCTAssertNotNil(Text3DMaterial.preset(named:material),recipe.id) }
        }
        for recipe in CraftPresets33.layerRecipes {
            XCTAssertTrue(["none","slide","whip","zoom","pull","spin","tilt","shake","bounce","breath","squash","fadeIn","fadeOut"].contains(recipe.motion),recipe.id)
        }
    }
    func testEveryNewTextGroupRemovesOnlyItsOwnComponentsAndRoundTrips() throws {
        for preset in CraftPresets33.textAnimations {
            var (_,l)=layer()
            let mine=TextAnimator(name:"User animation")
            let effect=try XCTUnwrap(EffectRegistry.definition("ae.gaussianBlur")).makeInstance()
            l.text!.animators=[mine];l.effects=[effect]
            TextPresetLibrary.applyPreset(preset,to:&l,start:1,duration:1)
            XCTAssertEqual(l.text?.string,"Keep my words")
            XCTAssertEqual(l.text?.animators.first?.id,mine.id)
            let decoded=try JSONDecoder().decode(Layer.self,from:JSONEncoder().encode(l))
            XCTAssertEqual(decoded,l)
            TextPresetLibrary.removePresetGroup(preset.id,from:&l)
            XCTAssertEqual(l.text?.animators.map(\.id),[mine.id],preset.id)
            XCTAssertEqual(l.effects,[effect],preset.id)
            XCTAssertNil(l.text?.text3D,preset.id)
        }
    }
    func testReal3DAndExistingUserGeometryArePreserved() throws {
        for preset in CraftPresets33.textAnimations where preset.category.hasPrefix("3D") {
            var (_,l)=layer()
            TextPresetLibrary.applyPreset(preset,to:&l,start:0)
            XCTAssertNotNil(l.text?.text3D,preset.id)
            XCTAssertEqual(l.text?.text3DGroup,preset.id)
            let userGeometry=Text3DOptions(material:.gold,extrusion:37)
            var (_,user)=layer();user.text?.text3D=userGeometry
            TextPresetLibrary.applyPreset(preset,to:&user,start:0)
            TextPresetLibrary.removePresetGroup(preset.id,from:&user)
            XCTAssertEqual(user.text?.text3D,userGeometry,preset.id)
        }
    }
    func testEveryLookCanBeReplacedAndRemovedWithoutDeletingUserStyle() {
        var (_,l)=layer()
        var style=TextStyleStack();style.strokes=[TextStrokeLayer(color:.black,width:3)]
        l.text?.style=style
        for look in CraftPresets33.textLooks {
            TextPresetLibrary.applyLook(look,to:&l)
            XCTAssertTrue(l.text!.style!.strokes.contains{$0.group==nil && $0.width.value(at:0)==3})
            XCTAssertTrue(l.effects.allSatisfy{$0.text?[TextPresetLibrary.effectGroupKey]==look.id})
        }
        if let last=CraftPresets33.textLooks.last { TextPresetLibrary.removePresetGroup(last.id,from:&l) }
        XCTAssertTrue(l.effects.isEmpty)
        XCTAssertNil(l.text?.text3D)
        XCTAssertEqual(l.text?.style?.strokes,style.strokes)
    }
    func testOutgoingPremadesUseTheClipTailAndRespectUserOpacity() {
        let (p,original)=layer()
        for preset in CraftPresets33.layerPresets where preset.kind == .transitionOut {
            var l=original;l.transform.opacity=Animated(50)
            let result=PresetLibrary.applying(preset,to:l,project:p,at:l.outPoint)
            XCTAssertEqual(result.transform.opacity.value(at:l.outPoint),0,accuracy:0.001,preset.id)
            XCTAssertEqual(result.transform.opacity.keyframes.first?.value ?? -1,50,accuracy:0.001,preset.id)
            XCTAssertTrue(result.transform.opacity.keyframes.allSatisfy{$0.time<=l.outPoint && $0.time>=l.inPoint},preset.id)
        }
    }
    func testPreviewKeyInvalidatesForAStyleColorChange() {
        var (_,l)=layer();var style=TextStyleStack()
        style.fills=[TextFillLayer(kind:.solid,colors:[.white])];l.text?.style=style
        let before=TextPresetPreviewSource(layer:l).key
        style.fills=[TextFillLayer(kind:.solid,colors:[.black])];l.text?.style=style
        XCTAssertNotEqual(before,TextPresetPreviewSource(layer:l).key)
    }
}
