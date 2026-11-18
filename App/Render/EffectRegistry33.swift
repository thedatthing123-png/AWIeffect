import Foundation
import Metal
import simd

extension EffectRegistry {
    static let featureMattes33:[EffectDefinition] = [
        featureMatte33("corner","Corner Response Matte",0,"Isolate corner responses from a smoothed gradient tensor, rather than every edge."),
        featureMatte33("coherence","Coherent Edge Matte",1,"Select neighborhoods with aligned gradients, useful for long strokes and line structures."),
        featureMatte33("junction","Junction Matte",2,"Select mixed-direction neighborhoods where strokes intersect or texture changes direction."),
        featureMatte33("energy","Gradient Energy Matte",3,"Select gradient energy over a controllable integration area without keying by brightness."),
        featureMatte33("deviation","Texture Deviation Matte",4,"Select local contrast using sampled luminance standard deviation."),
        featureMatte33("entropy","Texture Entropy Matte",5,"Select varied texture using an eight-bin neighborhood histogram."),
        featureMatte33("skewness","Texture Skew Matte",6,"Select neighborhoods with an asymmetric distribution of light and dark samples."),
        featureMatte33("kurtosis","Texture Peak Matte",7,"Select sparse intensity outliers using the neighborhood's standardized fourth moment.")
    ]
    private static func featureMatte33(_ id:String,_ name:String,_ mode:UInt32,_ summary:String) -> EffectDefinition {
        var controls:[ParamDef] = [.number("radius","Neighborhood",4,0.5,40,unit:"px"),
            .number("gain","Sensitivity",mode==0 ? 600:4,0,mode==0 ? 2000:40),
            .number("threshold","Threshold",25,0,100,unit:"%"),
            .number("softness","Softness",20,1,100,unit:"%")]
        if mode>=4 { controls.append(.choice("quality","Neighborhood Samples",["9","25","49"],1)) }
        controls += [.toggle("invert","Invert Matte",false),.choice("output","Output",["Cutout","Matte"],0),
            .number("blend","Blend",100,0,100,unit:"%")]
        return EffectDefinition(id:"awi33.feature."+id,name:name,category:.keying,aeMatchNames:[],summary:summary,
            params:controls,stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let field:MTLTexture
                if mode<4 {
                    let tensor=ctx.temp()
                    ctx.gpu.run("fxStructureTensor33",ctx.cb,textures:[ctx.input,tensor],grid:tensor)
                    field=ctx.gpu.gaussian(ctx,input:tensor,sigma:Double(px29(ctx,"radius")))
                } else { field=ctx.input }
                var p=EffectParams()
                p.a=SIMD4(px29(ctx,"radius"),f29(ctx,"gain"),pc29(ctx,"threshold"),pc29(ctx,"softness"))
                p.b.x=pc29(ctx,"blend")
                p.i=SIMD4(mode,UInt32(ch29(ctx,"quality")),b29(ctx,"invert") ? 1:0,UInt32(ch29(ctx,"output")))
                let output=ctx.temp()
                ctx.gpu.run("fxFeatureMatte33",ctx.cb,textures:[ctx.input,output,field],params:p,grid:output)
                return output
            })
    }

    static let temporalIDs33:Set<String>=["awi33.time.slice","awi33.time.difference","awi33.time.median",
        "awi33.time.echo","awi33.time.hold","awi33.time.rgb","awi33.time.exposure","awi33.time.extrema","awi37.retro.phosphor",
        "awi31.flowWarp","awi31.flowSmear","awi31.flowMap","awi31.flowDatamosh",
        "awi38.motionGlow","awi38.motionStreaks","awi38.motionRays","awi38.motionRings"]
    static let sampling33:[EffectDefinition] = [
        EffectDefinition(id:"awi33.time.hold",name:"Frame Hold",category:.stylize,aeMatchNames:[],
            summary:"Hold actual upstream frames on an editable sampling clock, independently of the composition frame rate.",
            params:[.number("rate","Sample Rate",6,0.5,60,unit:"fps"),
                .number("phase","Clock Phase",0,-1,1,unit:"s"),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard v29(ctx,"blend")>0,let sample=ctx.temporalSample else { return ctx.input }
                let rate=max(0.5,v29(ctx,"rate")),phase=v29(ctx,"phase")
                let heldTime=floor((ctx.time-phase)*rate)/rate+phase
                guard let held=sample(heldTime) else { return ctx.input }
                return timeComposite33(ctx,held)
            }),
        EffectDefinition(id:"awi33.time.rgb",name:"RGB Time Split",category:.stylize,aeMatchNames:[],
            summary:"Take red, green and blue from independently delayed real frames, with combined coverage.",
            params:[.number("red","Red Delay",0.15,-2,2,unit:"s"),
                .number("green","Green Delay",0,-2,2,unit:"s"),.number("blue","Blue Delay",-0.1,-2,2,unit:"s"),
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                guard v29(ctx,"blend")>0,let sample=ctx.temporalSample,
                      let red=sample(ctx.time-v29(ctx,"red")),let green=sample(ctx.time-v29(ctx,"green")),
                      let blue=sample(ctx.time-v29(ctx,"blue")) else { return ctx.input }
                let output=ctx.temp()
                ctx.gpu.run("fxRGBTime33",ctx.cb,textures:[red,output,green,blue],grid:output)
                return timeComposite33(ctx,output)
            }),
        temporalEnvelope33("echo","Frame Echo",0,"Composite actual past frames with controlled decay and ordering.",
            [.number("decay","Echo Decay",65,0,100,unit:"%"),.choice("combine","Composite",["Add","Over","Lighten","Darken"],0)]),
        temporalEnvelope33("exposure","Time Exposure",1,"Integrate actual image changes over a time window, including animated effects and content.",
            [.choice("weight","Exposure Profile",["Uniform","Triangle","Front Weighted"],0)]),
        temporalEnvelope33("extrema","Temporal Range",2,"Select light or dark temporal envelopes, or isolate their range across a sampled interval.",
            [.choice("combine","Envelope",["Lightest","Darkest","Range"],2)])
    ]
    private static func temporalEnvelope33(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi33.time."+id,name:name,category:.stylize,aeMatchNames:[],summary:summary,
            params:[.number("span","Time Window",0.3,0.01,3,unit:"s"),
                .number("offset","Time Offset",0,-3,3,unit:"s"),
                .number("samples","Frame Samples",5,2,8,step:1)]+controls+[
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                guard v29(ctx,"blend")>0,let sample=ctx.temporalSample else { return ctx.input }
                let count=min(8,max(2,Int(v29(ctx,"samples"))))
                var accumulated=ctx.temp(),minimum=ctx.temp()
                ctx.gpu.run("fxClear",ctx.cb,textures:[accumulated],grid:accumulated)
                ctx.gpu.run("fxClear",ctx.cb,textures:[minimum],grid:minimum)
                var weightSum:Double=0
                for index in 0..<count {
                    let fraction=Double(index)/Double(count-1)
                    guard let frame=sample(ctx.time+v29(ctx,"offset")-fraction*v29(ctx,"span")) else { return ctx.input }
                    var weight:Double=1
                    if mode==0 { weight=pow(v29(ctx,"decay")/100,Double(index)) }
                    if mode==1 {
                        if ch29(ctx,"weight")==1 { weight=1-abs(2*(Double(index)+0.5)/Double(count)-1) }
                        if ch29(ctx,"weight")==2 { weight=1-fraction*0.9 }
                    }
                    weightSum+=weight
                    var p=EffectParams();p.a.x=Float(weight)
                    p.i=SIMD4(mode,UInt32(index),UInt32(mode==1 ? ch29(ctx,"weight"):ch29(ctx,"combine")),0)
                    let next=ctx.temp()
                    ctx.gpu.run("fxTemporalAccumulate33",ctx.cb,textures:[accumulated,next,frame],params:p,grid:next)
                    accumulated=next
                    if mode==2 {
                        p.i.w=1
                        let nextMinimum=ctx.temp()
                        ctx.gpu.run("fxTemporalAccumulate33",ctx.cb,textures:[minimum,nextMinimum,frame],params:p,grid:nextMinimum)
                        minimum=nextMinimum
                    }
                }
                var p=EffectParams();p.i.x=mode;p.i.y=UInt32(ch29(ctx,"combine"))
                p.a.x=Float(weightSum)
                let output=ctx.temp()
                ctx.gpu.run("fxTemporalFinish33",ctx.cb,textures:[accumulated,output,minimum],params:p,grid:output)
                return timeComposite33(ctx,output)
            })
    }
    static let time33:[EffectDefinition]=[
        EffectDefinition(id:"awi33.time.slice",name:"Time Slice",category:.stylize,aeMatchNames:[],
            summary:"Different image regions show actual upstream frames from a time interval. Linear or radial slices can blend between sampled frames.",
            params:[.number("span","Time Span",0.3,-3,3,unit:"s"),.number("offset","Time Offset",-0.15,-10,10,unit:"s"),
                .number("samples","Frame Samples",6,2,8,step:1),.angle("angle","Direction",0),
                .point("center","Center",Vec2(0.5,0.5)),.choice("pattern","Time Map",["Linear","Radial"],0),
                .choice("sampling","Between Frames",["Hold","Blend"],1),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard let sample=ctx.temporalSample,v29(ctx,"blend")>0 else { return ctx.input }
                if abs(v29(ctx,"span"))+abs(v29(ctx,"offset"))<0.00001 { return ctx.input }
                let count=min(8,max(2,Int(v29(ctx,"samples"))))
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var accumulated=ctx.temp();ctx.gpu.run("fxClear",ctx.cb,textures:[accumulated],grid:accumulated)
                for index in 0..<count {
                    let t=ctx.time+v29(ctx,"offset")+v29(ctx,"span")*Double(index)/Double(count-1)
                    guard let frame=sample(t) else { return ctx.input }
                    var p=EffectParams();p.a=SIMD4(Float(index),Float(count),0,0)
                    p.b=SIMD4(Float(center.x),Float(center.y),f29(ctx,"angle")*Float.pi/180,0)
                    p.i=SIMD4(UInt32(ch29(ctx,"pattern")),UInt32(ch29(ctx,"sampling")),0,0)
                    let next=ctx.temp()
                    ctx.gpu.run("fxTimeSlice33",ctx.cb,textures:[accumulated,next,frame],params:p,grid:next)
                    accumulated=next
                }
                return timeComposite33(ctx,accumulated)
            }),
        EffectDefinition(id:"awi33.time.difference",name:"Frame Difference",category:.stylize,aeMatchNames:[],
            summary:"Compare the current upstream image with an actual earlier or later frame to isolate motion and changing detail.",
            params:[.number("delay","Frame Delay",0.1,-2,2,unit:"s"),.number("gain","Difference Gain",3,0,16),
                .choice("channels","Compare",["Color","Luminance","Alpha"],0),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard let sample=ctx.temporalSample,v29(ctx,"blend")>0,let frame=sample(ctx.time-v29(ctx,"delay")) else { return ctx.input }
                var p=EffectParams();p.a=SIMD4(f29(ctx,"gain"),pc29(ctx,"blend"),0,0);p.i.y=UInt32(ch29(ctx,"channels"))
                let out=ctx.temp();ctx.gpu.run("fxTimeDifference33",ctx.cb,textures:[ctx.input,out,frame],params:p,grid:out)
                return out
            }),
        EffectDefinition(id:"awi33.time.median",name:"Temporal Median",category:.blur,aeMatchNames:[],
            summary:"A three-frame median rejects isolated temporal changes. Larger spacing can deliberately remove moving detail.",
            params:[.number("spacing","Frame Spacing",0.05,0.01,1,unit:"s"),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard let sample=ctx.temporalSample,v29(ctx,"blend")>0,
                      let previous=sample(ctx.time-v29(ctx,"spacing")),let next=sample(ctx.time+v29(ctx,"spacing")) else { return ctx.input }
                var p=EffectParams();p.a.x=pc29(ctx,"blend")
                let out=ctx.temp();ctx.gpu.run("fxTimeMedian33",ctx.cb,textures:[ctx.input,out,previous,next],params:p,grid:out)
                return out
            })
    ]
    private static func timeComposite33(_ ctx:EffectContext,_ processed:MTLTexture) -> MTLTexture {
        let out=ctx.temp();var p=EffectParams();p.a.x=pc29(ctx,"blend")
        ctx.gpu.run("fxTimeComposite33",ctx.cb,textures:[ctx.input,out,processed],params:p,grid:out)
        return out
    }
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
