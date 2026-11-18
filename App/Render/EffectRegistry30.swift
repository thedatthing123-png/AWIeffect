import Foundation
import Metal
import simd

/// Background generators, expansion batch 30. Each mode is a separate visual primitive,
/// with its own controls rather than a preset of another effect.
extension EffectRegistry {
    static let math30:[EffectDefinition] = [
        math30("chladni","Chladni Plate",0,"Vibrating-plate nodal curves form crisp branching sand-like patterns.",
            [.number("first","First Mode",4,1,14,step:1),.number("second","Second Mode",7,1,14,step:1),.number("third","Node Width",0.08,0.01,0.4)],0xE9D3A3,0x233548),
        math30("quasicrystal","Quasicrystal",1,"Several noncrystallographic wave directions intersect into repeating-looking structures without an ordinary tile grid.",
            [.number("first","Directions",5,3,11,step:1),.number("second","Frequency",12,2,40),.number("third","Band Width",0.2,0.03,0.7)],0xB9EAE0,0x293654),
        math30("carpet","Fractal Carpet",2,"Recursive central openings create a scale-dependent square fractal, with editable hole proportions.",
            [.number("first","Recursion",4,1,6,step:1),.number("second","Hole Width",0.333,0.1,0.65),.number("third","Edge Softness",0.01,0.001,0.08)],0xF4C29A,0x49394F),
        math30("newton","Newton Basins",3,"Complex polynomial iteration divides the plane by which root attracts each point, with convergence contour shading.",
            [.number("first","Roots",3,2,6,step:1),.number("second","Iterations",18,4,32,step:1),.number("third","Contour Shading",0.7,0.05,2)],0x8DE3DD,0x8451A3),
        math30("primeSpiral","Prime Spiral",4,"Prime-number marks follow an integer square spiral; change the number offset to rebuild the pattern.",
            [.number("first","Grid Size",41,9,81,step:1),.number("second","Mark Size",0.7,0.1,0.95),.number("third","Number Offset",0,0,1000,step:1)],0xF2D38D,0x292C4B),
        math30("hilbert","Hilbert Path",5,"A connected space-filling curve winds through every cell, with a traveling highlight along its true path order.",
            [.number("first","Order",4,1,6,step:1),.number("second","Stroke Width",1.5,0.4,8,unit:"px"),.number("third","Highlight Width",0.3,0.04,1)],0xD9B9F8,0x252D48),
        math30("dipole","Dipole Lines",6,"Curved field lines and equipotential bands flow around two opposite analytic poles.",
            [.number("first","Pole Separation",0.45,0.1,1.2),.number("second","Line Count",12,2,40),.number("third","Line Width",0.15,0.02,0.6)],0xF0B5C3,0x293B54)
    ]
    private static func math30(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef],_ first:UInt32,_ second:UInt32) -> EffectDefinition {
        EffectDefinition(id:"awi30.math."+id,name:name,category:.generate,aeMatchNames:[],summary:summary,
            params:controls+[.number("zoom","Zoom",1,0.3,4),.point("center","Center",Vec2(0.5,0.5)),
                .angle("angle","Direction",0),.number("evolution","Evolution",0,-4,4),
                .number("speed","Evolution Speed",0.15,-2,2),.color("color","First Color",RGBA(hex:first)),
                .color("color2","Second Color",RGBA(hex:second)),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                let canvas=ctx.layerPixels ?? SIMD2(Double(ctx.width),Double(ctx.height))
                var p=EffectParams()
                p.a=SIMD4(f29(ctx,"zoom"),f29(ctx,"evolution")+Float(ctx.time)*f29(ctx,"speed"),pc29(ctx,"blend"),Float(min(canvas.x,canvas.y)))
                p.b=col29(ctx,"color");p.c=col29(ctx,"color2")
                p.d=SIMD4(Float(Double(ctx.width)*0.5+(center.x-0.5)*canvas.x),Float(Double(ctx.height)*0.5+(center.y-0.5)*canvas.y),f29(ctx,"angle") * .pi/180,Float(ctx.unit))
                p.i=SIMD4(mode,f29(ctx,"first").bitPattern,f29(ctx,"second").bitPattern,f29(ctx,"third").bitPattern)
                let output=ctx.temp()
                ctx.gpu.run("fxMathBackground30",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }

    static let batch30: [EffectDefinition] = [
        background30("solidSunburst", "Solid Sunburst", 0,
            "Solid candy starburst wedges, not light rays. Editable duty, twist and radial fade.",
            [.number("scale", "Wedges", 14, 2, 96, step: 1), .number("width", "Wedge Width", 50, 2, 98, unit: "%"),
             .number("shape", "Twist", 0.15, -4, 4), .number("softness", "Edge Softness", 1, 0, 30, unit: "%"),
             .number("fade", "Radial Fade", 18, 0, 100, unit: "%")], RGBA(hex: 0xFF627D), RGBA(hex: 0xFFE6B5)),
        background30("spiralBands", "Spiral Bands", 1,
            "Flat two-color spiral ribbons with adjustable arms, pitch and band width.",
            [.number("scale", "Arms", 5, 1, 32, step: 1), .number("width", "Band Width", 50, 2, 98, unit: "%"),
             .number("shape", "Pitch", 3, 0.2, 12)], RGBA(hex: 0x2A174A), RGBA(hex: 0xB3A1FF)),
        background30("chevronStripes", "Chevron Stripes", 2,
            "Continuous zigzag stripes. Change the slope and repeat spacing without a bitmap overlay.",
            [.number("scale", "Repeats", 7, 1, 40), .number("width", "Stripe Width", 42, 2, 98, unit: "%"),
             .number("shape", "Chevron Depth", 0.65, 0, 2)], RGBA(hex: 0x173A48), RGBA(hex: 0x7BEBCA)),
        background30("wovenPattern", "Woven Pattern", 3,
            "Interlaced horizontal and vertical ribbons with alternating over-under crossings.",
            [.number("scale", "Weave Count", 9, 2, 50), .number("width", "Ribbon Width", 65, 10, 95, unit: "%"),
             .number("shape", "Crossing Shade", 35, 0, 90, unit: "%")], RGBA(hex: 0xDCB883), RGBA(hex: 0x503A48)),
        background30("arcTiles", "Arc Tiles", 4,
            "Truchet quarter-circle connections form a seamless maze. Seed changes the tile connections.",
            [.number("scale", "Tile Count", 8, 2, 40), .number("width", "Line Width", 18, 2, 70, unit: "%"),
             .number("shape", "Seed", 7, 0, 1000, step: 1)], RGBA(hex: 0xE8D5A9), RGBA(hex: 0x1A3540)),
        background30("contourMap", "Contour Map", 5,
            "Animated topographic contour lines from a continuous noise field, independent of the image.",
            [.number("scale", "Terrain Scale", 3, 0.5, 12), .number("width", "Line Width", 15, 2, 70, unit: "%"),
             .number("shape", "Contour Count", 9, 2, 28)], RGBA(hex: 0x8EE8CC), RGBA(hex: 0x112E34)),
        background30("scallopPattern", "Scallop Pattern", 6,
            "Overlapping fish-scale arcs, with a controllable fan spread and border thickness.",
            [.number("scale", "Scale Count", 7, 2, 35), .number("width", "Border Width", 12, 2, 45, unit: "%"),
             .number("shape", "Fan Spread", 0.75, 0.3, 1.5)], RGBA(hex: 0xF6C680), RGBA(hex: 0x344C72)),
        background30("diamondLattice", "Diamond Lattice", 7,
            "Crossed diagonal lattice with independent horizontal stretch and clean antialiased lines.",
            [.number("scale", "Diamond Count", 9, 2, 45), .number("width", "Line Width", 10, 1, 70, unit: "%"),
             .number("shape", "Stretch", 1.4, 0.3, 3)], RGBA(hex: 0xAFA7F6), RGBA(hex: 0x28203F)),
        background30("dotWaves", "Dot Waves", 8,
            "A regular dot field breathes along traveling wave fronts. Not a halftone filter of the image.",
            [.number("scale", "Dot Count", 13, 3, 55), .number("width", "Dot Size", 58, 5, 95, unit: "%"),
             .number("shape", "Wave Depth", 65, 0, 100, unit: "%")], RGBA(hex: 0xF1A7FF), RGBA(hex: 0x231839)),
        background30("crossGrid", "Cross Grid", 9,
            "An offset field of plus-sign registration marks. Arm length and stroke width are independent.",
            [.number("scale", "Mark Count", 8, 2, 40), .number("width", "Stroke Width", 10, 1, 45, unit: "%"),
             .number("shape", "Arm Length", 35, 10, 90, unit: "%")], RGBA(hex: 0x6BCEEB), RGBA(hex: 0x142F43)),
        background30("ribbonGradient", "Ribbon Gradient", 10,
            "Soft diagonal color ribbons drift and bend continuously, with adjustable wave amplitude.",
            [.number("scale", "Ribbon Count", 2.5, 0.3, 10), .number("width", "Color Balance", 50, 5, 95, unit: "%"),
             .number("shape", "Wave Amount", 0.35, 0, 1.5)], RGBA(hex: 0xF2959F), RGBA(hex: 0x635FE5)),
        background30("horizonGradient", "Horizon Gradient", 11,
            "Layered atmospheric color bands with a gently moving horizon. Control banding and haze.",
            [.number("scale", "Bands", 6, 1, 24), .number("width", "Haze", 55, 2, 100, unit: "%"),
             .number("shape", "Horizon Curve", 0.25, 0, 1)], RGBA(hex: 0xF5AE79), RGBA(hex: 0x34376C)),
        background30("brickwork", "Brickwork", 12,
            "Staggered masonry with independent mortar width and brick proportions.",
            [.number("scale", "Rows", 10, 2, 40), .number("width", "Mortar", 9, 1, 40, unit: "%"),
             .number("shape", "Brick Aspect", 2.2, 0.6, 4)], RGBA(hex: 0xBF6E63), RGBA(hex: 0x302D39)),
        background30("herringbone", "Herringbone", 13,
            "Interlocking diagonal parquet blocks, shaded by plank direction with fine joints.",
            [.number("scale", "Repeat Count", 8, 2, 36), .number("width", "Joint Width", 7, 1, 35, unit: "%"),
             .number("shape", "Plank Contrast", 35, 5, 90, unit: "%")], RGBA(hex: 0xDBAE7B), RGBA(hex: 0x453444)),
        background30("tartan", "Tartan", 14,
            "Crossing broad cloth bands and fine pinstripes with controllable intersections.",
            [.number("scale", "Repeat Count", 6, 1, 30), .number("width", "Band Width", 38, 8, 80, unit: "%"),
             .number("shape", "Pinstripe Spacing", 0.3, 0.1, 0.48)], RGBA(hex: 0xA5D3BE), RGBA(hex: 0x214D4A)),
        background30("graphPaper", "Graph Paper", 15,
            "Fine ruled squares with stronger major divisions. Minor and major line weights stay readable.",
            [.number("scale", "Major Divisions", 4, 1, 12), .number("width", "Line Width", 9, 1, 40, unit: "%"),
             .number("shape", "Subdivisions", 5, 2, 12, step: 1)], RGBA(hex: 0x8BAFBA), RGBA(hex: 0xEDE6CE)),
        background30("isometricGrid", "Isometric Grid", 16,
            "Three equally spaced line families form a true equilateral drafting grid.",
            [.number("scale", "Divisions", 12, 2, 45), .number("width", "Line Width", 6, 1, 40, unit: "%"),
             .number("shape", "Vertical Stretch", 1, 0.4, 2.5)], RGBA(hex: 0x65C5BF), RGBA(hex: 0x19373E)),
        background30("polarGrid", "Polar Grid", 17,
            "Circular distance rings and angular spokes with independent spoke count.",
            [.number("scale", "Rings", 10, 2, 40), .number("width", "Line Width", 7, 1, 40, unit: "%"),
             .number("shape", "Spokes", 20, 4, 80, step: 1)], RGBA(hex: 0xC2ACEC), RGBA(hex: 0x292140)),
        background30("ringBands", "Ring Bands", 18,
            "Concentric solid elliptical bands with adjustable duty and horizontal stretch.",
            [.number("scale", "Ring Count", 9, 1, 35), .number("width", "Band Width", 45, 5, 95, unit: "%"),
             .number("shape", "Ellipse Stretch", 1.3, 0.4, 3)], RGBA(hex: 0xF9B88F), RGBA(hex: 0x714765)),
        background30("angularGradient", "Angular Gradient", 19,
            "Smooth two-color sweeps around a center, with adjustable repetition and color balance.",
            [.number("scale", "Sweeps", 2, 1, 12, step: 1), .number("width", "Color Balance", 50, 5, 95, unit: "%"),
             .number("shape", "Radial Twist", 0.35, -3, 3)], RGBA(hex: 0xF7B379), RGBA(hex: 0x7546C2)),
        background30("diamondGradient", "Diamond Gradient", 20,
            "Soft nested diamond-shaped color ramps, with independent corner stretching.",
            [.number("scale", "Repeats", 3, 0.5, 15), .number("width", "Color Balance", 50, 5, 95, unit: "%"),
             .number("shape", "Diamond Stretch", 1, 0.3, 3)], RGBA(hex: 0xA7F0D4), RGBA(hex: 0x395783)),
        background30("meshGradient", "Mesh Gradient", 21,
            "Soft moving color islands blend into a continuous mesh, with adjustable island separation.",
            [.number("scale", "Island Scale", 2.5, 0.5, 8), .number("width", "Color Balance", 50, 5, 95, unit: "%"),
             .number("shape", "Separation", 1.2, 0.2, 4)], RGBA(hex: 0xF9AFB2), RGBA(hex: 0x7160BC)),
        background30("opArtTiles", "Op Art Tiles", 22,
            "Alternating quarter-ring tiles form curved optical checker patterns with editable ring spacing.",
            [.number("scale", "Tiles", 5, 1, 20), .number("width", "Band Width", 46, 5, 95, unit: "%"),
             .number("shape", "Rings Per Tile", 4, 1, 12)], RGBA(hex: 0xEEDFC0), RGBA(hex: 0x39324E)),
        background30("stripeInterference", "Stripe Interference", 23,
            "Two crossing stripe fields produce moving moire cells. Control their angular separation.",
            [.number("scale", "Frequency", 18, 3, 60), .number("width", "Stripe Width", 35, 5, 85, unit: "%"),
             .number("shape", "Crossing Angle", 0.24, 0.03, 1.2)], RGBA(hex: 0xEA95B9), RGBA(hex: 0x2F254E)),
        background30("circuitBoard", "Circuit Board", 24,
            "Seeded right-angle traces and solder pads form a connected circuit-like pattern.",
            [.number("scale", "Cell Count", 10, 2, 40), .number("width", "Trace Width", 9, 2, 35, unit: "%"),
             .number("shape", "Seed", 13, 0, 1000, step: 1)], RGBA(hex: 0x90DBA4), RGBA(hex: 0x123E39)),
        background30("binaryPattern", "Binary Pattern", 25,
            "A tiled zero-one display with editable character weight and seeded binary content.",
            [.number("scale", "Columns", 14, 3, 45), .number("width", "Character Weight", 12, 3, 30, unit: "%"),
             .number("shape", "Seed", 8, 0, 1000, step: 1)], RGBA(hex: 0x92E4C2), RGBA(hex: 0x19332D)),
        background30("barcodeField", "Barcode Field", 26,
            "Rows of variable-width bars with editable density, row spacing and reproducible seed.",
            [.number("scale", "Bars", 35, 5, 100), .number("width", "Density", 50, 5, 95, unit: "%"),
             .number("shape", "Rows", 5, 1, 20)], RGBA(hex: 0xE8E3D2), RGBA(hex: 0x363244)),
        background30("windowGrid", "Window Grid", 27,
            "A facade of inset windows with independently illuminated panes and animated occupancy.",
            [.number("scale", "Window Count", 12, 3, 40), .number("width", "Pane Size", 66, 15, 92, unit: "%"),
             .number("shape", "Lit Windows", 55, 5, 95, unit: "%")], RGBA(hex: 0xF3CC86), RGBA(hex: 0x233648)),
        background30("hexMesh", "Hex Mesh", 28,
            "A continuous honeycomb cell mesh with editable edge thickness and cell proportions.",
            [.number("scale", "Cell Count", 9, 2, 35), .number("width", "Edge Width", 10, 1, 45, unit: "%"),
             .number("shape", "Cell Stretch", 1, 0.4, 2.5)], RGBA(hex: 0xE2BB88), RGBA(hex: 0x3B3351)),
        background30("triangleMosaic", "Triangle Mosaic", 29,
            "Split diagonal tiles with seeded tone variation. Adjust inset borders and tonal spread.",
            [.number("scale", "Tile Count", 9, 2, 35), .number("width", "Inset", 7, 1, 35, unit: "%"),
             .number("shape", "Tone Variation", 70, 5, 100, unit: "%")], RGBA(hex: 0x91D2C9), RGBA(hex: 0x385B72)),
        background30("basketWeave", "Basket Weave", 30,
            "Alternating pairs of long strips form a basket weave. Control joint width and strand shade.",
            [.number("scale", "Tile Count", 7, 2, 30), .number("width", "Joint Width", 8, 1, 35, unit: "%"),
             .number("shape", "Strand Shade", 40, 5, 90, unit: "%")], RGBA(hex: 0xD3AA79), RGBA(hex: 0x44344A)),
        background30("stitchPattern", "Stitch Pattern", 31,
            "Alternating diagonal cross stitches, with independently controlled thread width and length.",
            [.number("scale", "Stitch Count", 13, 3, 45), .number("width", "Thread Width", 8, 1, 30, unit: "%"),
             .number("shape", "Stitch Length", 65, 15, 95, unit: "%")], RGBA(hex: 0xECBEAE), RGBA(hex: 0x59425A)),
        background30("orderedDither", "Ordered Dither", 32,
            "A tiled Bayer threshold field, with editable fill density and a traveling threshold wave.",
            [.number("scale", "Matrix Count", 12, 2, 40), .number("width", "Fill Density", 50, 5, 95, unit: "%"),
             .number("shape", "Wave Amount", 25, 0, 75, unit: "%")], RGBA(hex: 0xCEBCEB), RGBA(hex: 0x33314D)),
        background30("rippleInterference", "Ripple Interference", 33,
            "Two wave sources create moving interference fringes, with editable separation and crest width.",
            [.number("scale", "Frequency", 13, 2, 40), .number("width", "Crest Width", 40, 5, 90, unit: "%"),
             .number("shape", "Source Separation", 0.45, 0.05, 1.2)], RGBA(hex: 0x9BDAD6), RGBA(hex: 0x294564)),
        background30("guilloche", "Guilloche", 34,
            "Fine engraved ribbons oscillate across the field, with editable amplitude and line weight.",
            [.number("scale", "Ribbons", 12, 2, 40), .number("width", "Line Width", 8, 1, 35, unit: "%"),
             .number("shape", "Amplitude", 1.4, 0.1, 4)], RGBA(hex: 0xE5C291), RGBA(hex: 0x323C54)),
        background30("waveMesh", "Wave Mesh", 35,
            "Two continuous grid directions bend through each other to form a flowing mesh.",
            [.number("scale", "Grid Count", 9, 2, 35), .number("width", "Line Width", 7, 1, 35, unit: "%"),
             .number("shape", "Wave Amount", 0.7, 0, 2)], RGBA(hex: 0xBFADE8), RGBA(hex: 0x2E3754))
    ]

    private static func background30(_ id: String, _ name: String, _ mode: UInt32, _ summary: String,
                                     _ controls: [ParamDef], _ first: RGBA, _ second: RGBA) -> EffectDefinition {
        EffectDefinition(id: "awi30." + id, name: name, category: .generate, aeMatchNames: [], summary: summary,
            params: controls + [.point("center", "Center", Vec2(0.5, 0.5)), .angle("rotation", "Rotation", 0),
                .number("speed", "Speed", 0.18, -2, 2), .color("color", "Color 1", first), .color("color2", "Color 2", second),
                .number("blend", "Blend", 100, 0, 100, unit: "%"), .toggle("only", "Effect Only", false)],
            stage: .pixels { ctx in
                func definition(_ key: String) -> ParamDef? { EffectRegistry.definition(ctx.effect.typeID)?.params.first { $0.id == key } }
                func value(_ key: String) -> Float {
                    Float(ctx.effect.params[key] != nil ? ctx.num(key) : definition(key)?.defaultValue.number(at: ctx.time) ?? 0)
                }
                func color(_ key: String) -> SIMD4<Float> {
                    (ctx.effect.params[key]?.color(at: ctx.time) ?? definition(key)?.defaultValue.color(at: ctx.time) ?? .white).simd
                }
                let center = ctx.effect.params["center"]?.point(at: ctx.time) ?? Vec2(0.5, 0.5)
                var p = EffectParams()
                p.a = SIMD4(value("scale"), value("width") / 100, value("shape"), Float(ctx.time) * value("speed"))
                p.b = color("color"); p.c = color("color2")
                p.d = SIMD4(Float(center.x), Float(center.y), value("rotation") * .pi / 180, value("blend") / 100)
                p.i = SIMD4(mode, ctx.effect.bool("only") ? 1 : 0, (value("softness") / 100).bitPattern, (value("fade") / 100).bitPattern)
                let out = ctx.temp()
                ctx.gpu.run("fxBackground30", ctx.cb, textures: [ctx.input, out], params: p, grid: out)
                return out
            })
    }
}
