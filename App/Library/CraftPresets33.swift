import Foundation

/// Authored recipes use normal editable animators, keyframes, effects and text
/// geometry. No flattened animation assets and no synthetic new effect wrappers.
struct PremadeEffect33:Codable,Equatable {
    var id:String
    var values:[String:Double]
    func make(start:Double,duration:Double,loop:Bool=false)->EffectInstance? {
        guard var effect=EffectRegistry.definition(id)?.makeInstance() else { return nil }
        for (key,value) in values { effect.params[key] = .number(Animated(value)) }
        effect.params[EffectStackR4.mixKey] = .number(TPB.kf([(start,0.0),(start+duration*0.18,100.0),
            (start+duration*0.72,100.0),(start+duration,loop ? 100.0:0.0)]))
        return effect
    }
}
struct TextPremade33:Codable,Equatable {
    var id:String;var name:String;var category:String;var motion:String;var unit:String;var order:String
    var amplitude:Double;var overlap:Double;var accent:String;var effects:[PremadeEffect33]
    var material:String?
}
struct TextLook33:Codable,Equatable {
    var id:String;var name:String;var category:String;var fill:String;var colors:[String]
    var stroke:Double;var stroke2:Double;var shadow:Double;var softness:Double;var glow:Double
    var material:String?;var depth:Double;var bevel:Double;var effects:[PremadeEffect33]
}
struct LayerPremade33:Codable,Equatable {
    var id:String;var name:String;var category:String;var motion:String;var amplitude:Double
    var duration:Double;var angle:Double;var effects:[PremadeEffect33]
}

