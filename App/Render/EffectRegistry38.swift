import Foundation
import Metal
import simd

extension EffectRegistry {
    static let surfaces38:[EffectDefinition] = [
        EffectDefinition(id:"awi38.surface.contourBloom",name:"Contour Bloom",category:.color,aeMatchNames:[],
            summary:"Turn image contours into a sharp luminous core and a separately colored multi-scale halo.",
            params:[.number("detail","Contour Scale",3,0.5,30,unit:"px"),
                .number("threshold","Contour Threshold",10,0,100,unit:"%"),
                .number("softness","Threshold Softness",15,1,100,unit:"%"),
                .number("radius","Halo Radius",35,1,300,unit:"px"),
                .number("core","Core Light",1.5,0,8),.number("halo","Halo Light",2,0,8),
                .color("color","Core Color",RGBA(0.7,0.95,1)),.color("color2","Halo Color",RGBA(0.2,0.35,1)),
                .number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)],
            margin:{ e,t in 3*(e.params["radius"]?.number(at:t) ?? 35) },stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let soft=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:v29(ctx,"detail")*ctx.unit)
                var p=EffectParams();p.a=SIMD4(pc29(ctx,"threshold"),pc29(ctx,"softness"),0,0)
                let contour=ctx.temp()
                ctx.gpu.run("fxContourSource38",ctx.cb,textures:[ctx.input,contour,soft],params:p,grid:contour)
                let halo=lightBloom25(ctx,contour,radius:v29(ctx,"radius")*ctx.unit,falloff:0.6)
                return surfaceComposite38(ctx,base:ctx.input,core:contour,halo:halo)
            }),
        EffectDefinition(id:"awi38.surface.glassRelief",name:"Glass Relief",category:.distort,aeMatchNames:[],
            summary:"Image brightness shapes a refracting relief with movable specular light and a separately softened reflection halo.",
            params:[.number("detail","Surface Smoothing",2,0.5,20,unit:"px"),
                .number("height","Relief Height",18,-80,80),.number("refraction","Refraction",1.2,0,4),
                .angle("angle","Light Direction",-40),.number("elevation","Light Elevation",35,5,85,unit:"°"),
                .number("gloss","Gloss",32,2,128),.number("radius","Reflection Halo",12,1,120,unit:"px"),
                .number("core","Reflection",1.5,0,8),.number("halo","Halo Light",0.8,0,8),
                .color("color","Reflection Color",RGBA(0.85,0.95,1)),.color("color2","Halo Color",RGBA(0.4,0.6,1)),
                .number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)],
            margin:{ e,t in 3*(e.params["radius"]?.number(at:t) ?? 12)+abs(e.params["height"]?.number(at:t) ?? 18)*(e.params["refraction"]?.number(at:t) ?? 1.2) },
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let soft=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:v29(ctx,"detail")*ctx.unit)
                var p=EffectParams();p.a=SIMD4(f29(ctx,"height"),f29(ctx,"refraction")*Float(ctx.unit),f29(ctx,"gloss"),0)
                p.b=SIMD4(f29(ctx,"angle") * .pi/180,f29(ctx,"elevation") * .pi/180,Float(max(0.5,ctx.unit)),0)
                let refraction=ctx.temp(),reflection=ctx.temp()
                ctx.gpu.run("fxGlassSurface38",ctx.cb,textures:[ctx.input,refraction,soft,reflection],params:p,grid:refraction)
                let halo=ctx.gpu.gaussian(ctx,input:reflection,sigma:v29(ctx,"radius")*ctx.unit)
                return surfaceComposite38(ctx,base:refraction,core:reflection,halo:halo)
            })
    ]
    private static func surfaceComposite38(_ ctx:EffectContext,base:MTLTexture,core:MTLTexture,halo:MTLTexture) -> MTLTexture {
        var p=EffectParams();p.a=SIMD4(f29(ctx,"core"),f29(ctx,"halo"),pc29(ctx,"blend"),b29(ctx,"only") ? 1:0)
        p.b=col29(ctx,"color");p.c=col29(ctx,"color2")
        let output=ctx.temp()
        ctx.gpu.run("fxSurfaceComposite38",ctx.cb,textures:[ctx.input,output,base,core,halo],params:p,grid:output)
        return output
    }

    static let batch38:[EffectDefinition]=[
        motionLight38("motionGlow","Motion Glow",0,"Changes between actual upstream frames emit a multi-scale glow while the current image remains intact.",
            [.number("radius","Glow Radius",60,1,400,unit:"px"),.number("falloff","Halo Falloff",60,0,100,unit:"%")]),
        motionLight38("motionStreaks","Motion Streaks",1,"Temporal image changes emit directional light streaks with independent reach, direction and decay.",
            [.number("radius","Streak Length",100,1,500,unit:"px"),.angle("angle","Streak Direction",0),.number("falloff","Streak Decay",2,0.1,8)]),
        motionLight38("motionRays","Motion Rays",2,"Changing image regions emit source-driven radial rays through an editable optical center.",
            [.number("reach","Ray Reach",70,1,100,unit:"%"),.number("falloff","Ray Decay",2,0.1,8),.point("center","Ray Center",Vec2(0.5,0.5))]),
        motionLight38("motionRings","Motion Rings",3,"Temporal changes spread into hollow light rings, with separate ring radius and soft thickness.",
            [.number("radius","Ring Radius",24,1,240,unit:"px"),.number("width","Ring Thickness",3,0.5,40,unit:"px")])
    ]
    private static func motionLight38(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi38."+id,name:name,category:.color,aeMatchNames:[],summary:summary,
            params:[.number("delay","Frame Difference",0.1,-2,2,unit:"s"),
                .choice("source","Changing Detail",["Color","Luminance","Alpha"],0),
                .number("threshold","Emission Threshold",15,0,100,unit:"%"),
                .number("softness","Threshold Softness",20,1,100,unit:"%")]+controls+[
                .number("intensity","Light Intensity",1.5,0,8),.color("tint","Light Tint",RGBA(0.4,0.65,1)),
                .number("tintMix","Tint Mix",25,0,100,unit:"%"),.number("blend","Blend",100,0,100,unit:"%"),
                .toggle("only","Effect Only",false)],
            margin:{effect,time in
                let radius=effect.params["radius"]?.number(at:time) ?? (mode==0 ? 60:mode==1 ? 100:24)
                if mode==2 { return 0 }
                return mode==0 ? radius*2:radius+3*(effect.params["width"]?.number(at:time) ?? 0)
            },stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                if v29(ctx,"intensity")<=0 {
                    if b29(ctx,"only") { let out=ctx.temp();ctx.gpu.run("fxClear",ctx.cb,textures:[out],grid:out);return out }
                    return ctx.input
                }
                if abs(v29(ctx,"delay"))<0.00001 && !b29(ctx,"only") { return ctx.input }
                guard let sample=ctx.temporalSample,
                      let old=sample(ctx.time-v29(ctx,"delay")) else { return ctx.input }
                var p=EffectParams();p.i.x=UInt32(ch29(ctx,"source"))
                p.a=SIMD4(pc29(ctx,"threshold"),pc29(ctx,"softness"),pc29(ctx,"tintMix"),0);p.b=col29(ctx,"tint")
                let emission=ctx.temp()
                ctx.gpu.run("fxChangeSource38",ctx.cb,textures:[ctx.input,emission,old],params:p,grid:emission)
                let light:MTLTexture
                switch mode {
                case 0:light=lightBloom25(ctx,emission,radius:v29(ctx,"radius")*ctx.unit,falloff:v29(ctx,"falloff")/100)
                case 1:light=streak25(ctx,light:emission,mode:.linear,length:v29(ctx,"radius")*ctx.unit,
                    rotation:v29(ctx,"angle")*Double.pi/180,decay:v29(ctx,"falloff"))
                case 2:
                    let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                    light=streak25(ctx,light:emission,mode:.godRays,length:v29(ctx,"reach")/100,
                        center:SIMD2(Float(center.x*Double(ctx.width)),Float(center.y*Double(ctx.height))),decay:v29(ctx,"falloff"))
                default:
                    let soft=ctx.gpu.gaussian(ctx,input:emission,sigma:v29(ctx,"width")*ctx.unit)
                    var ring=EffectParams();ring.a.x=px29(ctx,"radius")
                    light=ctx.temp();ctx.gpu.run("fxOptical36",ctx.cb,textures:[soft,light],params:ring,grid:light)
                }
                let composed=lightComp25(ctx,base:ctx.input,glow:light,intensity:v29(ctx,"intensity")*v29(ctx,"blend")/100,
                    composite:b29(ctx,"only") ? .glowOnly:.over)
                if b29(ctx,"only") { return composed }
                // The shared light shoulder also rolls off untouched pure white.
                // For this change-driven composite, no emitted light must mean
                // exact passthrough, without changing older glow definitions.
                let out=ctx.temp()
                ctx.gpu.run("fxChangeComposite38",ctx.cb,textures:[ctx.input,out,composed,light],grid:out)
                return out
            })
    }
}
