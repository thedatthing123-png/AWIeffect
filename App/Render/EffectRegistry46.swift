import Foundation
import Metal
import simd

extension EffectRegistry {
    static let spectral46:[EffectDefinition] = [
        spectral46("band","Spectral Band Filter",0,"Keep or reject a smooth radial frequency band, with separately editable inner and outer limits.",[
            .number("first","Inner Frequency",0.025,0,0.45),.number("second","Outer Frequency",0.25,0.02,0.7),.number("third","Band Softness",0.03,0.005,0.2),.choice("option","Band",["Keep","Reject"],0)]),
        spectral46("direction","Directional Spectrum Gate",1,"Attenuate a pair of frequency wedges to remove oriented image structure without blurring every direction.",[
            .number("first","Angular Width",40,2,170,unit:"°"),.number("second","Rejection",80,0,100,unit:"%"),.angle("angle","Direction",25)]),
        spectral46("notch","Paired Notch Reject",2,"Suppress a selected conjugate frequency pair, useful for periodic pattern removal or deliberate spectral holes.",[
            .point("point","Frequency Position",Vec2(0.55,0.5)),.number("first","Notch Radius",0.045,0.005,0.25),.number("second","Rejection",90,0,100,unit:"%")]),
        spectral46("whiten","Spectral Whiten",3,"Reduce dominant spectral magnitudes relative to weak detail while retaining the original phase and mean.",[
            .number("first","Whitening",0.7,0,1),.number("second","Magnitude Floor",0.02,0.001,0.2)]),
        spectral46("scramble","Phase Scramble",4,"Move image structure by scrambling conjugate phases while preserving frequency magnitudes.",[
            .number("first","Scramble",0.8,0,1),.number("seed","Seed",3,0,1000,step:1),.number("evolution","Evolution",0,-6,6),.number("speed","Phase Speed",0.4,-3,3)]),
        spectral46("quadrature","Quadrature Image",5,"Apply a directional Hilbert-style phase rotation to reveal quadrature structure rather than spatially shifting pixels.",[
            .number("first","Phase Shift",90,-180,180,unit:"°"),.angle("angle","Axis",25)]),
        spectral46("comb","Frequency Comb",6,"Pass repeating radial frequency bands to produce coherent resonances and repeated image structure.",[
            .number("first","Band Spacing",0.08,0.01,0.3),.number("second","Pass Fraction",0.4,0.05,0.95),.number("third","Band Phase",0.2,-4,4)]),
        spectral46("homomorphic","Homomorphic Contrast",7,"Filter log-color illumination and detail separately, then exponentiate back into image space.",[
            .number("first","Frequency Split",0.04,0.005,0.3),.number("second","Low Frequency Gain",0.85,0,1),.number("third","Detail Gain",1.2,0.5,3)]),
        spectral46("spectrum","Image Spectrum",8,"Inspect the centered Fourier magnitude or complex phase of the actual input image.",[
            .number("first","Log Gain",32,1,100),.choice("option","Display",["Magnitude","Phase Color"],0)]),
        spectral46("cepstrum","Image Cepstrum",9,"Inverse-transform log magnitude to expose repeated spacing and image echoes as a new spatial field.",[
            .number("first","Magnitude Floor",0.01,0.0001,0.1),.number("gain","Response",100,1,500)]),
        spectral46("deblur","Regularized Deblur",10,"Invert a Gaussian transfer function with a noise floor and bounded gain; this cannot recreate absent information.",[
            .number("first","Blur Sigma",1.5,0.2,12,unit:"px"),.number("second","Noise Floor",0.05,0.001,0.5),.number("third","Maximum Gain",3,1,12)]),
        spectral46("convolve","Image Convolution",11,"Use a reference layer as a normalized luminance kernel, with padded convolution and editable coverage.",[
            .number("first","Kernel Width",0.5,0.1,1),.number("second","Kernel Contrast",1,0.2,4),.choice("option","Coverage",["Convolve","Keep Source"],0)]),
        spectral46("correlate","Image Correlation",12,"Cross-correlate two layers to display matching offsets, with phase whitening and peak smoothing.",[
            .number("first","Peak Spread",2,0.5,12,unit:"px"),.number("second","Phase Whitening",0.8,0,1),.number("gain","Response",10,1,100)]),
        spectral46("magnitude","Magnitude Transfer",13,"Keep source phase while blending in a reference image's spectral magnitude; this transfers structure statistics rather than a color look.",[
            .number("first","Magnitude Mix",0.7,0,1)]),
        spectral46("dispersion","Wave Dispersion",14,"Apply an odd cubic spectral phase to disperse image features into coherent wave-like trails.",[
            .number("first","Dispersion",8,-400,400),.angle("angle","Direction",25)])
    ]
    private static func spectral46(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi46.spectral."+id,name:name,category:mode==0 || mode==10 || mode==11 ? .blur:.stylize,aeMatchNames:[],summary:summary,
            params:controls+[.choice("quality","Working Resolution",["128 px","256 px","512 px"],1),.number("blend","Blend",100,0,100,unit:"%")],
            expandedMargin:{ e,t,size in mode==11 ? max(size.x,size.y)*min(1,max(0.1,e.params["first"]?.number(at:t) ?? 0.5))*0.5:0 },
            stage:.pixels { ctx in
                guard v29(ctx,"blend")>0 else { return ctx.input }
                if (11...13).contains(mode) && ctx.reference==nil { return ctx.input }
                return FourierEffects46.encode(ctx,mode:mode) ?? ctx.input
            })
    }
}

