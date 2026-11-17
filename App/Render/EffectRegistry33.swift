import Foundation
import Metal
import simd

extension EffectRegistry {
    static let batch33: [EffectDefinition] = [
        matte33("channelMatte","Channel Matte",0,"Build a soft matte from a selected source color channel.",
            [.choice("channel","Channel",["Red","Green","Blue","Alpha"],0),.number("threshold","Threshold",45,0,100,unit:"%"),.number("softness","Softness",20,1,100,unit:"%")]),
        matte33("saturationMatte","Saturation Matte",1,"Separate saturated color from neutral image regions with a controllable soft boundary.",
            [.number("threshold","Saturation",35,0,100,unit:"%"),.number("softness","Softness",20,1,100,unit:"%")]),
        matte33("colorDistance","Color Distance Matte",2,"Key by distance from an exact RGB color, including neutral colors that hue keys cannot isolate.",
            [.color("color","Key Color",RGBA(0.1,0.9,0.2)),.number("threshold","Distance",30,0,100,unit:"%"),.number("softness","Softness",15,1,100,unit:"%")]),
        matte33("localContrast","Local Contrast Matte",3,"Fine image structure becomes a matte by comparison with a blurred neighborhood.",
            [.number("threshold","Detail Threshold",12,0,80,unit:"%"),.number("softness","Softness",20,1,100,unit:"%"),.number("radius","Detail Radius",6,0.5,40,unit:"px")]),
        matte33("colorEdge","Chroma Edge Matte",4,"Find boundaries between colors even when both sides have similar brightness.",
            [.number("threshold","Edge Threshold",15,0,80,unit:"%"),.number("softness","Softness",25,1,100,unit:"%"),.number("radius","Edge Radius",3,0.5,24,unit:"px")]),
        matte33("lumaBand","Luma Band Matte",5,"Keep a finite brightness band with independent band width and soft boundaries.",
            [.number("threshold","Band Center",55,0,100,unit:"%"),.number("band","Band Width",45,1,100,unit:"%"),.number("softness","Softness",15,1,100,unit:"%")]),
        matte33("neutralMatte","Neutral Color Matte",6,"Isolate near-neutral ink, whites and grays independently from saturated artwork.",
            [.number("threshold","Neutral Range",28,0,100,unit:"%"),.number("softness","Softness",20,1,100,unit:"%")]),
        matte33("colorDifference","Color Difference Key",7,"Remove a dominant screen channel by measuring how far it exceeds the other channels.",
            [.choice("channel","Screen Channel",["Red","Green","Blue"],1),.number("threshold","Difference",20,0,100,unit:"%"),.number("softness","Softness",30,1,100,unit:"%")]),
        matte33("fringeMatte","Matte Fringe",8,"Extract the soft outer fringe of an existing alpha edge for compositing and edge treatments.",
            [.number("radius","Fringe Radius",7,0.5,40,unit:"px"),.number("threshold","Edge Threshold",8,0,70,unit:"%"),.number("softness","Softness",20,1,100,unit:"%")]),
        matte33("coreMatte","Matte Core",9,"Extract the opaque inner core while excluding the soft boundary of a matte.",
            [.number("radius","Core Radius",5,0.5,40,unit:"px"),.number("threshold","Core Threshold",65,0,100,unit:"%"),.number("softness","Softness",12,1,100,unit:"%")]),
        matte33("alphaDither","Alpha Dither",10,"Convert soft alpha into ordered coverage while retaining transparent and opaque endpoints.",
            [.number("threshold","Coverage Bias",50,0,100,unit:"%"),.number("radius","Dither Size",2,1,16,unit:"px"),.number("softness","Threshold Spread",40,1,100,unit:"%")]),
        matte33("alphaSteps","Alpha Steps",11,"Quantize a soft matte into editable opacity levels, with a controllable threshold bias.",
            [.number("band","Opacity Levels",4,2,16,step:1),.number("threshold","Level Bias",50,0,100,unit:"%"),.number("softness","Step Softness",20,1,100,unit:"%")]),
        matte33("differenceMatte","Difference Matte",12,"Remove pixels matching another layer, with a soft RGB difference threshold.",
            [.number("threshold","Difference",20,0,100,unit:"%"),.number("softness","Softness",20,1,100,unit:"%")]),
        matte33("lumaDifference","Luma Difference Matte",13,"Compare source and reference luminance while ignoring changes in hue.",
            [.number("threshold","Difference",20,0,100,unit:"%"),.number("softness","Softness",20,1,100,unit:"%")]),
        matte33("lightWrap","Light Wrap",14,"Blur a reference background into the source's soft edge without replacing its interior.",
            [.number("radius","Wrap Radius",12,1,80,unit:"px"),.number("threshold","Edge Range",45,0,100,unit:"%"),.number("softness","Edge Softness",30,1,100,unit:"%")]),
        matte33("referenceSpill","Reference Spill",15,"Use a reference layer's color to reduce edge contamination in a source matte.",
            [.number("radius","Edge Radius",8,1,60,unit:"px"),.number("threshold","Edge Range",55,0,100,unit:"%"),.number("softness","Spill Softness",30,1,100,unit:"%")])
    ]

    private static func matte33(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi33."+id,name:name,category:.keying,aeMatchNames:[],summary:summary,
            params:controls+[.toggle("invert","Invert Matte",false),.choice("output","Output",["Cutout","Matte"],0),.number("amount","Amount",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                if mode>=12 && ctx.reference==nil { return ctx.input }
                let radius=Double(px29(ctx,"radius"))
                let softSource = [3,4,8,9,14,15].contains(mode) ? ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius) : ctx.input
                var reference=ctx.reference ?? ctx.input
                if mode==14 { reference=ctx.gpu.gaussian(ctx,input:reference,sigma:radius) }
                var p=EffectParams()
                p.a=SIMD4(pc29(ctx,"threshold"),pc29(ctx,"softness"),Float(radius),pc29(ctx,"amount"))
                p.b=col29(ctx,"color")
                p.c=SIMD4(f29(ctx,"band"),0,0,0)
                p.i=SIMD4(mode,UInt32(ch29(ctx,"channel")),b29(ctx,"invert") ? 1:0,UInt32(ch29(ctx,"output")))
                let output=ctx.temp()
                ctx.gpu.run("fxMatte33",ctx.cb,textures:[ctx.input,output,softSource,reference],params:p,grid:output)
                return output
            })
    }
}
