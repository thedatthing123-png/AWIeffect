import Foundation
import Metal
import simd

extension EffectRegistry {
    static let frequency37: [EffectDefinition] = [
        frequency37("detailBands","Detail Bands",0,
            "Separate fine texture, middle detail and broad structure with independent signed gains.",
            [.number("fine","Fine Detail",1.5,-2,4),.number("middle","Middle Detail",1.3,-2,4),
             .number("broad","Broad Structure",0.85,-2,4)]),
        frequency37("bandPass","Band Pass",1,
            "Isolate a finite range of image detail between two Gaussian scales, excluding both flat illumination and very fine noise.",
            [.number("gain","Detail Gain",2,0,8),.number("bias","Gray Level",50,0,100,unit:"%")]),
        frequency37("retinexDetail","Retinex Detail",2,
            "Luminance-only log-ratio detail from three surround scales, blended with the original illumination and hue.",
            [.number("strength","Illumination Recovery",55,0,100,unit:"%"),
             .number("contrast","Detail Contrast",0.7,0.1,2),
             .number("floor","Shadow Floor",1,0.1,10,unit:"%")])
    ]
    private static func frequency37(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi37."+id,name:name,category:.blur,aeMatchNames:[],summary:summary,
            params:[.number("radius","Detail Scale",4,0.5,48,unit:"px"),
                .number("spread","Scale Separation",4,1.5,12)]+controls+[
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let radius=v29(ctx,"radius")*ctx.unit,spread=v29(ctx,"spread")
                let near=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius)
                let middle=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius*spread)
                // Third scale is only needed by the log-surround operation.
                let far=mode==2 ? ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius*spread*2):middle
                var p=EffectParams();p.i.x=mode
                p.a=SIMD4(f29(ctx,"fine"),f29(ctx,"middle"),f29(ctx,"broad"),pc29(ctx,"blend"))
                p.b=SIMD4(f29(ctx,"gain"),pc29(ctx,"bias"),pc29(ctx,"strength"),f29(ctx,"contrast"))
                p.c.x=pc29(ctx,"floor")
                let output=ctx.temp()
                ctx.gpu.run("fxFrequency37",ctx.cb,textures:[ctx.input,output,near,middle,far],params:p,grid:output)
                return output
            })
    }
    static let cleanup37: [EffectDefinition] = [
        cleanup37("medianDetail","Median Detail",0,
            "A luminance-ranked median suppresses isolated specks without averaging across every contour."),
        cleanup37("conservativeSmooth","Conservative Smooth",1,
            "Only isolated extrema outside the neighboring color range are replaced; ordinary gradients stay intact."),
        cleanup37("chromaClean","Chroma Clean",2,
            "Neighbor colors are smoothed while the current pixel's luminance and alpha stay unchanged."),
        cleanup37("coverageSmooth","Coverage Smooth",3,
            "Smooth neighboring color in proportion to coverage, excluding fully transparent samples and retaining the existing matte."),
        cleanup37("trimmedMean","Trimmed Mean",4,
            "Discard the brightest and darkest samples before averaging, rejecting isolated hot and dark specks."),
        cleanup37("localRange","Local Range Contrast",5,
            "Remap luminance through its local neighborhood range, blending local contrast with the original hue.")
    ]
    private static func cleanup37(_ id:String,_ name:String,_ mode:UInt32,_ summary:String) -> EffectDefinition {
        EffectDefinition(id:"awi37."+id,name:name,category:.blur,aeMatchNames:[],summary:summary,
            params:[.number("radius","Sample Spacing",1,0.5,12,unit:"px"),
                .number("strength","Strength",70,0,100,unit:"%"),
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 || v29(ctx,"strength")<=0 { return ctx.input }
                var p=EffectParams();p.i.x=mode
                p.a=SIMD4(px29(ctx,"radius"),pc29(ctx,"strength")*pc29(ctx,"blend"),0,0)
                let output=ctx.temp()
                ctx.gpu.run("fxCleanup37",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
    static let batch37: [EffectDefinition] = [
        EffectDefinition(id:"awi37.pixelBlur",name:"Pixel Blur",category:.blur,aeMatchNames:[],
            summary:"Blur the source first, then sample it on a controllable pixel grid. Block size and blur radius are independent.",
            params:[.number("block","Block Size",12,1,100,unit:"px"),.number("blur","Blur Amount",8,0,120,unit:"px"),
                .choice("sampling","Block Sampling",["Center","Area"],1),.number("blend","Blend",100,0,100,unit:"%")],
            margin:{ effect,time in (effect.params["blur"]?.number(at:time) ?? 8)*2+(effect.params["block"]?.number(at:time) ?? 12) },
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                if v29(ctx,"block")<=1 && v29(ctx,"blur")<=0 { return ctx.input }
                let blurred=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:v29(ctx,"blur")*ctx.unit)
                var p=EffectParams();p.a=SIMD4(px29(ctx,"block"),pc29(ctx,"blend"),0,0);p.i.y=UInt32(ch29(ctx,"sampling"))
                let output=ctx.temp()
                ctx.gpu.run("fxFinish37",ctx.cb,textures:[ctx.input,output,blurred],params:p,grid:output)
                return output
            }),
        EffectDefinition(id:"awi37.hotColor",name:"Hot Color",category:.color,aeMatchNames:[],
            summary:"A luminance-conditioned hot chroma treatment with separate low and high tint controls and a bright white shoulder.",
            params:[.angle("lowHue","Low Hue",0),.number("lowSat","Low Saturation",100,0,100,unit:"%"),
                .angle("highHue","High Hue",60),.number("highSat","High Saturation",100,0,100,unit:"%"),
                .number("gamma","Luma Gamma",1,0.1,4),.number("cutoff","Tint Boundary",50,1,99,unit:"%"),
                .number("shine","White Shoulder",100,0,100,unit:"%"),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                var p=EffectParams();p.i.x=1
                p.a=SIMD4(f29(ctx,"lowHue")/360,pc29(ctx,"lowSat"),f29(ctx,"highHue")/360,pc29(ctx,"highSat"))
                p.b=SIMD4(f29(ctx,"gamma"),pc29(ctx,"cutoff"),pc29(ctx,"shine"),pc29(ctx,"blend"))
                let output=ctx.temp();ctx.gpu.run("fxFinish37",ctx.cb,textures:[ctx.input,output,ctx.input],params:p,grid:output);return output
            }),
        EffectDefinition(id:"awi37.hotColor2",name:"Hot Color 2",category:.color,aeMatchNames:[],
            summary:"A single hot tint expands toward neighboring hue sectors in shadows and highlights while retaining a bright shoulder.",
            params:[.angle("hue","Tint Hue",195),.number("saturation","Saturation",90,0,100,unit:"%"),
                .number("gamma","Luma Gamma",1,0.1,4),.number("shine","White Shoulder",100,0,100,unit:"%"),
                .number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                var p=EffectParams();p.i.x=2;p.a=SIMD4(f29(ctx,"hue")/360,pc29(ctx,"saturation"),0,0)
                p.b=SIMD4(f29(ctx,"gamma"),0.5,pc29(ctx,"shine"),pc29(ctx,"blend"))
                let output=ctx.temp();ctx.gpu.run("fxFinish37",ctx.cb,textures:[ctx.input,output,ctx.input],params:p,grid:output);return output
            })
    ]
}
