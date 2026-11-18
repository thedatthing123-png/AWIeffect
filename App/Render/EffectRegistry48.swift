import Foundation
import Metal
import simd

extension EffectRegistry {
    static let craft48:[EffectDefinition] = [
        craft48("stamp","Tonal Stamp",0,.stylize,"Turn sampled image tone into editable stamp coverage, including shapes and colored paper.",[
            .number("first","Cell Size",14,4,80,unit:"px"),.number("second","Tone Curve",1.2,0.2,4),.number("third","Stamp Fill",0.85,0.1,1),.choice("option","Stamp",["Disc","Diamond","Cross","Bar"],0)]),
        craft48("stitch","Contour Stitch",1,.stylize,"Place short threads across the actual cutout boundary, oriented by its local normal.",[
            .number("first","Stitch Spacing",14,4,60,unit:"px"),.number("second","Stitch Length",8,2,40,unit:"px"),.number("third","Thread Width",1.5,0.5,6,unit:"px")]),
        craft48("fringe","Rope Fringe",2,.stylize,"Extend sampled boundary color into curved, tapered strands outside the cutout.",[
            .number("first","Strand Length",18,2,100,unit:"px"),.number("second","Strand Spacing",7,2,30,unit:"px"),.number("third","Strand Bend",0.6,-2,2)]),
        craft48("paper","Paper Cut Layers",3,.stylize,"Quantized source-tone layers cast small directional shadows onto lower paper levels.",[
            .number("first","Paper Levels",5,2,12,step:1),.number("second","Step Height",6,1,24,unit:"px"),.number("third","Shadow",0.65,0,1)]),
        craft48("lenticular","Lenticular Flip",4,.transition,"Interlace source and reference through refracting strips with an editable viewing angle.",[
            .number("first","Strip Width",12,3,60,unit:"px"),.number("second","View Angle",0.25,-1,1),.number("third","Lens Strength",0.4,0,1)]),
        craft48("sequin","Sequin Image",5,.stylize,"Rebuild source color as separated, tilting reflective discs with actual coverage gaps.",[
            .number("first","Disc Size",14,6,80,unit:"px"),.number("second","Tilt",30,-70,70,unit:"°"),.number("third","Gap",0.12,0.02,0.4)]),
        craft48("chords","Chord Art",6,.stylize,"Sample image darkness along bounded circular chords, then draw the resulting weighted line structure.",[
            .number("first","Chords",24,8,48,step:1),.number("second","Line Width",1.2,0.4,4,unit:"px"),.number("third","Tone Response",2,0.2,5)]),
        craft48("junctions","Junction Flares",7,.color,"Detect mixed-direction image corners and place glints there, instead of making every bright pixel sparkle.",[
            .number("first","Detection Cell",24,8,80,unit:"px"),.number("second","Detection Radius",2,0.5,12,unit:"px"),.number("third","Glint Reach",0.55,0.1,0.9),.number("gain","Sensitivity",6,0.1,30)]),
        craft48("flowLight","Ink Flow Light",8,.color,"Image contours steer luminous ink trails through a local tangent field, with a separately softened halo.",[
            .number("first","Flow Length",40,2,160,unit:"px"),.number("second","Edge Scale",2,0.5,16,unit:"px"),.number("third","Response",3,0.1,12)]),
        craft48("chromaTrails","Chromatic Edge Trails",9,.color,"Send independently oriented RGB edge energy into colored directional trails while retaining the source.",[
            .number("first","Trail Length",50,2,200,unit:"px"),.number("second","Edge Scale",2,0.5,16,unit:"px"),.number("third","Decay",2,0.1,6)]),
        craft48("caustics","Relief Caustics",10,.color,"Curvature focuses and defocuses refracted source light using a protected local mapping Jacobian.",[
            .number("first","Relief Travel",20,-80,80,unit:"px"),.number("second","Surface Smoothing",4,1,24,unit:"px"),.number("third","Focusing",1.5,0.1,5)]),
        craft48("prismInk","Prism Ink",11,.color,"Dark image strokes act as small spectral lenses, bending source channels and emitting a tight edge light.",[
            .number("first","Dispersion",6,0,40,unit:"px"),.number("second","Ink Scale",2,0.5,16,unit:"px"),.number("third","Ink Threshold",0.1,0,0.5)]),
        craft48("collage","Photo Collage",12,.stylize,"Reassemble local image patches as jittered paper photographs with borders, gaps and cast shadows.",[
            .number("first","Patch Size",50,16,140,unit:"px"),.number("second","Scatter",0.3,0,0.9),.number("third","Patch Rotation",10,0,45,unit:"°"),.number("gain","Border Width",2,0.4,8,unit:"px")]),
        craft48("plexus","Image Plexus",13,.color,"Image gradients displace graph nodes; connections inherit source color and respond to source intensity.",[
            .number("first","Cell Size",26,8,100,unit:"px"),.number("second","Node Warp",40,0,80,unit:"%"),.number("third","Line Width",1.2,0.4,6,unit:"px"),.number("gain","Connection Threshold",25,0,100,unit:"%"),.choice("option","Drawing",["Lines","Lines and Points"],1)]),
        craft48("burn","Contour Burn",14,.transition,"Burn inward from the real cutout boundary, with a dark char band and independently softened ember light.",[
            .number("first","Burn Depth",8,0,1000,unit:"px"),.number("second","Ember Width",2,0.5,20,unit:"px"),.number("third","Char Width",4,0.5,30,unit:"px")])
    ]
    private static func craft48(_ id:String,_ name:String,_ mode:UInt32,_ category:EffectCategory,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        var parameters=controls
        if [1,2,14].contains(mode) { parameters += [.choice("source","Boundary Source",["Alpha","Luminance"],0),.number("threshold","Boundary Threshold",50,1,99,unit:"%"),.choice("quality","Contour Resolution",["512 px","1024 px","2048 px"],0)] }
        if [7,13].contains(mode) { parameters.append(.choice("quality","Detection Detail",["Fast","Fine"],0)) }
        if [0,3,4,6,7,8,9,12].contains(mode) { parameters.append(.angle("angle","Direction",mode==3 ? -45:15)) }
        if [5,6,7,12].contains(mode) { parameters += [.number("seed","Seed",3,0,1000,step:1),.number("evolution","Evolution",0,-10,10),.number("speed","Evolution Speed",0.3,-2,2)] }
        let light=[7,8,9,10,11,13,14].contains(mode)
        if ![3,4,5,12].contains(mode) { parameters.append(.color("ink",light ? "Light Color":"Ink / Thread Color",light ? RGBA(0.4,0.8,1):RGBA(0.08,0.12,0.2))) }
        if [0,6,12].contains(mode) { parameters.append(.color("paper","Paper Color",RGBA(0.96,0.93,0.86))) }
        if light { parameters += [.number("halo","Halo Radius",12,1,120,unit:"px"),.number("energy","Light Energy",1.5,0,5),.toggle("only","Effect Only",false)] }
        parameters.append(.number("blend","Blend",100,0,100,unit:"%"))
        return EffectDefinition(id:"awi48.craft."+id,name:name,category:category,aeMatchNames:[],summary:summary,params:parameters,
            margin:{ e,t in
                let halo=light ? 3*(e.params["halo"]?.number(at:t) ?? 12):0
                let first=e.params["first"]?.number(at:t) ?? controls.first(where:{$0.id=="first"})?.defaultValue.number(at:t) ?? 0
                if mode==1 { return (e.params["second"]?.number(at:t) ?? 8)*0.5 }
                if mode==2 { return abs(first) }
                if mode==12 { return first }
                return halo+([9,10,11].contains(mode) ? abs(first):0)
            },stage:.pixels { ctx in CraftGPU48.encode(ctx,mode:mode,light:light) })
    }
}