enum CraftPresets33 {
    private static func read<T:Decodable>(_ name:String,_ type:T.Type)->T? {
        guard let url=Bundle.main.url(forResource:name,withExtension:"json"),let data=try? Data(contentsOf:url),
              let value=try? JSONDecoder().decode(type,from:data) else {
            NSLog("AWIeffect: missing or invalid preset catalog %@",name);return nil
        }
        return value
    }
    static let textRecipes:[TextPremade33]=read("text-premades33",[TextPremade33].self) ?? []
    static let lookRecipes:[TextLook33]=read("text-looks33",[TextLook33].self) ?? []
    static let layerRecipes:[LayerPremade33]=read("layer-premades33",[LayerPremade33].self) ?? []
    static let textAnimations:[TextPreset]=textRecipes.map { recipe in
        TextPreset(id:recipe.id,name:recipe.name,category:recipe.category,configureLayer:{ layer,start,duration in
            layer.effects += recipe.effects.compactMap{$0.make(start:start,duration:duration,loop:recipe.category.contains("Loop"))}
            if let name=recipe.material,layer.text?.text3D == nil {
                layer.text?.text3D=Text3DOptions(material:Text3DMaterial.preset(named:name) ?? .chrome,extrusion:18,bevelSize:2)
            }
        },make:{ start,duration in textMotion(recipe,start:start,duration:duration) })
    }
    private static func unit(_ name:String)->TextUnit { name=="words" ? .words:name=="lines" ? .lines:.characters }
    private static func order(_ name:String)->TPB.Order { name=="reverse" ? .reverse:name=="random" ? .random:.forward }
    static func textMotion(_ r:TextPremade33,start s:Double,duration d:Double)->[TextAnimator] {
        let unit=unit(r.unit),a=r.amplitude,isOut=r.category.contains("Out"),loop=r.category.contains("Loop")
        let selector:TextSelector
        if loop { selector=TPB.wave(s,freq:1/max(0.1,d),spread:r.overlap,unit,amount:TPB.kf([(s,0.0),(s+d*0.15,100.0)])) }
        else if ["Impact","Emphasis"].contains(r.category) {
            selector=TPB.accent(s,d,unit,delay:0,soft:r.overlap,order:order(r.order))
        } else { selector=TPB.reveal(s,d,unit,soft:r.overlap,order:order(r.order),out:isOut) }
        var primary=TPB.anim(r.name,selector) { p in
            switch r.motion {
            case "rise":p.position=Animated(Vec2(0,70*a));p.opacity=Animated(0);p.blur=Animated(5*a)
            case "drop":p.position=Animated(Vec2(0,-120*a));p.rotation=Animated(-8*a);p.opacity=Animated(0)
            case "slide":p.position=Animated(Vec2(-180*a,0));p.tracking=Animated(5*a);p.opacity=Animated(0)
            case "whip":p.position=Animated(Vec2(240*a,-25*a));p.directionalBlur=Animated(22*a);p.directionalBlurAngle=Animated(0);p.opacity=Animated(0)
            case "scale":p.scale=Animated(Vec2(15,15));p.tracking=Animated(12*a);p.opacity=Animated(0)
            case "slam":p.scale=Animated(Vec2(240*a,270*a));p.blur=Animated(9*a);p.rotation=Animated(5*a);p.opacity=Animated(0)
            case "fold":p.rotationX=Animated(85*a);p.anchor=Animated(Vec2(0,30));p.opacity=Animated(0)
            case "rotate":p.rotation=Animated(-120*a);p.position=Animated(Vec2(-40*a,50*a));p.opacity=Animated(0)
            case "skew":p.skew=Animated(55*a);p.position=Animated(Vec2(90*a,0));p.opacity=Animated(0)
            case "tracking":p.tracking=Animated(40*a);p.scale=Animated(Vec2(115,100));p.opacity=Animated(0)
            case "focus":p.blur=Animated(24*a);p.scale=Animated(Vec2(135,135));p.opacity=Animated(0)
            case "baseline":p.baselineShift=Animated(60*a);p.rotation=Animated(15*a);p.opacity=Animated(0)
            case "scatter":p.position=Animated(Vec2(150*a,-140*a));p.rotation=Animated(95*a);p.scale=Animated(Vec2(30,30));p.opacity=Animated(0)
            case "decode":p.scramble=Animated(100);p.opacity=Animated(0);p.characterOffset=Animated(11*a)
            case "shutter":p.scale=Animated(Vec2(100,1));p.tracking=Animated(9*a);p.opacity=Animated(0)
            case "orbit":p.rotationY=Animated(-110*a);p.positionZ=Animated(-220*a);p.rotation=Animated(12*a);p.opacity=Animated(0)
            case "roll":p.rotation=Animated(180*a);p.positionZ=Animated(-100*a);p.opacity=Animated(0)
            case "perspective":p.rotationY=Animated(70*a);p.skew=Animated(20*a);p.positionZ=Animated(180*a);p.opacity=Animated(0)
            case "depth":p.positionZ=Animated(-420*a);p.blur=Animated(12*a);p.tracking=Animated(8*a);p.opacity=Animated(0)
            case "flip":p.rotationY=Animated(180*a);p.scale=Animated(Vec2(75,75));p.opacity=Animated(0)
            case "hinge":p.anchor=Animated(Vec2(-35,0));p.rotationY=Animated(-100*a);p.position=Animated(Vec2(25*a,0));p.opacity=Animated(0)
            case "fan":p.rotation=Animated(65*a);p.rotationY=Animated(35*a);p.tracking=Animated(20*a);p.opacity=Animated(0)
            case "stretch":p.scale=Animated(Vec2(25,210*a));p.baselineShift=Animated(-15*a);p.opacity=Animated(0)
            case "arc":p.position=Animated(Vec2(-100*a,100*a));p.rotation=Animated(-60*a);p.anchor=Animated(Vec2(0,55));p.opacity=Animated(0)
            case "elastic":p.position=Animated(Vec2(0,85*a));p.scale=Animated(Vec2(65,145));p.opacity=Animated(0)
            case "bounce":p.position=Animated(Vec2(0,-45*a));p.scale=Animated(Vec2(118,82));p.rotation=Animated(6*a)
            case "wave":p.position=Animated(Vec2(0,-24*a));p.rotation=Animated(5*a)
            case "breath":p.scale=Animated(Vec2(100+12*a,100+12*a));p.tracking=Animated(2*a)
            case "pendulum":p.anchor=Animated(Vec2(0,-40));p.rotation=Animated(18*a)
            case "rubber":p.scale=Animated(Vec2(100+28*a,100-22*a));p.skew=Animated(8*a)
            case "depthWave":p.positionZ=Animated(110*a);p.rotationX=Animated(16*a)
            case "spin":p.rotationY=Animated(160*a);p.rotation=Animated(12*a)
            case "twist":p.rotationX=Animated(30*a);p.rotationY=Animated(-25*a);p.skew=Animated(8*a)
            case "hue":p.hueShift=Animated(120*a);p.glow=Animated(30*a)
            case "flicker":p.opacity=Animated(30);p.scramble=Animated(25*a)
            case "punch":p.scale=Animated(Vec2(100+45*a,100+40*a));p.rotation=Animated(-4*a)
            case "rattle":p.position=Animated(Vec2(12*a,-6*a));p.rotation=Animated(9*a);p.directionalBlur=Animated(4*a)
            case "squash":p.scale=Animated(Vec2(100+55*a,100-40*a));p.baselineShift=Animated(-8*a)
            case "focusPulse":p.blur=Animated(9*a);p.positionZ=Animated(25*a);p.glow=Animated(45*a)
            case "trackingWave":p.tracking=Animated(10*a);p.position=Animated(Vec2(0,-6*a))
            case "type":p.opacity=Animated(0)
            default:break
            }
        }
        if r.motion=="type" { primary.selector.shape = .square;primary.selector.easeHigh=0;primary.selector.easeLow=0 }
        if r.motion=="rattle" || r.motion=="flicker" {
            primary.selector.kind = .wiggly;primary.selector.frequency=Animated(9/max(0.2,d));primary.selector.seed=17
            primary.selector.minAmount = -100;primary.selector.maxAmount=100
            primary.selector.amount=TPB.kf([(s,0.0),(s+d*0.15,100.0),(s+d,loop ? 100.0:0.0)])
        }
        var result=[primary]
        if r.accent != "none" {
            let secondary=TPB.accent(s,d,unit,delay:0.13,soft:max(12,r.overlap*0.65),order:order(r.order))
            result.append(TPB.anim(r.accent,secondary) { p in
                switch r.accent {
                case "rebound":p.position=Animated(Vec2(0,-18*a));p.scale=Animated(Vec2(108,94))
                case "counter":p.rotation=Animated(12*a);p.position=Animated(Vec2(12*a,-8*a))
                case "squeeze":p.scale=Animated(Vec2(118,85));p.tracking=Animated(-2*a)
                case "focus":p.blur=Animated(7*a);p.glow=Animated(35*a)
                case "lift":p.positionZ=Animated(55*a);p.rotationX=Animated(-12*a)
                case "trail":p.directionalBlur=Animated(14*a);p.directionalBlurAngle=Animated(25)
                default:p.strokeWidth=Animated(2*a);p.glow=Animated(20*a)
                }
            })
        }
        return result
    }

