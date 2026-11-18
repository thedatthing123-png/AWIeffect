import Foundation
import Metal
import simd

/// Contour processing from an approximate Euclidean distance transform, not
/// repeated alpha blurs. See docs/DISTANCE_EFFECTS.md for accuracy and cost.
extension EffectRegistry {
    static let distance41:[EffectDefinition] = [
        distance41("map","Signed Distance Map",0,.keying,"Encode inward and outward distance from the selected boundary around middle gray.",[
            .number("range","Distance Range",32,1,240,unit:"px")]),
        distance41("vectors","Boundary Vectors",1,.color,"Encode the displacement to the nearest contour point as centered RG vectors.",[
            .number("range","Vector Range",32,1,240,unit:"px")]),
        distance41("extend","Nearest Color Extend",2,.keying,"Extend actual boundary colors into transparent pixels without blurring across the shape.",[
            .number("range","Extension",24,1,240,unit:"px"),.number("falloff","Falloff",1,0.1,6),
            .number("inset","Color Sample Inset",2,0.5,16,unit:"px")]),
        distance41("pull","Boundary Pull",3,.distort,"Pull interior texture toward its nearest contour while keeping the existing cutout coverage.",[
            .number("range","Reach",40,1,240,unit:"px"),.number("amount","Pull",70,0,100,unit:"%")]),
        distance41("bands","Contour Bands",4,.stylize,"Draw evenly spaced bands following the real silhouette, including concave edges and holes.",[
            .number("range","Reach",40,1,240,unit:"px"),.number("period","Band Spacing",10,2,80,unit:"px"),
            .number("width","Band Width",35,5,90,unit:"%"),.number("phase","Phase",0.2,-4,4),
            .color("color","Band Color",RGBA(0.2,0.85,1)),.choice("side","Side",["Both","Inside","Outside"],0)]),
        distance41("ridges","Medial Ridges",5,.keying,"Extract interior distance-field ridges where competing contour fronts meet. This is a soft ridge matte, not a topology-preserving skeleton.",[
            .number("range","Minimum Depth",2,0.5,40,unit:"px"),.number("amount","Ridge Sensitivity",0.65,0.1,1),
            .number("width","Ridge Sampling",2,0.5,12,unit:"px")]),
        distance41("refract","Contour Refraction",6,.distort,"Refract texture through a curved contour rim using normals from nearest-boundary geometry.",[
            .number("range","Rim Width",24,1,160,unit:"px"),.number("amount","Refraction",14,-80,80,unit:"px"),
            .number("curve","Rim Curve",1.5,0.2,6)]),
        distance41("flow","Contour Flow",7,.distort,"Move texture tangentially along the silhouette with several integration steps, rather than a fixed image-axis offset.",[
            .number("range","Reach",36,1,200,unit:"px"),.number("amount","Travel",20,-100,100,unit:"px"),
            .number("steps","Integration Steps",6,1,12,step:1)]),
        distance41("light","Contour Light Sweep",8,.color,"Send a luminous band through successive contour depths with a separate soft halo and retained source.",[
            .number("range","Sweep Depth",12,-120,120,unit:"px"),.number("width","Light Width",3,0.5,30,unit:"px"),
            .number("halo","Halo Width",10,1,80,unit:"px"),.number("amount","Light Energy",2,0.1,8),
            .number("speed","Sweep Speed",16,-100,100,unit:"px/s"),.color("color","Light Color",RGBA(0.3,0.65,1))]),
        distance41("fold","Contour Fold",9,.distort,"Reflect successive strips of texture back toward the nearest contour, folding image detail along the silhouette.",[
            .number("range","Reach",50,1,200,unit:"px"),.number("period","Fold Spacing",14,2,80,unit:"px"),
            .number("amount","Fold Strength",80,0,100,unit:"%"),.number("phase","Phase",0.2,-4,4)])
    ]
    private static func distance41(_ id:String,_ name:String,_ mode:UInt32,_ category:EffectCategory,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi41.contour."+id,name:name,category:category,aeMatchNames:[],summary:summary,
            params:controls + [.choice("source","Boundary Source",["Alpha","Luminance"],0),
                .number("threshold","Boundary Threshold",50,1,99,unit:"%"),
                .choice("quality","Field Resolution",["512 px","1024 px","2048 px"],1),
                .number("blend","Blend",100,0,100,unit:"%")],
            margin:{ e,t in
                guard [2,4,8].contains(mode) else { return 0 }
                let range=abs(e.params["range"]?.number(at:t) ?? (mode==2 ? 24:mode==4 ? 40:12))
                return mode==8 ? range+3*(e.params["halo"]?.number(at:t) ?? 10):range+2
            },stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                guard let field=DistanceField41.encode(ctx) else { return ctx.input }
                var p=EffectParams()
                p.a=SIMD4(Float(ctx.width),Float(ctx.height),px29(ctx,"range"),pc29(ctx,"blend"))
                p.b=SIMD4(px29(ctx,"period"),f29(ctx,"width"),f29(ctx,"phase"),f29(ctx,"amount"))
                p.c=SIMD4(f29(ctx,"falloff"),px29(ctx,"inset"),px29(ctx,"halo"),f29(ctx,"curve"))
                p.d=col29(ctx,"color")
                p.i=SIMD4(mode,UInt32(ch29(ctx,"side")),UInt32(max(1,min(12,Int(v29(ctx,"steps").rounded())))),0)
                p.i.w=(UInt32((pc29(ctx,"threshold")*65535).rounded())<<1)|UInt32(ch29(ctx,"source"))
                // Width/amount units differ by operation, and are explicitly packed here.
                if mode==5 { p.b.y=px29(ctx,"width") }
                if mode==6 || mode==7 { p.b.w=px29(ctx,"amount") }
                if mode==8 { p.a.z += Float(ctx.time)*px29(ctx,"speed");p.b.y=px29(ctx,"width") }
                let output=ctx.temp()
                ctx.gpu.run("fxContourFinish41",ctx.cb,textures:[ctx.input,output,field],params:p,grid:output)
                return output
            })
    }
}

