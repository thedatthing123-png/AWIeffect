import Foundation
import Metal
import simd

extension EffectRegistry {
    static let advancedClean37:[EffectDefinition] = [
        EffectDefinition(id:"awi37.guidedSmooth",name:"Guided Smooth",category:.blur,aeMatchNames:[],
            summary:"A coverage-weighted local linear model smooths color while retaining the guidance image's stronger boundaries.",
            params:[.number("radius","Neighborhood",8,0.5,100,unit:"px"),
                .number("epsilon","Edge Regularization",0.04,0.001,0.4),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let scalar=ctx.temp(),cross=ctx.temp()
                ctx.gpu.run("fxGuidedMoments37",ctx.cb,textures:[ctx.input,scalar,cross],grid:scalar)
                let radius=v29(ctx,"radius")*ctx.unit
                let meanRGB=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius)
                let meanScalar=ctx.gpu.gaussian(ctx,input:scalar,sigma:radius)
                let meanCross=ctx.gpu.gaussian(ctx,input:cross,sigma:radius)
                let a=ctx.temp(),b=ctx.temp();var p=EffectParams()
                p.a=SIMD4(f29(ctx,"epsilon"),pc29(ctx,"blend"),0,0)
                ctx.gpu.run("fxGuidedCoefficients37",ctx.cb,textures:[ctx.input,a,meanRGB,meanScalar,meanCross,b],params:p,grid:a)
                let smoothA=ctx.gpu.gaussian(ctx,input:a,sigma:radius)
                let smoothB=ctx.gpu.gaussian(ctx,input:b,sigma:radius)
                let output=ctx.temp()
                ctx.gpu.run("fxGuidedFinish37",ctx.cb,textures:[ctx.input,output,smoothA,smoothB],params:p,grid:output)
                return output
            }),
        EffectDefinition(id:"awi37.tvLuma",name:"TV Luma Clean",category:.blur,aeMatchNames:[],
            summary:"Total-variation luminance denoising uses bounded primal-dual iterations while preserving source chroma and coverage.",
            params:[.number("strength","Denoise Strength",0.12,0.01,0.5),
                .number("iterations","Iterations",16,2,48,step:1),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let primal=[ctx.temp(),ctx.temp()],dual=[ctx.temp(),ctx.temp()]
                ctx.gpu.run("fxTVPrepare37",ctx.cb,textures:[ctx.input,primal[0]],grid:primal[0])
                ctx.gpu.run("fxClear",ctx.cb,textures:[dual[0]],grid:dual[0])
                var p=EffectParams();p.a=SIMD4(Float(v29(ctx,"strength")*ctx.unit),0,0,pc29(ctx,"blend"))
                let iterations=min(48,max(2,Int(v29(ctx,"iterations"))))
                for iteration in 0..<iterations {
                    let read=iteration%2,write=1-read
                    ctx.gpu.run("fxTVDual37",ctx.cb,textures:[primal[read],dual[write],dual[read]],params:p,grid:dual[write])
                    ctx.gpu.run("fxTVPrimal37",ctx.cb,textures:[primal[read],primal[write],dual[write]],grid:primal[write])
                }
                let output=ctx.temp()
                ctx.gpu.run("fxTVFinish37",ctx.cb,textures:[ctx.input,output,primal[iterations%2]],params:p,grid:output)
                return output
            })
    ]

    static let nonlinear37:[EffectDefinition] = [
        nonlinear37("edgeDiffusion","Edge Diffusion",0,.blur,"Iterative contrast-dependent diffusion smooths small variation while resisting strong boundaries.",
            [.number("threshold","Edge Contrast",0.15,0.02,0.7),.choice("conduction","Edge Response",["Exponential","Reciprocal"],0)]),
        nonlinear37("shockSharpen","Shock Sharpen",1,.blur,"A bounded nonlinear shock step steepens transitions without a ringing unsharp-mask halo.",[]),
        nonlinear37("curvatureFlow","Curvature Smooth",2,.blur,"Image contours move along their local curvature, smoothing narrow bends while retaining broad edges.",[])
    ]
    private static func nonlinear37(_ id:String,_ name:String,_ mode:UInt32,_ category:EffectCategory,
                                     _ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi37.pde."+id,name:name,category:category,aeMatchNames:[],summary:summary,
            params:[.number("iterations","Passes",8,1,24,step:1),.number("strength","Step Strength",75,0,100,unit:"%")]+controls+[
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 || v29(ctx,"strength")<=0 { return ctx.input }
                var p=EffectParams();p.i=SIMD4(mode,UInt32(ch29(ctx,"conduction")),0,0)
                p.a=SIMD4(pc29(ctx,"strength"),f29(ctx,"threshold"),Float(max(0.5,ctx.unit)),0)
                // Encoder ordering makes two alternating textures safe to reuse;
                // iteration count must not multiply full-frame scratch storage.
                let ping=ctx.temp(),pong=ctx.temp()
                var current=ctx.input
                for index in 0..<min(24,max(1,Int(v29(ctx,"iterations")))) {
                    let output=index%2==0 ? ping:pong
                    ctx.gpu.run("fxNonlinear37",ctx.cb,textures:[current,output],params:p,grid:output)
                    current=output
                }
                if v29(ctx,"blend")>=100 { return current }
                var mix=EffectParams();mix.a.x=pc29(ctx,"blend")
                let output=ctx.temp()
                ctx.gpu.run("fxTimeComposite33",ctx.cb,textures:[ctx.input,output,current],params:mix,grid:output)
                return output
            })
    }

    static let transforms37:[EffectDefinition] = [
        EffectDefinition(id:"awi37.dctBlocks",name:"DCT Blocks",category:.glitch,aeMatchNames:[],
            summary:"Transform real 8x8 image blocks into frequency coefficients, filter them, and reconstruct the image with preserved coverage.",
            params:[.number("amount","Coefficient Loss",25,0,100,unit:"%"),
                .number("frequency","High Frequency Loss",1.2,0,3),
                .number("chroma","Chroma Loss",1.5,0,4),
                .choice("method","Coefficient Filter",["Quantize","Soft Threshold"],0),.toggle("dc","Keep Average",true),
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 || v29(ctx,"amount")<=0 { return ctx.input }
                var p=EffectParams();p.a=SIMD4(pc29(ctx,"amount"),f29(ctx,"frequency"),f29(ctx,"chroma"),pc29(ctx,"blend"))
                p.i=SIMD4(UInt32(ch29(ctx,"method")),b29(ctx,"dc") ? 1:0,0,0)
                let output=ctx.temp();ctx.gpu.dctBlocks37(ctx,input:ctx.input,output:output,params:p)
                return output
            }),
        EffectDefinition(id:"awi37.dogInk",name:"DoG Ink",category:.stylize,aeMatchNames:[],
            summary:"Two Gaussian scales form an extended difference response, then a smooth ink threshold draws fine light-dark boundaries.",
            params:[.number("radius","Detail Scale",1.2,0.4,12,unit:"px"),
                .number("ratio","Scale Ratio",1.6,1.1,5),.number("weight","Edge Weight",0.98,0.5,1.5),
                .number("threshold","Ink Threshold",-0.01,-0.2,0.2),.number("hardness","Edge Hardness",60,1,100),
                .color("ink","Ink",RGBA(0.03,0.03,0.05)),.color("paper","Paper",RGBA(0.98,0.97,0.94)),
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let radius=v29(ctx,"radius")*ctx.unit
                let near=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius)
                let far=ctx.gpu.gaussian(ctx,input:ctx.input,sigma:radius*v29(ctx,"ratio"))
                var p=EffectParams();p.a=SIMD4(f29(ctx,"weight"),f29(ctx,"threshold"),f29(ctx,"hardness"),pc29(ctx,"blend"))
                p.b=col29(ctx,"ink");p.c=col29(ctx,"paper")
                let output=ctx.temp()
                ctx.gpu.run("fxDoGInk37",ctx.cb,textures:[ctx.input,output,near,far],params:p,grid:output)
                return output
            })
    ]

    static let morphology37:[EffectDefinition] = [
        morphology37("opening", "Remove Bright Specks", 0, "Opening removes bright marks smaller than the neighborhood while retaining broad lighting."),
        morphology37("closing", "Fill Dark Gaps", 1, "Closing fills narrow dark gaps without blurring broad boundaries."),
        morphology37("whiteHat", "Bright Detail Matte", 2, "Subtract an opening to isolate small bright features under uneven lighting."),
        morphology37("blackHat", "Dark Detail Matte", 3, "Subtract the image from a closing to isolate fine dark lines and crevices."),
        morphology37("gradient", "Local Range Matte", 4, "The local maximum minus minimum extracts both sides of contrast boundaries."),
        morphology37("midrange", "Extrema Smooth", 5, "Average local dark and light envelopes to remove texture with a different character from blur.")
    ]

    private static func morphology37(_ id:String, _ name:String, _ mode:UInt32, _ summary:String) -> EffectDefinition {
        var controls:[ParamDef] = [.number("radius", "Neighborhood", 3, 1, 24, unit:"px"),
            .choice("axis", "Structure", ["Box", "Horizontal", "Vertical"], 0)]
        if (2...4).contains(mode) { controls.append(.number("gain", "Detail Gain", 2, 0, 12)) }
        controls.append(.number("blend", "Blend", 100, 0, 100, unit:"%"))
        return EffectDefinition(id:"awi37.morph."+id,name:name,category:.stylize,aeMatchNames:[],summary:summary,
            params:controls,stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let radius = min(48,max(1,Int(px29(ctx,"radius").rounded())))
                let structure = ch29(ctx,"axis")
                func envelope(_ input:MTLTexture, _ maximum:Bool, _ raw:Bool) -> MTLTexture {
                    var current=input
                    let axes:[UInt32] = structure == 0 ? [0,1] : [structure == 1 ? 0:1]
                    for (index,axis) in axes.enumerated() {
                        var p=EffectParams()
                        p.i=SIMD4(UInt32(radius),axis,maximum ? 1:0,raw && index == 0 ? 1:0)
                        let output=ctx.temp()
                        ctx.gpu.run("fxExtrema37",ctx.cb,textures:[current,output],params:p,grid:output)
                        current=output
                    }
                    return current
                }
                let a:MTLTexture, b:MTLTexture
                // The first envelope reads straight source luminance. Subsequent
                // passes read scalar scratch fields, never premultiplied color.
                // Reuse the envelope's raw path rather than guessing from alpha.
                if mode <= 3 {
                    let maximum = mode == 1 || mode == 3
                    a=envelope(envelope(ctx.input,maximum,true),!maximum,false)
                    b=a
                } else {
                    a=envelope(ctx.input,false,true)
                    b=envelope(ctx.input,true,true)
                }
                var p=EffectParams()
                p.a=SIMD4((2...4).contains(mode) ? f29(ctx,"gain"):1,pc29(ctx,"blend"),0,0)
                p.i.x=mode
                let output=ctx.temp()
                ctx.gpu.run("fxMorphology37",ctx.cb,textures:[ctx.input,output,a,b],params:p,grid:output)
                return output
            })
    }

    static let textGeometryIDs37:Set<String>=["awi37.text.arc","awi37.text.cylinder","awi37.text.sphere", "awi37.text.accordion","awi37.text.helix","awi37.text.attractor"]
    static let textGeometry37:[EffectDefinition]=[
        textGeometry37("arc","Text Arc","Bend the actual glyph baseline into an arc, optionally turning each letter along its tangent.",
            [.angle("bend","Arc Bend",65),.toggle("orient","Follow Tangent",true)]),
        textGeometry37("cylinder","Text Cylinder","Wrap glyph positions and their real 3D rotations around a cylinder, with independent depth exaggeration.",
            [.number("radius","Cylinder Radius",80,10,2000,unit:"px"),.angle("phase","Cylinder Rotation",20),
             .number("depth","Depth",100,0,1000,unit:"%")]),
        textGeometry37("sphere","Text Sphere","Project the glyph layout onto a sphere, retaining per-letter perspective rather than warping a flattened bitmap.",
            [.number("radius","Sphere Radius",90,10,2000,unit:"px"),.angle("phase","Longitude",10),
             .angle("latitude","Latitude",15),.number("depth","Depth",100,0,1000,unit:"%")]),
        textGeometry37("accordion","Text Accordion","Fold successive glyph panels in alternating directions with connected panel positions in depth.",
            [.number("width","Panel Width",40,4,400,unit:"px"),.angle("fold","Fold Angle",45)]),
        textGeometry37("helix","Text Helix","Wind actual glyph positions around a rising 3D helix; pitch follows typographic distance, not character count.",
            [.number("radius","Helix Radius",30,1,500,unit:"px"),.number("pitch","Turn Length",100,10,1000,unit:"px"),
             .number("rise","Rise Per Turn",20,-500,500,unit:"px"),.angle("phase","Helix Rotation",0)]),
        textGeometry37("attractor","Text Attractor","Pull or repel glyphs through a smooth distance field centered on an editable point, with optional facing.",
            [.number("radius","Influence Radius",120,1,1000,unit:"px"),.number("strength","Attraction",50,-200,200,unit:"%"),
             .number("turn","Face Center",0,0,100,unit:"%")])
    ]
    private static func textGeometry37(_ id:String,_ name:String,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi37.text."+id,name:name,category:.text,aeMatchNames:[],summary:summary,
            params:controls+[.point("center","Geometry Center",Vec2(0.5,0.5)),.number("blend","Blend",100,0,100,unit:"%")],
            // Native layout stage, like Letter Spacing: TextEngine consumes these
            // parameters before glyph projection. Never run a fake pixel pass.
            stage:.transform { _,_ in (0,0,0,1) })
    }
    static let retro37:[EffectDefinition]=[
        EffectDefinition(id:"awi37.retro.ccdSmear",name:"CCD Smear",category:.stylize,aeMatchNames:[],
            summary:"Bright source regions leak charge into one-way vertical sensor streaks, with a soft threshold and decaying reach.",
            params:[.number("length","Smear Length",120,1,600,unit:"px"),.number("threshold","Highlight Threshold",65,0,100,unit:"%"),
                .number("knee","Threshold Softness",15,1,100,unit:"%"),.number("softness","Column Softness",2,0,24,unit:"px"),
                .number("decay","Charge Falloff",2,0.1,8),.number("gain","Smear Gain",1.5,0,6),
                .choice("direction","Smear Direction",["Down","Up"],0),
                .number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)],
            margin:{effect,time in (effect.params["length"]?.number(at:time) ?? 120)+3*(effect.params["softness"]?.number(at:time) ?? 2)},
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                if v29(ctx,"gain")<=0 {
                    if b29(ctx,"only") { let out=ctx.temp();ctx.gpu.run("fxClear",ctx.cb,textures:[out],grid:out);return out }
                    return ctx.input
                }
                let light=lightPrep25(ctx,threshold:v29(ctx,"threshold")/100,knee:v29(ctx,"knee")/100)
                let softened=ctx.gpu.gaussian(ctx,input:light,sigma:max(v29(ctx,"softness")*ctx.unit,v29(ctx,"length")*ctx.unit/24*0.4))
                var p=EffectParams();p.a=SIMD4(px29(ctx,"length"),f29(ctx,"decay"),ch29(ctx,"direction")==0 ? -1:1,0)
                let out=ctx.temp();ctx.gpu.run("fxRetro37",ctx.cb,textures:[softened,out],params:p,grid:out)
                return lightComp25(ctx,base:ctx.input,glow:out,intensity:v29(ctx,"gain")*v29(ctx,"blend")/100,
                    composite:b29(ctx,"only") ? .glowOnly:.over)
            }),
        EffectDefinition(id:"awi37.retro.compositeCrosstalk",name:"Composite Crosstalk",category:.stylize,aeMatchNames:[],
            summary:"Encode color onto a scanline carrier and demodulate it again, producing actual luma/chroma cross-talk and crawling color artifacts.",
            params:[.number("carrier","Carrier Period",4,2,12,unit:"px"),.number("chroma","Chroma Level",100,0,200,unit:"%"),
                .angle("phase","Carrier Phase",0),.number("speed","Phase Speed",6,0,12,unit:"Hz"),
                .number("blend","Blend",70,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                var p=EffectParams();p.i.x=1
                p.a=SIMD4(px29(ctx,"carrier"),pc29(ctx,"chroma"),Float((v29(ctx,"phase")/360+ctx.time*v29(ctx,"speed"))*2*Double.pi),pc29(ctx,"blend"))
                p.b.x=Float(ctx.unit)
                let out=ctx.temp();ctx.gpu.run("fxRetro37",ctx.cb,textures:[ctx.input,out],params:p,grid:out);return out
            }),
        EffectDefinition(id:"awi37.retro.plateRegistration",name:"Plate Registration",category:.stylize,aeMatchNames:[],
            summary:"Re-register red and blue image plates with independent rotation and scale, retaining the green plate and the union of their coverage.",
            params:[.angle("redAngle","Red Rotation",1.5),.angle("blueAngle","Blue Rotation",-1.5),
                .number("redScale","Red Scale",100.5,50,150,unit:"%"),.number("blueScale","Blue Scale",99.5,50,150,unit:"%"),
                .number("shift","Plate Separation",2,-50,50,unit:"px"),.point("center","Registration Pivot",Vec2(0.5,0.5)),
                .number("blend","Blend",100,0,100,unit:"%")],
            expandedMargin:{effect,time,size in
                var reach=0.0
                let center=effect.params["center"]?.point(at:time) ?? Vec2(0.5,0.5)
                let pivot=Vec2((center.x-0.5)*size.x,(center.y-0.5)*size.y)
                let shift=min(50,max(-50,effect.params["shift"]?.number(at:time) ?? 2))
                for (rotation,scale) in [("redAngle","redScale"),("blueAngle","blueScale")] {
                    let angle=(effect.params[rotation]?.number(at:time) ?? (rotation=="redAngle" ? 1.5:-1.5))*Double.pi/180
                    let factor=min(1.5,max(0.5,(effect.params[scale]?.number(at:time) ?? (scale=="redScale" ? 100.5:99.5))/100))
                    let offset=rotation=="redAngle" ? shift:-shift
                    for x in [-size.x/2,size.x/2] { for y in [-size.y/2,size.y/2] {
                        let qx=(x-pivot.x-offset)*factor,qy=(y-pivot.y)*factor
                        let px=pivot.x+qx*cos(angle)-qy*sin(angle),py=pivot.y+qx*sin(angle)+qy*cos(angle)
                        reach=max(reach,abs(px)-size.x/2,abs(py)-size.y/2)
                    } }
                }
                return max(0,reach)+2
            },stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams();p.i.x=2
                p.a=SIMD4(f29(ctx,"redAngle")*Float.pi/180,f29(ctx,"blueAngle")*Float.pi/180,pc29(ctx,"redScale"),pc29(ctx,"blueScale"))
                let extent=ctx.layerPixels ?? SIMD2(Double(ctx.width),Double(ctx.height))
                p.b=SIMD4(px29(ctx,"shift"),Float(Double(ctx.width)/2+(center.x-0.5)*extent.x),
                    Float(Double(ctx.height)/2+(center.y-0.5)*extent.y),pc29(ctx,"blend"))
                let out=ctx.temp();ctx.gpu.run("fxRetro37",ctx.cb,textures:[ctx.input,out],params:p,grid:out);return out
            }),
        EffectDefinition(id:"awi37.retro.phosphor",name:"Phosphor Persistence",category:.stylize,aeMatchNames:[],
            summary:"Actual previous frames decay with independent red, green and blue half-lives, leaving source-driven phosphor afterimages.",
            params:[.number("window","History Window",0.2,0.01,2,unit:"s"),.number("samples","History Samples",6,2,8,step:1),
                .number("red","Red Half-Life",0.12,0.005,1,unit:"s"),.number("green","Green Half-Life",0.2,0.005,1,unit:"s"),
                .number("blue","Blue Half-Life",0.04,0.005,1,unit:"s"),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard let sample=ctx.temporalSample,v29(ctx,"blend")>0 else { return ctx.input }
                let count=max(2,min(8,Int(v29(ctx,"samples"))))
                var accumulated=ctx.input
                for index in 1..<count {
                    let age=v29(ctx,"window")*Double(index)/Double(count-1)
                    guard let frame=sample(ctx.time-age) else { return ctx.input }
                    var p=EffectParams()
                    p.a=SIMD4(Float(exp2(-age/v29(ctx,"red"))),Float(exp2(-age/v29(ctx,"green"))),Float(exp2(-age/v29(ctx,"blue"))),0)
                    let out=ctx.temp();ctx.gpu.run("fxPhosphor37",ctx.cb,textures:[accumulated,out,frame],params:p,grid:out);accumulated=out
                }
                var p=EffectParams();p.a.x=pc29(ctx,"blend")
                let out=ctx.temp();ctx.gpu.run("fxTimeComposite33",ctx.cb,textures:[ctx.input,out,accumulated],params:p,grid:out);return out
            })
    ]
    static let drawing37:[EffectDefinition]=[
        drawing37("flowPaint","Flow Paint",0,"Smooth color along image contours with a color-distance gate instead of blurring equally across edges.",
            .number("size","Orientation Radius",2,0.5,16,unit:"px"),
            .number("detail","Stroke Reach",9,1,40,unit:"px"),.number("detail2","Color Tolerance",25,1,100,unit:"%")),
        drawing37("adaptiveHatch","Adaptive Hatch",1,"Small engraved patches turn with the image gradient; source darkness controls their line coverage.",
            .number("size","Patch Size",18,4,80,unit:"px"),
            .number("detail","Line Spacing",4,1,20,unit:"px"),.number("detail2","Contour Alignment",80,0,100,unit:"%")),
        drawing37("gradientStrokes","Gradient Strokes",2,"A field of short colored brush marks follows local image orientation, with independent length and thickness.",
            .number("size","Mark Spacing",10,3,40,unit:"px"),
            .number("detail","Mark Length",85,5,150,unit:"%"),.number("detail2","Mark Thickness",25,5,90,unit:"%")),
        drawing37("mezzotint","Mezzotint",3,"A multi-scale pitted grain field encodes source tone as dense etched ink, rather than one dot per cell.",
            .number("size","Pit Size",3,0.5,20,unit:"px"),
            .number("detail","Tone Contrast",1.3,0.2,4),.number("detail2","Pit Roughness",55,0,100,unit:"%")),
        drawing37("edgeStretch","Edge Stretch",4,"Pull source pixels along the local image gradient, with signed reach and independent edge sensitivity.",
            .number("size","Edge Radius",2,0.5,20,unit:"px"),
            .number("detail","Stretch",14,-100,100,unit:"px"),.number("detail2","Edge Sensitivity",3,0.2,12)),
        drawing37("curvature","Curvature",5,"A signed second-derivative image separates convex and concave tonal structure around an editable neutral gray.",
            .number("size","Curvature Radius",2,0.5,20,unit:"px"),
            .number("detail","Curvature Gain",5,0.1,20),.number("detail2","Neutral Gray",50,0,100,unit:"%")),
        drawing37("ridgeInk","Ridge Ink",6,"Hessian curvature detects dark or bright line centers, including lines within an otherwise continuous silhouette.",
            .number("size","Line Radius",1.5,0.5,12,unit:"px"),
            .number("detail","Line Gain",5,0.2,20),.number("detail2","Ink Threshold",12,0,80,unit:"%")),
        drawing37("spiralEngraving","Spiral Engraving",7,"A tonal spiral screen widens into dark image regions, with an editable center and arm count.",
            .number("size","Spiral Spacing",7,2,30,unit:"px"),
            .number("detail","Spiral Arms",2,1,12,step:1),.number("detail2","Tone Contrast",1.2,0.2,4)),
        drawing37("edgeSolarize","Edge Solarize",8,"Solarize relative to the local surround, revealing edge-adjacent negative regions instead of using one global threshold.",
            .number("size","Surround Radius",10,1,60,unit:"px"),
            .number("detail","Local Threshold",1,0.2,2),.number("detail2","Boundary Softness",20,1,100,unit:"%"))
    ]
    private static func drawing37(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,
                                  _ size:ParamDef,_ detail:ParamDef,_ detail2:ParamDef) -> EffectDefinition {
        var controls=[size,detail,detail2]
        if [1,2,7].contains(mode) { controls.append(.angle("angle","Direction",35)) }
        if [1,3,6,7].contains(mode) {
            controls += [.color("ink","Ink",RGBA(0.04,0.03,0.06)),.color("paper","Paper",RGBA(0.97,0.95,0.9))]
        }
        if mode==6 { controls.append(.choice("polarity","Line Polarity",["Dark Lines","Bright Lines"],0)) }
        if mode==3 { controls.append(.number("seed","Random Seed",3,0,1000,step:1)) }
        if mode==7 { controls.append(.point("center","Spiral Center",Vec2(0.5,0.5))) }
        return EffectDefinition(id:"awi37.draw."+id,name:name,category:.stylize,aeMatchNames:[],summary:summary,
            params:controls+[.number("blend","Blend",100,0,100,unit:"%")],
            margin:{effect,time in mode==4 ? min(100,abs(effect.params["detail"]?.number(at:time) ?? 14)):0},stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let scale=v29(ctx,"size")*ctx.unit
                let sigma = [1,2].contains(mode) ? max(0.5,scale*0.18):max(0.35,scale*0.45)
                let smooth = [3,7].contains(mode) ? ctx.input:ctx.gpu.gaussian(ctx,input:ctx.input,sigma:sigma)
                func packed(_ definition:ParamDef) -> Float {
                    let value=f29(ctx,definition.id)
                    if case .number(_,_,_,let unit)=definition.kind {
                        if unit=="px" { return value*Float(ctx.unit) }
                        if unit=="%" { return value/100 }
                    }
                    return value
                }
                var p=EffectParams()
                p.a=SIMD4(Float(scale),packed(detail),packed(detail2),pc29(ctx,"blend"))
                p.b.x=f29(ctx,"angle")*Float.pi/180
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                p.b.y=Float(center.x*Double(ctx.width));p.b.z=Float(center.y*Double(ctx.height))
                p.c=col29(ctx,"ink");p.d=col29(ctx,"paper")
                p.i=SIMD4(mode,UInt32(ch29(ctx,"polarity")),f29(ctx,"seed").bitPattern,0)
                let out=ctx.temp()
                ctx.gpu.run("fxDrawing37",ctx.cb,textures:[ctx.input,out,smooth],params:p,grid:out)
                return out
            })
    }
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