enum CraftGPU48 {
    static func encode(_ ctx:EffectContext,mode:UInt32,light:Bool) -> MTLTexture {
        if EffectRegistry.v29(ctx,"blend")<=0 { return ctx.input }
        if mode==4 && ctx.reference==nil { return ctx.input }
        if mode==14 && EffectRegistry.v29(ctx,"first")<=0 && !EffectRegistry.b29(ctx,"only") { return ctx.input }
        let factor=light ? min(1,1024.0/Double(max(ctx.width,ctx.height))):1
        var input=ctx.input
        if factor<1 { input=ctx.pool.acquire(width:max(1,Int(Double(ctx.width)*factor)),height:max(1,Int(Double(ctx.height)*factor)));ctx.gpu.run("fxResample",ctx.cb,textures:[ctx.input,input],grid:input) }
        var wc=EffectContext(gpu:ctx.gpu,cb:ctx.cb,input:input,effect:ctx.effect,time:ctx.time,unit:ctx.unit*factor,pool:ctx.pool)
        wc.layerPixels=ctx.layerPixels.map{$0*factor};wc.inputPixels=ctx.inputPixels.map{$0*factor};wc.reference=ctx.reference
        let a=EffectRegistry.v29(wc,"first"),b=EffectRegistry.v29(wc,"second"),c=EffectRegistry.v29(wc,"third")
        let pixelA = ![3,6].contains(mode),pixelB=[1,2,3,6,7,8,9,10,11,14].contains(mode),pixelC=[1,13,14].contains(mode)
        var p=EffectParams();p.a=SIMD4(Float(a*(pixelA ? wc.unit:1)),Float(b*(pixelB ? wc.unit:1)),Float(c*(pixelC ? wc.unit:1)),EffectRegistry.pc29(wc,"blend"))
        p.b=EffectRegistry.col29(wc,"ink");p.c=EffectRegistry.col29(wc,"paper")
        p.d=SIMD4(EffectRegistry.f29(wc,"angle") * .pi/180,EffectRegistry.f29(wc,"evolution")+Float(wc.time)*EffectRegistry.f29(wc,"speed"),EffectRegistry.f29(wc,"seed"),Float(max(0.35,wc.unit)))
        p.i=SIMD4(mode,UInt32(EffectRegistry.ch29(wc,"option")),EffectRegistry.f29(wc,"gain").bitPattern,UInt32(EffectRegistry.ch29(wc,"source")))
        if [1,2,14].contains(mode) { p.i.z=EffectRegistry.pc29(wc,"threshold").bitPattern }
        if mode==12 { p.i.z=EffectRegistry.px29(wc,"gain").bitPattern }
        if mode==13 { p.i.z=EffectRegistry.pc29(wc,"gain").bitPattern }
        let size=wc.layerPixels ?? SIMD2(Double(wc.width),Double(wc.height)),origin=SIMD2(Double(wc.width),Double(wc.height))*0.5-size*0.5
        let layout=[SIMD4(Float(size.x),Float(size.y),Float(origin.x),Float(origin.y))]
        let sigma=[7,8,9,10,11].contains(mode) ? b*wc.unit:2*wc.unit
        let soft=wc.gpu.gaussian(wc,input:input,sigma:sigma)
        var field=input
        if [1,2,14].contains(mode) { guard let found=DistanceField41.encode(wc) else { return ctx.input };field=found }
        var nodes=input
        if [6,7,13].contains(mode) {
            let cap=EffectRegistry.ch29(wc,"quality")==1 ? 512:256
            if mode != 6 { p.a.x=max(p.a.x,Float(max(wc.width,wc.height))/Float(cap-2)) }
            let width=mode==6 ? max(8,min(48,Int(a.rounded()))):min(cap,Int(ceil(Double(wc.width)/Double(p.a.x)))+2)
            let height=mode==6 ? 2:min(cap,Int(ceil(Double(wc.height)/Double(p.a.x)))+2)
            nodes=ctx.pool.acquire(width:width,height:height,format:.rgba32Float)
            wc.gpu.run("fxCraftPrepare48",wc.cb,textures:[input,nodes,soft],params:p,extra:layout,grid:nodes)
        }
        let core=wc.temp(),base=wc.temp()
        wc.gpu.run("fxCraft48",wc.cb,textures:[input,core,soft,field,nodes,ctx.reference ?? input,base],params:p,extra:layout,grid:core)
        var result=core
        if light {
            let halo=wc.gpu.gaussian(wc,input:core,sigma:EffectRegistry.v29(wc,"halo")*wc.unit)
            let energy=EffectRegistry.v29(ctx,"energy")
            let glow=EffectRegistry.lightSum25(wc,[core,halo],[energy,0.65*energy])
            let fullGlow=ctx.temp();ctx.gpu.run("fxResample",ctx.cb,textures:[glow,fullGlow],grid:fullGlow)
            var background=ctx.input
            if [10,11,14].contains(mode) { background=ctx.temp();ctx.gpu.run("fxResample",ctx.cb,textures:[base,background],grid:background) }
            let only=EffectRegistry.b29(ctx,"only")
            result=EffectRegistry.lightComp25(ctx,base:background,glow:fullGlow,intensity:1,composite:only ? .glowOnly:.over)
            if !only { let corrected=ctx.temp();ctx.gpu.run("fxChangeComposite38",ctx.cb,textures:[background,corrected,result,fullGlow],grid:corrected);result=corrected }
        }
        if EffectRegistry.v29(ctx,"blend")>=100 { return result }
        let out=ctx.temp();var mix=EffectParams();mix.a.x=EffectRegistry.pc29(ctx,"blend");ctx.gpu.run("fxTimeComposite33",ctx.cb,textures:[ctx.input,out,result],params:mix,grid:out);return out
    }
}
