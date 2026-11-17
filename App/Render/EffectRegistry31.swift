import Foundation
import Metal
import simd

/// Distinct signal-damage primitives. Modes share timing and safe sampling, not a look preset.
extension EffectRegistry {
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
        glitch31("horizontalBleed", "Horizontal Bleed", 14, "A directional multi-tap pixel bleed spreads source colors across selected rows.",
                 .number("scale", "Row Height", 12, 2, 100, unit: "px"), .number("detail", "Bleed Distance", 50, 1, 180, unit: "px")),
        glitch31("verticalBleed", "Vertical Bleed", 15, "Selected columns bleed their own colors downward with independently varying lengths.",
                 .number("scale", "Column Width", 12, 2, 100, unit: "px"), .number("detail", "Bleed Distance", 50, 1, 180, unit: "px")),
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
        glitch31("pixelColumns", "Pixel Columns", 24, "Vertical strips quantize to different pixel heights, like mismatched digital column buffers.",
                 .number("scale", "Column Width", 16, 2, 100, unit: "px"), .number("detail", "Pixel Height", 25, 2, 100, unit: "px")),
        glitch31("pixelRows", "Pixel Rows", 25, "Horizontal strips quantize to different pixel widths without applying a uniform mosaic.",
                 .number("scale", "Row Height", 16, 2, 100, unit: "px"), .number("detail", "Pixel Width", 25, 2, 100, unit: "px")),
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
            params: [.number("amount", "Amount", 65, 0, 100, unit: "%"), scale, detail,
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
                let output = ctx.temp()
                ctx.gpu.run("fxSignal31",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
}