    static let textLooks:[TextLookPreset]=lookRecipes.map { recipe in
        let colors=recipe.colors.map{RGBA(hex:UInt32($0,radix:16) ?? 0xFFFFFF)}
        var style=TextStyleStack()
        let kind:TextFillKind=recipe.fill=="radial" ? .radial:recipe.fill=="linear" ? .linear:.solid
        style.fills=[TextFillLayer(kind:kind,colors:colors,angle:90)]
        if recipe.stroke>0 { style.strokes.append(TextStrokeLayer(color:.black,width:recipe.stroke)) }
        if recipe.stroke2>0 { style.strokes.append(TextStrokeLayer(color:colors.last ?? .white,width:recipe.stroke+recipe.stroke2)) }
        if recipe.shadow>0 { style.shadows.append(TextShadowLayer(distance:recipe.shadow,blur:recipe.softness)) }
        if recipe.glow>0 { var glow=TextGlowLayer();glow.radius=Animated(recipe.glow);glow.useFillColor=true;style.glow=glow }
        var geometry:Text3DOptions?
        if let material=recipe.material {
            geometry=Text3DOptions(material:Text3DMaterial.preset(named:material) ?? .chrome,extrusion:recipe.depth,bevelSize:recipe.bevel)
            geometry?.front.color=Animated(colors.first ?? .white)
        }
        return TextLookPreset(id:recipe.id,name:recipe.name,category:recipe.category,style:style,
            effects:recipe.effects.map{($0.id,$0.values.mapValues{.number(Animated($0))})},text3D:geometry)
    }