enum DistanceField41 {
    /// Two ping-pong RG32 buffers retain subpixel contour positions even on large
    /// sources. Resolution is capped; extra unit jumps reduce JFA approximation error.
    static func encode(_ ctx:EffectContext) -> MTLTexture? {
        let limit=[512,1024,2048][EffectRegistry.ch29(ctx,"quality")]
        let scale=min(1,Double(limit)/Double(max(ctx.width,ctx.height)))
        let width=max(1,Int((Double(ctx.width)*scale).rounded())),height=max(1,Int((Double(ctx.height)*scale).rounded()))
        let first=ctx.pool.acquire(width:width,height:height,format:.rg32Float)
        let second=ctx.pool.acquire(width:width,height:height,format:.rg32Float)
        guard first.width==width,first.height==height,second.width==width,second.height==height,first !== second else { return nil }
        var p=EffectParams();p.a=SIMD4(Float(ctx.width),Float(ctx.height),EffectRegistry.pc29(ctx,"threshold"),0)
        p.i.y=UInt32(EffectRegistry.ch29(ctx,"source"))
        ctx.gpu.run("fxContourSeed41",ctx.cb,textures:[ctx.input,first],params:p,grid:first)
        var current=first,other=second,jump=1
        while jump<max(width,height) { jump *= 2 }
        jump /= 2
        while jump>=1 {
            p.i.x=UInt32(jump)
            ctx.gpu.run("fxContourFlood41",ctx.cb,textures:[current,other],params:p,grid:other)
            swap(&current,&other);jump /= 2
        }
        for _ in 0..<2 {
            p.i.x=1
            ctx.gpu.run("fxContourFlood41",ctx.cb,textures:[current,other],params:p,grid:other)
            swap(&current,&other)
        }
        return current
    }
}
