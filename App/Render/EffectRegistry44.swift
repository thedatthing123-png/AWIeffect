import Foundation
import Metal
import simd

extension EffectRegistry {
    static let finishes44:[EffectDefinition] = [
        finish44("brushed","Brushed Surface",0,"Directional micro-grooves stretch reflections along a brushed surface while retaining the source artwork.",
            10,0.8,80,.number("shape","Brush Wandering",0.45,0,2)),
        finish44("hammered","Hammered Surface",1,"Rounded irregular impact pits deform surface normals; specular light follows the actual pit geometry.",
            22,3,85,.number("shape","Pit Roundness",1.2,0.3,3)),
        finish44("woven","Woven Relief",2,"Alternating crossing thread profiles create over-under relief and directional surface reflections.",
            12,1.8,15,.number("shape","Thread Rounding",1.5,0.3,4)),
        finish44("glaze","Cracked Glaze",3,"Irregular cellular seams cut through a glossy surface, with separate crack depth and darkening.",
            30,2.5,10,.number("shape","Crack Width",0.07,0.015,0.3),[.number("special","Crack Darkening",65,0,100,unit:"%")]),
        finish44("ink","Pooled Ink",4,"Dark image regions pool into raised glossy ink, with capillary texture and a separately controlled source relief.",
            16,2,5,.number("shape","Pooling Curve",1.7,0.3,4)),
        finish44("prisms","Prism Grooves",5,"Asymmetric prism facets refract source channels by different amounts and carry a movable reflection.",
            18,2,20,.number("shape","Facet Balance",0.35,0.1,0.9),[.number("dispersion","Dispersion",2,0,12,unit:"px")]),
        finish44("foil","Folded Foil",6,"Interacting sharp and broad creases create a folded reflective finish rather than a flat rainbow overlay.",
            35,4,90,.number("shape","Crease Sharpness",1.4,0.3,3)),
        finish44("iridescent","Iridescent Ridges",7,"Curved surface ridges modulate a wavelength-based coating reflection as the surface and light change.",
            24,2,25,.number("shape","Ridge Curvature",1.1,0.1,3),[.number("special","Film Thickness",420,100,1200,unit:"nm")])
    ]
    private static func finish44(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ size:Double,_ depth:Double,_ metal:Double,
                                 _ shape:ParamDef,_ extra:[ParamDef]=[]) -> EffectDefinition {
        EffectDefinition(id:"awi44.finish."+id,name:name,category:.stylize,aeMatchNames:[],summary:summary,
            params:[.number("size","Surface Scale",size,2,160,unit:"px"),.number("depth","Surface Depth",depth,0,12,unit:"px"),shape] + extra + [
                .number("relief","Image Relief",0.8,0,12,unit:"px"),.number("smooth","Relief Smoothing",2,0.5,20,unit:"px"),
                .angle("angle","Surface Direction",25),.angle("light","Light Direction",mode==0 ? -65:-45),.number("elevation","Light Elevation",mode==4 ? 75:45,5,85,unit:"°"),
                .number("roughness","Roughness",mode==0 ? 0.4:mode==4 ? 0.22:0.34,0.08,0.85),.number("metal","Metalness",metal,0,100,unit:"%"),
                .number("energy","Light Energy",2,0,6),.number("ambient","Ambient",0.3,0,1),
                .number("evolution","Evolution",0,-10,10),.number("speed","Surface Speed",0.15,-2,2),
                .number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard v29(ctx,"blend")>0 else { return ctx.input }
                let needsHeight=v29(ctx,"relief")>0 || (mode==4 && v29(ctx,"depth")>0)
                let soft=needsHeight ? ctx.gpu.gaussian(ctx,input:ctx.input,sigma:v29(ctx,"smooth")*ctx.unit):ctx.input
                var p=EffectParams()
                p.a=SIMD4(max(0.5,px29(ctx,"size")),px29(ctx,"depth"),px29(ctx,"relief"),pc29(ctx,"blend"))
                p.b=SIMD4(f29(ctx,"angle") * .pi/180,f29(ctx,"light") * .pi/180,f29(ctx,"elevation") * .pi/180,f29(ctx,"roughness"))
                p.c=SIMD4(pc29(ctx,"metal"),f29(ctx,"energy"),f29(ctx,"ambient"),f29(ctx,"shape"))
                p.d=SIMD4(f29(ctx,"evolution")+Float(ctx.time)*f29(ctx,"speed"),f29(ctx,"special"),px29(ctx,"dispersion"),Float(max(0.5,ctx.unit)))
                p.i.x=mode
                let output=ctx.temp();ctx.gpu.run("fxSurfaceFinish44",ctx.cb,textures:[ctx.input,output,soft],params:p,grid:output);return output
            })
    }
}
