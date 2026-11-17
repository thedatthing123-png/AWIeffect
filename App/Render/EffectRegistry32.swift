import Foundation
import Metal
import simd

extension EffectRegistry {
    static let batch32: [EffectDefinition] = [
        warp32("liquidCurl", "Curl Flow", 0, "Coupled swirling flow follows the curl of an animated scalar field.", "Flow Complexity", 1.2),
        warp32("liquidGel", "Gel Warp", 1, "Soft gel pockets compress and stretch the image with smoothly changing cell boundaries.", "Pocket Shape", 0.8),
        warp32("liquidTendrils", "Ink Tendrils", 2, "Branching narrow ink-like channels drag the image in coherent streams.", "Branching", 1.3),
        warp32("liquidDrip", "Drip Trails", 3, "Independent rounded drips stretch image columns into downward trails.", "Drip Reach", 1.1),
        warp32("liquidTension", "Surface Tension", 4, "A soft anchored contact patch pulls the image inward and releases in a smooth oscillation.", "Contact Shape", 0.7),
        warp32("liquidWaterline", "Waterline", 5, "A moving wavy waterline refracts only the submerged part of the layer.", "Surface Chop", 0.9),
        warp32("liquidViscous", "Viscous Twist", 6, "An elliptical patch twists as a cohesive fluid pocket, fading smoothly to the untouched image.", "Pocket Stretch", 1.4),
        warp32("liquidLava", "Lava Flow", 7, "Slow nested flow channels create thick molten distortions without a baked texture.", "Channel Depth", 1.5),
        warp32("liquidMercury", "Mercury Fold", 8, "Reflective folded flow creases bend neighboring image regions in opposing directions.", "Fold Sharpness", 1.2),
        warp32("liquidStream", "Stream Warp", 9, "Parallel streams accelerate and bend independently while staying smooth along their length.", "Stream Curl", 0.9),
        warp32("liquidTidal", "Tidal Shear", 10, "Two broad fluid regions slide in opposing directions across a moving curved boundary.", "Boundary Curve", 1.1),
        warp32("liquidSilk", "Silk Flow", 11, "Long interacting wave ribbons create a continuous silky displacement field.", "Ribbon Twist", 0.8),
        warp32("lensStripes", "Lens Stripes", 12, "Continuous cylindrical lens strips alternate between magnification and compression.", "Lens Curvature", 1.0),
        warp32("lensQuilt", "Lens Quilt", 13, "A quilt of rounded square lenses bends each tile smoothly toward its own center.", "Lens Rounding", 1.2),
        warp32("prismCells", "Prism Cells", 14, "Triangular prism cells bend rays toward different faces of the same tile.", "Face Tilt", 0.9),
        warp32("waveSqueeze", "Wave Squeeze", 15, "Successive wave fronts compress horizontal detail while retaining continuous joins.", "Squeeze Bias", 1.1),
        warp32("radialShear", "Radial Shear", 16, "Angular sectors shear tangentially with a smooth radial envelope.", "Sector Spread", 1.4),
        warp32("spiralStretch", "Spiral Stretch", 17, "A spiral-shaped stretch field moves the image along radial and tangential directions.", "Spiral Pitch", 1.2),
        warp32("domeGrid", "Dome Grid", 18, "Small spherical domes lens the picture inside each rounded cell.", "Dome Shape", 0.9),
        warp32("crossWave", "Cross Wave", 19, "Two perpendicular standing waves interact rather than simply displacing along one axis.", "Cross Ratio", 1.3),
        warp32("fanFold", "Fan Fold", 20, "A radial fan of folds bends alternating sectors with a distance-dependent crease.", "Fold Count", 1.6),
        warp32("heartbeatWarp", "Heartbeat Warp", 21, "A localized traveling ring squeezes and releases the image around an editable center.", "Ring Tightness", 1.0),
        warp32("rollingCloth", "Rolling Cloth", 22, "A rolling cloth-like displacement combines a large fold and a smaller cross crease.", "Crease Amount", 0.7),
        warp32("ribbonPull", "Ribbon Pull", 23, "An editable narrow ribbon pulls image detail along its length with smooth falloff.", "Ribbon Taper", 1.2),
        warp32("sinePerspective", "Sine Perspective", 24, "A smooth perspective field varies the apparent horizontal scale down the picture.", "Perspective Curve", 1.0),
        warp32("tangentWarp", "Tangent Warp", 25, "A bounded inverse-tangent lens compresses the middle and stretches the sides.", "Lens Compression", 1.4),
        warp32("moireWarp", "Moire Warp", 26, "Close-frequency wave carriers beat against one another to produce moving displacement cells.", "Frequency Difference", 0.8),
        warp32("heatColumns", "Heat Columns", 27, "Rising narrow heat plumes bend the image more strongly toward the top of each plume.", "Plume Spread", 1.1),
        warp32("windTrails", "Wind Trails", 28, "Directional gusts stretch broad image trails while retaining a smooth cross-flow.", "Gust Variation", 0.9),
        warp32("paperCrumple", "Paper Crumple", 29, "Intersecting smooth fold ridges deform the picture like flexible crumpled paper.", "Fold Complexity", 1.3),
        warp32("vortexPair", "Vortex Pair", 30, "Two oppositely rotating fluid pockets interact around a shared center.", "Vortex Separation", 1.1),
        warp32("stretchLens", "Stretch Lens", 31, "An elliptical soft lens stretches one axis and compresses the other inside its boundary.", "Lens Aspect", 1.5)
    ]

    private static func warp32(_ id: String,_ name: String,_ mode: UInt32,_ summary: String,_ shapeName: String,_ shape: Double) -> EffectDefinition {
        EffectDefinition(id:"awi32."+id,name:name,category:.distort,aeMatchNames:[],summary:summary,
            params:[.number("amount","Displacement",28,-200,200,unit:"px"),
                .number("scale","Pattern Size",120,12,700,unit:"px"),
                .number("shape",shapeName,shape,0.1,3),
                .number("speed","Speed",0.4,-3,3),.point("center","Center",Vec2(0.5,0.5)),
                .angle("angle","Direction",25),.choice("edge","Edges",["Transparent","Repeat","Tile","Mirror"],3),
                .choice("quality","Sampling",["Draft","Fine"],1),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams()
                p.a=SIMD4(px29(ctx,"amount"),px29(ctx,"scale"),f29(ctx,"shape"),Float(ctx.time)*f29(ctx,"speed"))
                p.b=SIMD4(Float(center.x*Double(ctx.width)),Float(center.y*Double(ctx.height)),f29(ctx,"angle") * .pi/180,pc29(ctx,"blend"))
                p.i=SIMD4(mode,UInt32(ch29(ctx,"edge")),UInt32(ch29(ctx,"quality"))+1,0)
                let output=ctx.temp()
                ctx.gpu.run("fxFlow32",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
}
