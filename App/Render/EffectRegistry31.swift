import Foundation
import Metal
import simd

/// Distinct signal-damage primitives. Modes share timing and safe sampling, not a look preset.
extension EffectRegistry {
    static let flow31:[EffectDefinition] = [
        flow31("flowWarp","Motion Warp",0,.distort,"Displace the current image along motion estimated from actual upstream frames.",
            [.number("strength","Warp",80,-300,300,unit:"%")]),
        flow31("flowSmear","Motion Path Smear",1,.blur,"Integrate image samples along a dense estimated motion field, including motion inside footage.",
            [.number("strength","Path Length",120,0,500,unit:"%"),.number("samples","Path Samples",8,2,16,step:1)]),
        flow31("flowMap","Motion Field",2,.stylize,"Render measured motion as direction color, an RG displacement map, or a moving-region matte.",
            [.number("range","Display Range",24,1,256,unit:"px"),
             .choice("output","Field Output",["Direction Color","RG Displacement","Motion Matte"],0)]),
        flow31("flowDatamosh","Flow Datamosh",3,.glitch,"Carry pixels from a real earlier frame using block-held measured motion and an editable hit envelope.",
            [.number("amount","Amount",70,0,100,unit:"%"),.number("block","Block Size",18,2,128,unit:"px"),
             .number("carry","Vector Carry",1.8,0,5),
             .choice("motion","Motion",["Smooth","Choppy","Burst","On Keyframe"],0),
             .number("speed","Pattern Speed",3,0,24),.number("seed","Seed",3,0,1000,step:1),
             .number("frequency","Bursts Per Second",2,0.2,15),.number("duration","Hit Duration",0.18,0.02,1,unit:"s"),
             .number("trigger","Keyframe Hit",100,0,100,unit:"%")])
    ]
    private static func flow31(_ id:String,_ name:String,_ mode:UInt32,_ category:EffectCategory,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi31."+id,name:name,category:category,aeMatchNames:[],summary:summary,
            params:[.number("delay","Frame Interval",0.1,0.01,1,unit:"s"),
                .number("maximum","Maximum Motion",64,4,256,unit:"px"),
                .choice("quality","Motion Solver",["Fast","Fine"],0),
                .number("confidence","Reject Weak Motion",10,0,95,unit:"%")]+controls+[
                .number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                guard v29(ctx,"blend")>0,let sample=ctx.temporalSample else { return ctx.input }
                if mode<=1 && abs(v29(ctx,"strength"))<0.00001 { return ctx.input }
                let timing=signalClock31(ctx)
                if mode==3 && v29(ctx,"amount")*timing.1<=0 { return ctx.input }
                guard let previous=sample(ctx.time-v29(ctx,"delay")) else { return ctx.input }
                let flow=measuredFlow31(ctx,previous:previous)
                var p=EffectParams();p.i=SIMD4(mode,UInt32(ch29(ctx,"output")),UInt32(max(2,min(16,Int(v29(ctx,"samples"))))),0)
                p.a=SIMD4(pc29(ctx,"strength"),pc29(ctx,"blend"),pc29(ctx,"confidence"),Float(timing.0))
                p.b=SIMD4(px29(ctx,"range"),px29(ctx,"block"),f29(ctx,"carry"),pc29(ctx,"amount")*Float(timing.1))
                p.c.x=f29(ctx,"seed")
                let output=ctx.temp()
                ctx.gpu.run("fxMeasuredFlow31",ctx.cb,textures:[ctx.input,output,flow,previous],params:p,grid:output)
                return output
            })
    }

    /// Dense coarse-to-fine Lucas–Kanade. All images/fields remain on the GPU;
    /// finest solve is bounded to 128/256 pixels on the long side, independently
    /// of the output resolution. Half-float RG stores signed pixel displacement.
    static func measuredFlow31(_ ctx:EffectContext,previous:MTLTexture) -> MTLTexture {
        let fine=ch29(ctx,"quality")==1,limit=fine ? 256:128
        let factor=min(1,Double(limit)/Double(max(ctx.width,ctx.height)))
        let width=max(1,Int((Double(ctx.width)*factor).rounded())),height=max(1,Int((Double(ctx.height)*factor).rounded()))
        func scaled(_ texture:MTLTexture,_ w:Int,_ h:Int) -> MTLTexture {
            let output=ctx.pool.acquire(width:w,height:h)
            ctx.gpu.run("fxResample",ctx.cb,textures:[texture,output],grid:output)
            return output
        }
        let sigma=max(0.6,0.5/max(factor,0.0001))
        var current=[scaled(ctx.gpu.gaussian(ctx,input:ctx.input,sigma:sigma),width,height)]
        var history=[scaled(ctx.gpu.gaussian(ctx,input:previous,sigma:sigma),width,height)]
        for _ in 0..<2 {
            let w=max(1,current.last!.width/2),h=max(1,current.last!.height/2)
            current.append(scaled(ctx.gpu.gaussian(ctx,input:current.last!,sigma:0.8),w,h))
            history.append(scaled(ctx.gpu.gaussian(ctx,input:history.last!,sigma:0.8),w,h))
        }
        var estimate=ctx.pool.acquire(width:current.last!.width,height:current.last!.height)
        ctx.gpu.run("fxClear",ctx.cb,textures:[estimate],grid:estimate)
        for level in (0..<current.count).reversed() {
            let image=current[level]
            for _ in 0..<(fine ? 5:3) {
                var p=EffectParams()
                p.a=SIMD4(Float(v29(ctx,"maximum")*ctx.unit*Double(image.width)/Double(ctx.width)),
                    Float(v29(ctx,"maximum")*ctx.unit*Double(image.height)/Double(ctx.height)),0.8,0)
                p.i.x=fine ? 2:1
                let next=ctx.pool.acquire(width:image.width,height:image.height)
                ctx.gpu.run("fxSolveFlow31",ctx.cb,textures:[image,next,history[level],estimate],params:p,grid:next)
                estimate=next
            }
        }
        return estimate
    }

    static func signalClock31(_ ctx:EffectContext) -> (Double,Double) {
        var clock=ctx.time*v29(ctx,"speed"),envelope=1.0
        switch ch29(ctx,"motion") {
        case 1:clock=floor(clock)
        case 2:
            let frequency=max(v29(ctx,"frequency"),0.01),phase=ctx.time*frequency
            let elapsed=(phase-floor(phase))/frequency
            envelope=max(0,1-elapsed/max(v29(ctx,"duration"),0.001))
        case 3:
            envelope=0
            if case .number(let animated)?=ctx.effect.params["trigger"] {
                for key in animated.keyframes where key.time<=ctx.time && key.value>0 {
                    envelope=max(envelope,key.value/100*max(0,1-(ctx.time-key.time)/max(v29(ctx,"duration"),0.001)))
                }
            }
        default:break
        }
        return (clock,envelope)
    }

    static let sorting31:[EffectDefinition]=[
        EffectDefinition(id:"awi31.segmentSort",name:"Segment Pixel Sort",category:.glitch,aeMatchNames:[],
            summary:"Actually reorder pixels within threshold-selected runs, bounded by editable windows. Excluded pixels stay in their original positions.",
            params:[.number("length","Sort Window",64,8,128,unit:"px"),
                .number("low","Minimum Luma",15,0,100,unit:"%"),.number("high","Maximum Luma",95,0,100,unit:"%"),
                .choice("axis","Direction",["Horizontal","Vertical"],0),
                .choice("key","Sort By",["Brightness","Hue","Saturation"],0),
                .toggle("descending","Reverse Order",false),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                var p=EffectParams()
                p.a=SIMD4(pc29(ctx,"low"),pc29(ctx,"high"),pc29(ctx,"blend"),0)
                p.i=SIMD4(UInt32(ch29(ctx,"axis")),UInt32(ch29(ctx,"key")),b29(ctx,"descending") ? 1:0,0)
                let output=ctx.temp()
                ctx.gpu.segmentSort31(ctx,input:ctx.input,output:output,
                    span:min(256,max(2,Int((v29(ctx,"length")*ctx.unit).rounded()))),params:p)
                return output
            })
    ]
    static let batch31: [EffectDefinition] = [
        glitch31("rowDuplicate", "Row Duplicate", 0, "Selected scan rows repeat a neighboring strip while other rows remain intact.",
                 .number("scale", "Strip Height", 14, 2, 100, unit: "px"), .number("detail", "Repeat Distance", 30, 1, 180, unit: "px")),
        glitch31("columnMelt", "Column Melt", 1, "Vertical strips drag downward with different lengths and smoothly varying offsets.",
                 .number("scale", "Column Width", 18, 2, 120, unit: "px"), .number("detail", "Melt Length", 75, 1, 240, unit: "px")),
        glitch31("mirrorTear", "Mirror Tear", 2, "Horizontal damage bands reflect their image fragments around an adjustable axis.",
                 .number("scale", "Band Height", 24, 2, 120, unit: "px"), .number("detail", "Mirror Axis", 50, 5, 95, unit: "%")),
        glitch31("chromaShatter", "Chroma Shatter", 3, "Unequal rectangular chroma cells separate in two dimensions without moving the luma core.",
                 .number("scale", "Cell Size", 24, 3, 120, unit: "px"), .number("detail", "Chroma Distance", 25, 1, 100, unit: "px")),
        glitch31("codecChroma", "Codec Chroma", 4, "Coarse chroma subsampling bleeds color across macroblocks while retaining luminance detail.",
                 .number("scale", "Macroblock", 18, 2, 96, unit: "px"), .number("detail", "Color Levels", 7, 2, 24, step: 1)),
        glitch31("interlaceTear", "Interlace Tear", 5, "Alternating scan fields slip in opposite directions, with a traveling field boundary.",
                 .number("scale", "Field Height", 4, 1, 30, unit: "px"), .number("detail", "Field Slip", 24, 1, 120, unit: "px")),
        glitch31("signalDrop", "Signal Drop", 6, "Rolling dropout bands dissolve into monochrome static, preserving the picture outside the dropout.",
                 .number("scale", "Band Height", 35, 3, 160, unit: "px"), .number("detail", "Static Grain", 3, 1, 20, unit: "px")),
        glitch31("trackingBand", "Tracking Band", 7, "One moving tracking band shears sideways with ragged noisy boundaries.",
                 .number("scale", "Band Width", 34, 3, 180, unit: "px"), .number("detail", "Tracking Slip", 55, 1, 180, unit: "px")),
        glitch31("rollingSync", "Rolling Sync", 8, "Vertical sync loss rolls the picture and bends the seam rather than adding generic RGB blocks.",
                 .number("scale", "Seam Width", 24, 2, 120, unit: "px"), .number("detail", "Seam Bend", 50, 1, 180, unit: "px")),
        glitch31("channelRows", "Channel Rows", 9, "Different horizontal bands carry different channel permutations and local brightness errors.",
                 .number("scale", "Row Height", 20, 2, 120, unit: "px"), .number("detail", "Channel Bias", 45, 1, 100, unit: "%")),
        glitch31("blockLuma", "Block Luma", 10, "Macroblocks keep their source texture but acquire mismatched exposure and contrast.",
                 .number("scale", "Block Size", 25, 3, 100, unit: "px"), .number("detail", "Exposure Error", 1.5, 0.1, 4, unit: "stops")),
        glitch31("tileSlip", "Tile Slip", 11, "Whole rectangular cells slide into neighboring positions with continuous drift or held jumps.",
                 .number("scale", "Tile Size", 30, 4, 140, unit: "px"), .number("detail", "Slide Distance", 45, 1, 160, unit: "px")),
        glitch31("chromaRows", "Chroma Rows", 12, "Color channels shear across scan rows while the green channel holds the image structure.",
                 .number("scale", "Row Height", 8, 1, 60, unit: "px"), .number("detail", "Channel Slip", 20, 1, 100, unit: "px")),
        glitch31("analogBars", "Analog Noise Bars", 13, "Wide analog interference bars alter luminance and slowly bend horizontal detail.",
                 .number("scale", "Bar Height", 26, 3, 140, unit: "px"), .number("detail", "Bar Contrast", 65, 1, 100, unit: "%")),
        glitch31("directionalBleed", "Directional Bleed", 14, "A multi-tap source-color bleed works across rows or columns with independent strip lengths.",
                 .number("scale", "Strip Size", 12, 2, 100, unit: "px"), .number("detail", "Bleed Distance", 50, 1, 180, unit: "px")),
        glitch31("blockInvert", "Block Invert", 16, "A moving field of cells inverts image values while undamaged cells keep their original colors.",
                 .number("scale", "Block Size", 28, 3, 140, unit: "px"), .number("detail", "Coverage", 50, 5, 95, unit: "%")),
        glitch31("posterizeBands", "Posterize Bands", 17, "Adjacent scan bands crush the source to different tonal resolutions.",
                 .number("scale", "Band Height", 19, 2, 120, unit: "px"), .number("detail", "Tonal Levels", 5, 2, 24, step: 1)),
        glitch31("chromaEcho", "Chroma Echo", 18, "Three colored image copies separate along a rotating direction with a stable center image.",
                 .number("scale", "Copy Distance", 24, 2, 120, unit: "px"), .number("detail", "Color Trail", 65, 5, 100, unit: "%")),
        glitch31("staircaseTear", "Staircase Tear", 19, "Horizontal displacement steps across a moving staircase of diagonal scan groups.",
                 .number("scale", "Step Height", 18, 2, 100, unit: "px"), .number("detail", "Step Offset", 25, 1, 120, unit: "px")),
        glitch31("diagonalShred", "Diagonal Shred", 20, "Diagonal strips slide across the picture along their own axes.",
                 .number("scale", "Strip Width", 15, 2, 100, unit: "px"), .number("detail", "Shred Distance", 35, 1, 140, unit: "px")),
        glitch31("quadrantSlip", "Quadrant Slip", 21, "Groups of four image cells slide in opposing directions, breaking the picture into coherent chunks.",
                 .number("scale", "Cell Size", 35, 5, 140, unit: "px"), .number("detail", "Slip Distance", 35, 1, 140, unit: "px")),
        glitch31("scanlineRipple", "Scanline Ripple", 22, "A narrow-band horizontal carrier warps scanlines with a second slow modulation.",
                 .number("scale", "Wave Height", 12, 2, 80, unit: "px"), .number("detail", "Warp Distance", 24, 1, 120, unit: "px")),
        glitch31("chromaPulse", "Chroma Pulse", 23, "Separate channels expand and contract around the image center like a misaligned color tube.",
                 .number("scale", "Pulse Size", 25, 2, 100, unit: "px"), .number("detail", "Pulse Spread", 65, 5, 100, unit: "%")),
        glitch31("stripPixelate", "Strip Pixelate", 24, "Rows or columns quantize to different pixel lengths instead of applying one uniform mosaic.",
                 .number("scale", "Strip Size", 16, 2, 100, unit: "px"), .number("detail", "Pixel Length", 25, 2, 100, unit: "px")),
        glitch31("edgeTear", "Edge Tear", 26, "Horizontal slices displace only the strongest image contours, leaving flat color fields intact.",
                 .number("scale", "Slice Height", 14, 2, 100, unit: "px"), .number("detail", "Tear Distance", 25, 1, 120, unit: "px")),
        glitch31("rasterSkew", "Raster Skew", 27, "Repeated raster groups tilt sideways with independent slopes, as if line timing lost alignment.",
                 .number("scale", "Group Height", 30, 3, 140, unit: "px"), .number("detail", "Skew Distance", 35, 1, 140, unit: "px")),
        glitch31("lumaShards", "Luma Shards", 28, "Bright and dark source regions shear in opposite directions inside a field of scan cells.",
                 .number("scale", "Cell Size", 24, 3, 120, unit: "px"), .number("detail", "Shear Distance", 30, 1, 140, unit: "px")),
        glitch31("bitplaneSlip", "Bitplane Slip", 29, "Quantized low bitplanes shift relative to the stable high-value image structure.",
                 .number("scale", "Shift Distance", 12, 1, 80, unit: "px"), .number("detail", "Bit Levels", 8, 2, 32, step: 1)),
        glitch31("scanlineComb", "Scanline Comb", 30, "Alternating thin scanlines sample opposing displaced positions, producing a visible comb tear.",
                 .number("scale", "Tooth Height", 3, 1, 24, unit: "px"), .number("detail", "Comb Distance", 18, 1, 100, unit: "px")),
        glitch31("blockDesync", "Block Desync", 31, "Separate macroblocks acquire different cyclic vertical timing offsets with readable seams.",
                 .number("scale", "Block Size", 28, 4, 140, unit: "px"), .number("detail", "Desync Distance", 45, 1, 180, unit: "px"))
    ]

    private static func glitch31(_ id: String, _ name: String, _ mode: UInt32, _ summary: String,
                                 _ scale: ParamDef, _ detail: ParamDef) -> EffectDefinition {
        EffectDefinition(id: "awi31."+id, name: name, category: .glitch, aeMatchNames: [], summary: summary,
            params: [.number("amount", "Amount", 65, 0, 100, unit: "%"), scale, detail]
                + ([14,24].contains(mode) ? [.choice("axis","Direction",["Horizontal","Vertical"],0)] : [])
                + [
                .choice("motion", "Motion", ["Smooth", "Choppy", "Burst", "On Keyframe"], 0),
                .number("speed", "Pattern Speed", 3, 0, 24), .number("seed", "Seed", 3, 0, 1000, step: 1),
                .number("frequency", "Bursts Per Second", 2, 0.2, 15),
                .number("duration", "Hit Duration", 0.18, 0.02, 1, unit: "s"),
                .number("trigger", "Keyframe Hit", 100, 0, 100, unit: "%"),
                .number("blend", "Blend", 100, 0, 100, unit: "%")],
            stage: .pixels { ctx in
                var clock = ctx.time * v29(ctx,"speed"), envelope = 1.0
                switch ch29(ctx,"motion") {
                case 1: clock = floor(clock)
                case 2:
                    let phase = ctx.time * v29(ctx,"frequency")
                    let elapsed = (phase-floor(phase))/max(v29(ctx,"frequency"),0.01)
                    envelope = max(0,1-elapsed/max(v29(ctx,"duration"),0.001))
                case 3:
                    envelope = 0
                    if case .number(let animated)? = ctx.effect.params["trigger"] {
                        for key in animated.keyframes where key.time <= ctx.time && key.value > 0 {
                            envelope = max(envelope,key.value/100 * max(0,1-(ctx.time-key.time)/max(v29(ctx,"duration"),0.001)))
                        }
                    }
                default: break
                }
                var p = EffectParams()
                p.a = SIMD4(pc29(ctx,"amount")*Float(envelope),px29(ctx,"scale"),f29(ctx,"detail"),Float(clock))
                // Detail pixel units vary by effect; transfer explicitly so non-pixel controls stay dimensionless.
                if case .number(_,_,_,let unit) = detail.kind, unit == "px" { p.a.z *= Float(ctx.unit) }
                p.b = SIMD4(f29(ctx,"seed"),pc29(ctx,"blend"),0,0)
                p.i.x = mode
                p.i.y = UInt32(ch29(ctx,"axis"))
                let output = ctx.temp()
                ctx.gpu.run("fxSignal31",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
}