    static let layerPresets:[LayerPreset]=layerRecipes.map { recipe in
        LayerPreset(id:recipe.id,name:recipe.name,kind:LayerPreset.Kind(rawValue:recipe.category) ?? .manga,symbol:symbol(recipe.category)) { layer,project,start in
            applyLayer(recipe,to:&layer,project:project,start:start)
        }
    }
    private static func symbol(_ category:String)->String {
        switch category { case "Shakes":return "waveform.path";case "Glow & Light":return "sun.max";case "Loops":return "repeat";case "Looks & CC":return "paintpalette";default:return "sparkles" }
    }
    static func applyLayer(_ recipe:LayerPremade33,to layer:inout Layer,project:Project,start anchor:Double) {
        let outgoing=recipe.category=="Out"
        let s=outgoing ? max(layer.inPoint,anchor-recipe.duration):anchor
        let d=min(recipe.duration,max(0.05,layer.outPoint-s)),a=recipe.amplitude,angle=recipe.angle*Double.pi/180
        let at=layer.transform.position.value(at:s),scale=layer.transform.scale.value(at:s),rotation=layer.transform.rotation.value(at:s)
        let offset=Vec2(cos(angle),sin(angle))*min(Double(project.width),Double(project.height))*a*0.01
        switch recipe.motion {
        case "slide":layer.transform.position=insert(layer.transform.position,outgoing ? [(s,at),(s+d,at+offset)]:[(s,at+offset),(s+d,at)])
        case "whip":layer.transform.position=insert(layer.transform.position,outgoing ? [(s,at),(s+d*0.2,at-offset*0.05),(s+d,at+offset)]:[(s,at+offset),(s+d*0.7,at-offset*0.05),(s+d,at)])
        case "zoom":layer.transform.scale=insert(layer.transform.scale,[(s,scale*(1+a*0.01)),(s+d,scale)])
        case "pull":layer.transform.scale=insert(layer.transform.scale,[(s,scale),(s+d,scale*(1+a*0.01))])
        case "spin":layer.transform.rotation=insert(layer.transform.rotation,outgoing ? [(s,rotation),(s+d,rotation+a)]:[(s,rotation+a),(s+d,rotation)])
        case "tilt":
            let yaw=layer.transform.rotationY.value(at:s)
            layer.is3D=true;layer.transform.rotationY=insert(layer.transform.rotationY,[(s,yaw+a),(s+d,yaw)])
        case "shake":
            let fractions:[Double]=[0,0.12,0.25,0.4,0.58,0.77,1],weights:[Double]=[0,1,-0.72,0.48,-0.29,0.1,0]
            layer.transform.position=insert(layer.transform.position,zip(fractions,weights).map{(s+$0.0*d,at+offset*$0.1)})
            layer.transform.rotation=insert(layer.transform.rotation,zip(fractions,weights).map{(s+$0.0*d,rotation+$0.1*a*0.04)})
        case "bounce":layer.transform.position=insert(layer.transform.position,[(s,at),(s+d*0.3,at-offset),(s+d*0.6,at+offset*0.25),(s+d,at)])
        case "breath":layer.transform.scale=insert(layer.transform.scale,[(s,scale),(s+d*0.5,scale*(1+a*0.01)),(s+d,scale)])
        case "squash":layer.transform.scale=insert(layer.transform.scale,[(s,scale),(s+d*0.3,Vec2(scale.x*(1+a*0.01),scale.y*(1-a*0.007))),(s+d,scale)])
        // LayerPreset's application wrapper multiplies normalized opacity by
        // the user's opacity. Do not multiply it a second time here.
        case "fadeIn":layer.transform.opacity=insert(layer.transform.opacity,[(s,0),(s+d,100)])
        case "fadeOut":layer.transform.opacity=insert(layer.transform.opacity,[(s,100),(s+d,0)])
        default:break
        }
        if outgoing && recipe.motion != "fadeOut" {
            layer.transform.opacity=insert(layer.transform.opacity,[(s,100),(s+d*0.8,100),(s+d,0)])
        }
        let loop=recipe.category=="Loops",persistent=recipe.category=="Looks & CC"
        if loop {
            // Native expressions repeat only the new end-of-track keys. Existing
            // expressions belong to the user and are preserved.
            if ["shake","bounce"].contains(recipe.motion),layer.transform.position.expression == nil {
                layer.transform.position.expression="loopOut('cycle', \(recipe.motion=="shake" ? 6:3))"
            }
            if ["breath","squash"].contains(recipe.motion),layer.transform.scale.expression == nil { layer.transform.scale.expression="loopOut('cycle', 2)" }
            if recipe.motion=="shake",layer.transform.rotation.expression == nil { layer.transform.rotation.expression="loopOut('cycle', 6)" }
        }
        for spec in recipe.effects {
            guard var effect=spec.make(start:s,duration:d,loop:loop||persistent) else { continue }
            if persistent { effect.params[EffectStackR4.mixKey] = .number(Animated(100)) }
            var tags=effect.text ?? [:];tags[TextPresetLibrary.effectGroupKey]=recipe.id;effect.text=tags
            layer.effects.append(effect)
        }
    }
    private static func insert<V:Interpolatable>(_ input:Animated<V>,_ keys:[(Double,V)])->Animated<V> {
        var result=input
        for (time,value) in keys { var key=Keyframe(time:time,value:value,interpolation:.bezier);key.curve=EaseCurve(.cubicOut);result.insertKeyframe(key) }
        return result
    }
}
