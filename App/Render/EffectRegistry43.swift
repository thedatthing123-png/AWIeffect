import Foundation
import Metal
import simd

extension EffectRegistry {
    static let temporalAnalysis43:[EffectDefinition] = [
        temporal43("variance","Temporal Variance",0,"Measure variation across actual frames instead of measuring spatial texture.",[
            .number("gain","Response",4,0.1,20)]),
        temporal43("occupancy","Change Occupancy",1,"Measure how often each pixel changes across consecutive samples in a time window.",[
            .number("threshold","Change Threshold",10,0,100,unit:"%"),.number("softness","Threshold Softness",10,1,100,unit:"%")]),
        temporal43("changeTime","Change Timing Map",2,"Color pixels by when their strongest change occurred, with a strength gate for stable areas.",[
            .number("threshold","Change Threshold",8,0,100,unit:"%"),.number("gain","Response",4,0.1,20)]),
        temporal43("acceleration","Temporal Acceleration",3,"Isolate changes in the rate of image change using a centered second time difference.",[
            .number("gain","Response",3,0.1,20)]),
        temporal43("rank","Temporal Rank",4,"Sort sampled frames by per-pixel brightness and choose an interpolated rank while retaining complete pixel colors.",[
            .number("rank","Rank",25,0,100,unit:"%")]),
        temporal43("sigma","Temporal Sigma Clip",5,"Average real frames while rejecting temporal outliers using local mean and standard deviation.",[
            .number("sigma","Sigma Limit",1,0.2,4),.number("floor","Noise Floor",2,0.1,20,unit:"%")]),
        temporal43("trend","Temporal Color Trend",6,"Fit a straight color trend through the sample window; centered RGB encodes falling and rising channels.",[
            .number("gain","Response",2,0.1,12)]),
        temporal43("frequency","Temporal Frequency",7,"Measure temporal oscillation at a chosen number of cycles across the window, rejecting the constant image component.",[
            .number("cycles","Cycles per Window",1,0.25,3.5),.number("gain","Response",3,0.1,16)]),
        temporal43("history","Frame History Grid",8,"Show successive real frames together in an editable grid, useful for contact-sheet motion designs.",[
            .number("columns","Columns",3,2,4,step:1),.number("gap","Gap",3,0,24,unit:"px")])
    ]
    private static func temporal43(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        var params:[ParamDef]=[.number("span","Time Window",0.4,0.01,2,unit:"s"),.number("offset","Time Offset",0,-2,2,unit:"s")]
        if mode != 3 { params.append(.number("samples","Frame Samples",mode==7 ? 8:6,mode==7 ? 4:2,8,step:1)) }
        params += controls + [.number("blend","Blend",100,0,100,unit:"%")]
        return EffectDefinition(id:"awi43.time."+id,name:name,category:.stylize,aeMatchNames:[],summary:summary,params:params,
            stage:.pixels { ctx in
                guard v29(ctx,"blend")>0,let sample=ctx.temporalSample else { return ctx.input }
                let count=mode==3 ? 3:max(mode==7 ? 4:2,min(8,Int(v29(ctx,"samples").rounded())))
                var frames:[MTLTexture]=[]
                for index in 0..<count {
                    let t=ctx.time+v29(ctx,"offset")-v29(ctx,"span")*(1-Double(index)/Double(count-1))
                    guard let frame=sample(t) else { return ctx.input };frames.append(frame)
                }
                while frames.count<8 { frames.append(frames.last!) }
                var p=EffectParams();p.i=SIMD4(mode,UInt32(count),UInt32(max(2,min(4,Int(v29(ctx,"columns").rounded())))),0)
                p.a=SIMD4(pc29(ctx,"blend"),f29(ctx,"gain"),pc29(ctx,"threshold"),pc29(ctx,"softness"))
                p.b=SIMD4(pc29(ctx,"rank"),f29(ctx,"sigma"),pc29(ctx,"floor"),f29(ctx,"cycles"))
                p.c.x=px29(ctx,"gap")
                let output=ctx.temp();ctx.gpu.run("fxTemporalAnalysis43",ctx.cb,textures:[ctx.input,output]+frames,params:p,grid:output);return output
            })
    }
}
