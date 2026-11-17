import XCTest
@testable import AWIeffect

final class TextGeometryEffectTests:XCTestCase {
    private func layer(_ effect:EffectInstance?,vertical:Bool=false) -> Layer {
        var project=Project.new(name:"Glyph geometry",width:400,height:300,fps:30,duration:2,background:.black)
        var layer=project.makeLayer(name:"Text",content:.text,size:Vec2(300,100))
        var text=TextData(string:"AWI EFFECT");text.fontSize=44;text.vertical=vertical
        text.ensureCharIDs();layer.text=text;layer.effects=effect.map{[$0]} ?? []
        return layer
    }
    private func states(_ layer:Layer,time:Double=0.4) throws -> [Renderer.GlyphState] {
        let text=try XCTUnwrap(Renderer.renderTextData(layer,time:time))
        let layout=TextEngine.shared.layout(text,time:time)
        return TextEngine.glyphStates(text,layout:layout,time:time)
    }
    private func difference(_ a:[Renderer.GlyphState],_ b:[Renderer.GlyphState]) -> Double {
        zip(a,b).reduce(0.0){total,pair in
            total+abs(pair.0.offset.x-pair.1.offset.x)+abs(pair.0.offset.y-pair.1.offset.y)
                + abs(pair.0.rotation-pair.1.rotation)+abs(pair.0.rotX-pair.1.rotX)
                + abs(pair.0.rotY-pair.1.rotY)+abs(pair.0.z-pair.1.z)
        }
    }
    func testEveryGeometryChangesRealGlyphsAndFallsBackToDefaults() throws {
        for vertical in [false,true] {
            let original=try states(layer(nil,vertical:vertical))
            for definition in EffectRegistry.textGeometry37 {
                let rendered=try states(layer(definition.makeInstance(),vertical:vertical))
                XCTAssertGreaterThan(difference(original,rendered),0.01,definition.name)
                let fallback=try states(layer(EffectInstance(typeID:definition.id,params:[:]),vertical:vertical))
                XCTAssertLessThan(difference(rendered,fallback),0.00001,definition.name)
            }
        }
    }
    func testGeometryRespectsBlendStackMixAndSoloMute() throws {
        let original=try states(layer(nil))
        for definition in EffectRegistry.textGeometry37 {
            for key in ["blend",EffectStackR4.mixKey] {
                var effect=definition.makeInstance();effect.params[key] = .number(Animated(0))
                XCTAssertLessThan(difference(original,try states(layer(effect))),0.00001,definition.name)
            }
            var muted=definition.makeInstance();muted.text=["soloMute":"1"]
            XCTAssertLessThan(difference(original,try states(layer(muted))),0.00001,definition.name)
        }
    }
    func testNativeGeometryKeepsTextAnimationAndTransientStateOutOfSaveData() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi37.text.cylinder"))
        var original=layer(definition.makeInstance())
        var animator=TextAnimator(name:"Existing animation")
        animator.properties.position=Animated(Vec2(8,-12));original.text?.animators=[animator]
        let source=try XCTUnwrap(original.text)
        let rendered=try XCTUnwrap(Renderer.renderTextData(original,time:0.4))
        XCTAssertEqual(rendered.animators,source.animators)
        XCTAssertEqual(rendered.charIDs,source.charIDs)
        XCTAssertNotNil(rendered.geometryEffects)
        let encoded=try JSONEncoder().encode(rendered)
        let dictionary=try XCTUnwrap(JSONSerialization.jsonObject(with:encoded) as? [String:Any])
        XCTAssertNil(dictionary["geometryEffects"],"Geometry effects are saved on Layer.effects only")
        XCTAssertNil(try JSONDecoder().decode(TextData.self,from:encoded).geometryEffects)
        let savedLayer=try JSONDecoder().decode(Layer.self,from:JSONEncoder().encode(original))
        XCTAssertEqual(savedLayer.effects,original.effects)
    }
    func testGeometryAnimationChangesProjectedStateAndBoundsStayFinite() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi37.text.helix"))
        var effect=definition.makeInstance(),phase=Animated(0.0)
        phase.insertKeyframe(Keyframe(time:0,value:0));phase.insertKeyframe(Keyframe(time:1,value:180))
        effect.params["phase"] = .number(phase)
        let owner=layer(effect)
        XCTAssertGreaterThan(difference(try states(owner,time:0),try states(owner,time:0.5)),1)
        let text=try XCTUnwrap(Renderer.renderTextData(owner,time:0.5)),layout=TextEngine.shared.layout(text,time:0.5)
        let bounds=TextEngine.animatedBounds(text,layout:layout,time:0.5)
        XCTAssertTrue(bounds.minX.isFinite && bounds.minY.isFinite && bounds.width.isFinite && bounds.height.isFinite)
        XCTAssertGreaterThan(bounds.width,0);XCTAssertGreaterThan(bounds.height,0)
    }
    func testLetterSelectorAppliesGeometryOnlyToSelectedCharacterIDs() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi37.text.cylinder"))
        var owner=layer(nil)
        var text=try XCTUnwrap(owner.text)
        let selected=try XCTUnwrap(text.charIDs?.first)
        var animator=TextAnimator(name:"Selected geometry")
        animator.selector.targetIDs=[selected];animator.letterEffects=[definition.makeInstance()]
        text.animators=[animator];owner.text=text
        let rendered=try states(owner),original=try states(layer(nil))
        let layout=TextEngine.shared.layout(text,time:0.4)
        var changedSelected=false
        for (index,glyph) in layout.glyphs.enumerated() {
            let delta=difference([rendered[index]],[original[index]])
            if glyph.charID==selected { changedSelected = changedSelected || delta>0.01 }
            else { XCTAssertLessThan(delta,0.00001,"Unselected glyph moved") }
        }
        XCTAssertTrue(changedSelected)
    }
}
