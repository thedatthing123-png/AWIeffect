import Foundation
import Metal
import simd

extension EffectRegistry {
    static let poisson45:[EffectDefinition] = [
        poisson45("normalHeight","Normal to Height",0,"Integrate tangent-space normals into a zero-mean height field using a periodic Poisson solve.",[
            .number("strength","Slope Scale",1,-4,4),.number("range","Height Range",400,1,600,unit:"px"),
            .number("minimum","Minimum Normal Z",0.15,0.02,0.8)]),
        poisson45("gradientHeight","Gradient Integrate",1,"Recover a scalar height from centered RG gradients, projecting inconsistent gradients onto an integrable field.",[
            .number("strength","Gradient Scale",1,-4,4),.number("range","Height Range",120,1,600,unit:"px")]),
        poisson45("reshape","Gradient Reshape",2,"Compress or amplify image gradients and reconstruct color globally, keeping the sampled image mean.",[
            .number("exponent","Gradient Exponent",0.8,0.2,2),.number("threshold","Gradient Pivot",4,0.2,30,unit:"%")]),
        poisson45("tile","Periodic Texture",3,"Remove the smooth boundary-discontinuity component of an image to reduce visible RGB tile seams.",[
            .number("vertical","Vertical Priority",1,0.1,4)])
    ]
    private static func poisson45(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi45.poisson."+id,name:name,category:mode<2 ? .color:.stylize,aeMatchNames:[],summary:summary,
            params:controls+[.choice("quality","Solver Resolution",["128 px","256 px","512 px"],1),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                guard v29(ctx,"blend")>0 else { return ctx.input }
                return SpectralPoisson45.encode(ctx,mode:mode) ?? ctx.input
            })
    }
}

/// Four reused complex scratch planes; no CPU readback, per-pixel iterative solve,
/// or unbounded transform size. All FFT arithmetic and storage are float32.
enum SpectralPoisson45 {
    struct Work {
        var real:MTLTexture;var imaginary:MTLTexture;var spareReal:MTLTexture;var spareImaginary:MTLTexture
        mutating func flip() {
            let r=real,i=imaginary;real=spareReal;imaginary=spareImaginary;spareReal=r;spareImaginary=i
        }
    }
    static func transform(_ ctx:EffectContext,_ input:Work,inverse:Bool) -> Work {
        var work=input
        ctx.gpu.run("fxFFTReorder45",ctx.cb,textures:[work.real,work.spareReal,work.imaginary,work.spareImaginary],grid:work.spareReal)
        work.flip()
        for axis in 0..<2 {
            let length=axis==0 ? work.real.width:work.real.height
            var stage=2
            while stage<=length {
                var p=EffectParams();p.i=SIMD4(UInt32(stage),UInt32(axis),inverse ? 1:0,0)
                ctx.gpu.run("fxFFTStage45",ctx.cb,textures:[work.real,work.spareReal,work.imaginary,work.spareImaginary],params:p,grid:work.spareReal)
                work.flip();stage *= 2
            }
        }
        return work
    }
    static func encode(_ ctx:EffectContext,mode:UInt32) -> MTLTexture? {
        let cap=[128,256,512][EffectRegistry.ch29(ctx,"quality")]
        let raw=ctx.inputPixels ?? ctx.layerPixels ?? SIMD2(Double(ctx.width),Double(ctx.height))
        let extent=SIMD2(min(Double(ctx.width),max(1,raw.x)),min(Double(ctx.height),max(1,raw.y)))
        let factor=min(1,Double(cap)/max(extent.x,extent.y))
        func power(_ target:Double) -> Int { var n=1;while n<Int(ceil(target)) && n<cap { n *= 2 };return n }
        let width=power(extent.x*factor),height=power(extent.y*factor)
        let planes=(0..<5).map { _ in ctx.pool.acquire(width:width,height:height,format:.rgba32Float) }
        guard planes.allSatisfy({$0.width==width && $0.height==height}) else { return nil }
        for index in planes.indices { for prior in 0..<index { guard planes[index] !== planes[prior] else { return nil } } }
        let source=planes[0]
        var p=EffectParams()
        p.a=SIMD4(Float(extent.x),Float(extent.y),EffectRegistry.f29(ctx,"strength"),EffectRegistry.f29(ctx,"range"))
        p.b=SIMD4(EffectRegistry.f29(ctx,"exponent"),EffectRegistry.pc29(ctx,"threshold"),EffectRegistry.f29(ctx,"minimum"),EffectRegistry.pc29(ctx,"blend"))
        p.c=SIMD4(mode==3 ? EffectRegistry.f29(ctx,"vertical"):1,Float(width*height),Float(max(0.05,ctx.unit)),0)
        p.i.x=mode
        ctx.gpu.run("fxPoissonPrepare45",ctx.cb,textures:[ctx.input,source],params:p,grid:source)
        var mean=source
        if mode==2 {
            while mean.width>1 || mean.height>1 {
                let w=max(1,mean.width/2),h=max(1,mean.height/2),reduced=ctx.pool.acquire(width:w,height:h,format:.rgba32Float)
                guard reduced.width==w,reduced.height==h,reduced !== mean else { return nil }
                ctx.gpu.run("fxPoissonMean45",ctx.cb,textures:[mean,reduced],grid:reduced);mean=reduced
            }
        }
        var work=Work(real:planes[1],imaginary:planes[2],spareReal:planes[3],spareImaginary:planes[4])
        ctx.gpu.run("fxPoissonForce45",ctx.cb,textures:[source,work.real,work.imaginary],params:p,grid:work.real)
        work=transform(ctx,work,inverse:false)
        ctx.gpu.run("fxPoissonDivide45",ctx.cb,textures:[work.real,work.spareReal,work.imaginary,work.spareImaginary],params:p,grid:work.spareReal)
        work.flip()
        work=transform(ctx,work,inverse:true)
        let output=ctx.temp()
        ctx.gpu.run("fxPoissonFinish45",ctx.cb,textures:[ctx.input,output,work.real,mean],params:p,grid:output)
        return output
    }
}
