import Foundation
import Metal
import simd

extension EffectRegistry {
    static let interactions47:[EffectDefinition] = [
        interaction47("calculate","Channel Calculations",0,.color,"Calculate source and reference channels together, including signed arithmetic and alpha output.",[
            .choice("option","Source Channel",["RGB","Red","Green","Blue","Alpha","Luma"],0),.choice("channel","Reference Channel",["RGB","Red","Green","Blue","Alpha","Luma"],0),
            .choice("operation","Calculation",["Multiply","Add","Subtract","Difference","Divide","Minimum","Maximum"],0),.choice("target","Output",["RGB","Alpha"],0),
            .number("amount","Gain",1,0,4),.number("detail","Bias",0,-1,1)]),
        interaction47("uv","UV Remap",1,.distort,"Read absolute image coordinates from a reference RG map, rather than treating it as an offset.",[
            .number("amount","Map Strength",100,0,100,unit:"%")]),
        interaction47("polar","Polar Map Displacement",2,.distort,"Interpret reference red and green as radial and tangential displacements around an editable center.",[
            .number("distance","Travel",30,-160,160,unit:"px"),.number("amount","Tangential Scale",1,-2,2),.point("center","Center",Vec2(0.5,0.5))]),
        interaction47("advect","Map Advection",3,.distort,"Transport source pixels through a separate RG velocity field using midpoint integration.",[
            .number("distance","Travel",32,-200,200,unit:"px"),.number("steps","Integration Steps",8,1,16,step:1)]),
        interaction47("smear","Vector Map Smear",4,.blur,"Integrate source colors along a curved reference vector path with independently controlled decay.",[
            .number("distance","Path Length",40,0,240,unit:"px"),.number("steps","Path Samples",12,2,24,step:1),.number("amount","Decay",1.5,0.1,4)]),
        interaction47("refract","Height Map Refraction",5,.distort,"A separate height layer refracts source channels through its gradients, with optical index and dispersion.",[
            .number("radius","Surface Smoothing",2,0.5,16,unit:"px"),.number("distance","Thickness",35,-120,120,unit:"px"),
            .number("amount","Index of Refraction",1.45,1.01,2.5),.number("detail","Dispersion",0.06,0,0.3)]),
        interaction47("focus","Compound Focus",6,.blur,"A separate depth layer controls the local defocus radius around an editable focal depth.",[
            .number("distance","Maximum Blur",14,0,80,unit:"px"),.number("amount","Focal Depth",0.3,0,1),.number("detail","Focus Range",0.2,0.02,1),.number("steps","Aperture Samples",16,4,24,step:1)]),
        interaction47("bomb","Texture Bomb",7,.stylize,"Scatter cropped reference-image patches across the source with independent density, scale and rotation.",[
            .number("radius","Patch Size",36,8,128,unit:"px"),.number("distance","Scatter",12,0,60,unit:"px"),.number("amount","Density",0.8,0.05,1),
            .number("detail","Patch Scale",0.8,0.2,2),.number("aux","Seed",3,0,1000,step:1),.angle("angle","Patch Rotation",20)]),
        interaction47("match","Local Color Match",8,.color,"Match local reference color and contrast while retaining source detail and coverage.",[
            .number("radius","Neighborhood",12,1,80,unit:"px"),.number("amount","Color Match",80,0,100,unit:"%"),.number("detail","Contrast Match",0.6,0,1)]),
        interaction47("detail","Detail Transfer",9,.stylize,"Combine source structure with a separately extracted reference detail band.",[
            .number("radius","Detail Scale",4,0.5,32,unit:"px"),.number("amount","Reference Detail",1.2,-3,3),.number("detail","Source Detail",0.5,0,1)]),
        interaction47("dissolve","Map Dissolve",10,.transition,"Reveal or remove the source through an arbitrary animated reference intensity map.",[
            .number("amount","Completion",50,0,100,unit:"%"),.number("detail","Softness",0.08,0.001,0.5),.choice("option","Map",["Normal","Inverted"],0)]),
        interaction47("matte","Matte Advection",11,.keying,"Move only source coverage along a reference velocity field, keeping source color independent.",[
            .number("distance","Travel",18,-120,120,unit:"px"),.number("steps","Integration Steps",8,1,16,step:1)]),
        interaction47("normalLight","Normal Decal Light",12,.color,"Light source artwork using another layer's RGB normals, with separate diffuse, specular and ambient controls.",[
            .number("amount","Diffuse",1.1,0,3),.number("detail","Gloss",24,2,128),.number("aux","Specular",0.7,0,4),.number("radius","Ambient",0.2,0,1),
            .number("threshold","Metalness",30,0,100,unit:"%"),.angle("angle","Light Direction",-45),.number("elevation","Light Elevation",40,5,85,unit:"°"),.color("color","Light Color",RGBA(1,0.95,0.85))]),
        interaction47("fog","Depth Fog",13,.color,"Composite aerial haze according to an independent depth map, with near/far control.",[
            .number("amount","Density",1.2,0,5),.number("detail","Near Depth",0.1,0,0.95),.number("threshold","Far Depth",90,5,100,unit:"%"),.color("color","Fog Color",RGBA(0.5,0.65,0.8))]),
        interaction47("parallax","Depth Parallax",14,.distort,"March a view ray through a reference height field to find the visible source location, rather than applying a single offset.",[
            .number("distance","Travel",30,-160,160,unit:"px"),.number("detail","Relief Contrast",1,0.1,3),.number("steps","Ray Steps",16,4,32,step:1),.angle("angle","View Direction",20)]),
        interaction47("pack","Channel Pack",15,.color,"Replace one source channel with a selected reference channel, including correct alpha repremultiplication.",[
            .choice("option","Destination",["Red","Green","Blue","Alpha"],0),.choice("channel","Reference Channel",["Red","Green","Blue","Alpha","Luma"],4),
            .number("amount","Gain",1,0,4),.number("detail","Bias",0,-1,1)]),
        interaction47("register","Image Registration",16,.distort,"Estimate a dense source-to-reference alignment field and warp source pixels toward the matching image.",[
            .number("distance","Alignment",100,-100,200,unit:"%"),.number("maximum","Maximum Search",48,4,128,unit:"px"),
            .number("threshold","Reject Weak Matches",5,0,90,unit:"%"),.choice("quality","Alignment Solver",["Fast","Fine"],0)]),
        interaction47("occlusion","Depth Occlusion",17,.color,"Estimate local screen-space occlusion from a depth reference and shade the source without changing alpha.",[
            .number("radius","Radius",12,1,80,unit:"px"),.number("amount","Occlusion",1.5,0,4),.number("detail","Depth Bias",0.02,0,0.2),.number("aux","Depth Scale",1,0.1,4)]),
        interaction47("shadow","Relief Cast Shadow",18,.color,"Trace toward a directional light through reference relief to cast self-shadow onto source artwork.",[
            .number("radius","Surface Smoothing",2,0.5,16,unit:"px"),.number("distance","Shadow Reach",40,1,200,unit:"px"),.number("amount","Height Scale",1,0.05,4),
            .number("detail","Depth Bias",0.02,0,0.2),.angle("angle","Light Direction",-45),.number("threshold","Light Elevation",35,5,85,unit:"°")]),
        interaction47("palette","Palette Lookup",19,.color,"Use any row of a reference image as a continuous palette, with contrast, offset and addressing controls.",[
            .number("distance","Palette Row",0.5,0,1),.number("amount","Lookup Contrast",1.2,0.2,4),.number("detail","Palette Offset",0,-1,1),.choice("option","Addressing",["Clamp","Repeat","Mirror"],0)])
    ]
    private static func interaction47(_ id:String,_ name:String,_ mode:UInt32,_ category:EffectCategory,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        var params=controls
        if [1,2,3,4,5,6,11,14,16].contains(mode) { params.append(.choice("edge","Edges",["Transparent","Clamp","Repeat","Mirror"],1)) }
        params.append(.number("blend","Blend",100,0,100,unit:"%"))
        return EffectDefinition(id:"awi47.layer."+id,name:name,category:category,aeMatchNames:[],summary:summary,params:params,stage:.pixels { ctx in
            guard v29(ctx,"blend")>0,let reference=ctx.reference else { return ctx.input }
            // Exact identity at the dissolve's first frame, without a sampling
            // pass perturbing the original coverage on another GPU backend.
            if mode==10 && v29(ctx,"amount")<=0 { return ctx.input }
            let sourceSoft=[8,9].contains(mode) ? ctx.gpu.gaussian(ctx,input:ctx.input,sigma:v29(ctx,"radius")*ctx.unit):ctx.input
            let referenceSoft=[5,8,9,18].contains(mode) ? ctx.gpu.gaussian(ctx,input:reference,sigma:v29(ctx,"radius")*ctx.unit):reference
            let flow=mode==16 ? measuredFlow31(ctx,previous:reference):reference
            var p=EffectParams()
            p.a=SIMD4(px29(ctx,"distance"),px29(ctx,"radius"),f29(ctx,"amount"),Float(max(0.5,ctx.unit)))
            p.b=SIMD4(f29(ctx,"detail"),pc29(ctx,"threshold"),pc29(ctx,"softness"),pc29(ctx,"blend"))
            p.c=col29(ctx,"color");p.d=SIMD4(f29(ctx,"angle") * .pi/180,f29(ctx,"elevation") * .pi/180,f29(ctx,"aux"),f29(ctx,"steps"))
            p.i=SIMD4(mode,UInt32(ch29(ctx,"option")),UInt32(ch29(ctx,"edge")),0)
            if mode==0 { p.i.z=UInt32(ch29(ctx,"channel"));p.i.w=UInt32(ch29(ctx,"operation"));p.d.w=Float(ch29(ctx,"target")) }
            if mode==2 { let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5);p.c.x=Float(center.x*Double(ctx.width));p.c.y=Float(center.y*Double(ctx.height)) }
            if mode==12 { p.a.y=f29(ctx,"radius") }
            if mode==15 { p.i.z=UInt32(ch29(ctx,"channel")) }
            if mode==16 { p.a.x=pc29(ctx,"distance") }
            if mode==18 { p.b.y=f29(ctx,"threshold") * .pi/180 }
            if mode==19 { p.a.x=f29(ctx,"distance") }
            let output=ctx.temp();ctx.gpu.run("fxLayerInteraction47",ctx.cb,textures:[ctx.input,output,reference,sourceSoft,referenceSoft,flow],params:p,grid:output);return output
        })
    }
}
