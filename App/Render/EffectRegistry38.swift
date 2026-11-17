import Foundation
import Metal
import simd

extension EffectRegistry {
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