/// Native glyph geometry shares the existing text renderer, its 3D projection and
/// animated-bounds pass. It does not create animators or replace user presets.
enum TextGeometry37 {
    static func apply(_ effects:[EffectInstance],text:TextData,layout:TextLayout,
                      states:inout [Renderer.GlyphState],time:Double,weights:[Double]?=nil) {
        let vertical=text.vertical==true
        let bounds=layout.bounds
        for raw in effects where raw.isEnabled && !EffectStackR4.isMuted(raw) {
            guard let definition=EffectRegistry.rawDefinition(raw.typeID),EffectRegistry.textGeometryIDs37.contains(raw.typeID) else { continue }
            let effect=EffectStackR4.resolved(raw,at:time) ?? raw
            let defaults=Dictionary(definition.params.map{($0.id,$0.defaultValue)},uniquingKeysWith:{$1})
            let ranges=EffectRegistry.paramRanges[raw.typeID] ?? [:]
            func value(_ key:String) -> Double {
                let v=(effect.params[key] ?? defaults[key])?.number(at:time) ?? 0
                if let range=ranges[key] { return min(max(v,range.lowerBound),range.upperBound) }
                return v
            }
            let mix=min(1,max(0,value("blend")/100))*EffectStackR4.mix(raw,time)/100
            if mix<=0 { continue }
            let center=(effect.params["center"] ?? defaults["center"])?.point(at:time) ?? Vec2(0.5,0.5)
            let pivot=Vec2(Double(bounds.minX)+center.x*Double(bounds.width),Double(bounds.minY)+center.y*Double(bounds.height))
            let pu=vertical ? pivot.y:pivot.x,pv=vertical ? pivot.x:pivot.y
            let width=max(1,Double(vertical ? bounds.height:bounds.width))
            let radius=max(1,value("radius")),phase=value("phase")*Double.pi/180
            let latitudeOffset=value("latitude")*Double.pi/180,depth=value("depth")/100
            let bend=value("bend")*Double.pi/180,fold=value("fold")*Double.pi/180
            let panel=max(1,value("width")),pitch=max(1,value("pitch")),rise=value("rise")
            let attraction=value("strength")/100,facing=value("turn")/100
            let orient=value("orient")>0.5
            for (index,glyph) in layout.glyphs.enumerated() where !glyph.isSpace && index<states.count {
                let selection=weights.map { index<$0.count ? $0[index]:0 } ?? 1
                let glyphMix=mix*min(1,max(0,selection.isFinite ? selection:0))
                if glyphMix<=0 { continue }
                let position=glyph.center+states[index].offset
                let u=vertical ? position.y:position.x,v=vertical ? position.x:position.y
                guard u.isFinite,v.isFinite else { continue }
                var targetU=u,targetV=v,z=0.0,yaw=0.0,tilt=0.0,roll=0.0
                switch raw.typeID {
                case "awi37.text.arc":
                    if abs(bend)<0.000001 { continue }
                    let r=width/bend,angle=(u-pu)/r
                    targetU=pu+sin(angle)*r;targetV=v+r*(1-cos(angle))
                    if orient { roll=angle }
                case "awi37.text.cylinder":
                    let angle=(u-pu)/radius+phase
                    targetU=pu+sin(angle)*radius;z=radius*(1-cos(angle))*depth;yaw=angle
                case "awi37.text.sphere":
                    let longitude=(u-pu)/radius+phase,latitude=(v-pv)/radius+latitudeOffset
                    targetU=pu+radius*sin(longitude)*cos(latitude);targetV=pv+radius*sin(latitude)
                    z=radius*(1-cos(longitude)*cos(latitude))*depth;yaw=longitude;tilt=latitude
                case "awi37.text.accordion":
                    let start=Double(vertical ? bounds.minY:bounds.minX),along=u-start
                    let panelIndex=floor(along/panel),local=along-panelIndex*panel
                    let even=panelIndex.truncatingRemainder(dividingBy:2)==0
                    targetU=pu+(u-pu)*cos(fold);z=(even ? local:panel-local)*sin(fold);yaw=even ? fold:-fold
                case "awi37.text.helix":
                    let turn=(u-pu)/pitch,angle=turn*2*Double.pi+phase
                    targetU=pu+radius*sin(angle);targetV=v+rise*turn
                    z=radius*(1-cos(angle));yaw=angle
                case "awi37.text.attractor":
                    let du=u-pu,dv=v-pv,factor=attraction*exp(-(du*du+dv*dv)/(2*radius*radius))
                    targetU=u-du*factor;targetV=v-dv*factor
                    let desired=atan2(pivot.y-position.y,pivot.x-position.x)
                    let current=glyph.baseRotation+states[index].rotation*Double.pi/180
                    let delta=atan2(sin(desired-current),cos(desired-current))
                    roll=delta*facing*abs(factor)
                    if vertical { roll = -roll }
                default: continue
                }
                let target=vertical ? Vec2(targetV,targetU):Vec2(targetU,targetV)
                states[index].offset=states[index].offset+(target-position)*glyphMix
                states[index].z+=z*glyphMix
                states[index].rotation+=(vertical ? -roll:roll)*180/Double.pi*glyphMix
                if vertical {
                    states[index].rotX-=yaw*180/Double.pi*glyphMix;states[index].rotY+=tilt*180/Double.pi*glyphMix
                } else {
                    states[index].rotY+=yaw*180/Double.pi*glyphMix;states[index].rotX-=tilt*180/Double.pi*glyphMix
                }
            }
        }
    }
}