enum FourierEffects46 {
    static func encode(_ ctx:EffectContext,mode:UInt32) -> MTLTexture? {
        let cap=[128,256,512][EffectRegistry.ch29(ctx,"quality")]
        let raw=ctx.inputPixels ?? ctx.layerPixels ?? SIMD2(Double(ctx.width),Double(ctx.height))
        let extent=SIMD2(min(Double(ctx.width),max(1,raw.x)),min(Double(ctx.height),max(1,raw.y)))
        let domain=extent*(mode==11 ? 2.0:1.0),factor=min(1,Double(cap)/max(domain.x,domain.y))
        func power(_ target:Double) -> Int { var n=1;while n<Int(ceil(target)) && n<cap { n *= 2 };return n }
        let width=power(domain.x*factor),height=power(domain.y*factor)
        let count=(11...13).contains(mode) ? 6:4
        let planes=(0..<count).map{_ in ctx.pool.acquire(width:width,height:height,format:.rgba32Float)}
        guard planes.allSatisfy({$0.width==width && $0.height==height}) else { return nil }
        for i in planes.indices { for j in 0..<i { guard planes[i] !== planes[j] else { return nil } } }
        let mean=ctx.pool.acquire(width:1,height:1,format:.rgba32Float)
        let refMean=(11...13).contains(mode) ? ctx.pool.acquire(width:1,height:1,format:.rgba32Float):mean
        var p=EffectParams();p.i=SIMD4(mode,0,UInt32(EffectRegistry.ch29(ctx,"option")),0)
        p.a=SIMD4(EffectRegistry.f29(ctx,"first"),EffectRegistry.f29(ctx,"second"),EffectRegistry.f29(ctx,"third"),EffectRegistry.pc29(ctx,"blend"))
        p.b=SIMD4(EffectRegistry.f29(ctx,"angle") * .pi/180,EffectRegistry.f29(ctx,"evolution")+Float(ctx.time)*EffectRegistry.f29(ctx,"speed"),EffectRegistry.f29(ctx,"seed"),EffectRegistry.f29(ctx,"gain"))
        p.c=SIMD4(Float(extent.x),Float(extent.y),Float(max(0.05,ctx.unit)),Float(width*height))
        let point=ctx.effect.params["point"]?.point(at:ctx.time) ?? EffectRegistry.definition(ctx.effect.typeID)?.params.first(where:{$0.id=="point"})?.defaultValue.point(at:ctx.time) ?? Vec2(0.5,0.5)
        let layer=ctx.layerPixels ?? extent
        p.d=SIMD4(Float(point.x),Float(point.y),Float(layer.x),Float(layer.y))
        var work=SpectralPoisson45.Work(real:planes[0],imaginary:planes[1],spareReal:planes[2],spareImaginary:planes[3])
        ctx.gpu.run("fxSpectralPrepare46",ctx.cb,textures:[ctx.input,work.real,work.imaginary],params:p,grid:work.real)
        work=SpectralPoisson45.transform(ctx,work,inverse:false)
        ctx.gpu.run("fxSpectralAnchor46",ctx.cb,textures:[work.real,mean],params:p,grid:mean)
        var referenceReal=work.real,referenceImaginary=work.imaginary
        if (11...13).contains(mode),let reference=ctx.reference {
            var refWork=SpectralPoisson45.Work(real:work.spareReal,imaginary:work.spareImaginary,spareReal:planes[4],spareImaginary:planes[5])
            var rp=p;rp.i.y=1
            ctx.gpu.run("fxSpectralPrepare46",ctx.cb,textures:[reference,refWork.real,refWork.imaginary],params:rp,grid:refWork.real)
            refWork=SpectralPoisson45.transform(ctx,refWork,inverse:false)
            ctx.gpu.run("fxSpectralAnchor46",ctx.cb,textures:[refWork.real,refMean],params:p,grid:refMean)
            referenceReal=refWork.real;referenceImaginary=refWork.imaginary
            work.spareReal=refWork.spareReal;work.spareImaginary=refWork.spareImaginary
        }
        if mode != 8 {
            ctx.gpu.run("fxSpectralModify46",ctx.cb,textures:[work.real,work.spareReal,work.imaginary,work.spareImaginary,referenceReal,referenceImaginary,mean,refMean],params:p,grid:work.spareReal)
            work.flip();work=SpectralPoisson45.transform(ctx,work,inverse:true)
        }
        let output=ctx.temp();ctx.gpu.run("fxSpectralFinish46",ctx.cb,textures:[ctx.input,output,work.real,work.imaginary,mean],params:p,grid:output);return output
    }
}
