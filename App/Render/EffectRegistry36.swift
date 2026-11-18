import Foundation
import Metal
import simd

extension EffectRegistry {
    // Source-derived optical structures, not generated flare overlays. The sampling pass
    // reshapes thresholded emission; the shared photographic compositor preserves HDR hue.
    static let lights36: [EffectDefinition] = [
        optical36("annularGlow", "Annular Glow", 0,
            "Highlights spread into hollow halos; ring radius and thickness are independent.",
            [.number("radius","Ring Radius",24,1,240,unit:"px"),
             .number("width","Ring Thickness",3,0.5,40,unit:"px")]),
        optical36("lensGhosts", "Lens Ghosts", 1,
            "Reflected copies of the actual highlights spread across the optical center, with chromatic separation.",
            [.number("spacing","Ghost Spacing",65,10,180,unit:"%"),
             .number("count","Ghost Count",4,1,8,step:1),
             .number("dispersion","Dispersion",4,0,30,unit:"px"),
             .point("center","Optical Center",Vec2(0.5,0.5))]),
        optical36("spiralLight", "Spiral Light", 2,
            "Highlight trails wind around a center while receding inward; winding and contraction stay independent.",
            [.angle("angle","Winding",55),.number("pull","Contraction",30,0,90,unit:"%"),
             .point("center","Spiral Center",Vec2(0.5,0.5))]),
        optical36("splitStreak", "Split Streak", 3,
            "Two differently colored highlight streaks diverge in opposite directions, with a separately softened core.",
            [.number("length","Streak Length",80,1,400,unit:"px"),.angle("angle","Direction",0),
             .number("split","Separation",8,0,100,unit:"px"),
             .color("color","First Streak",RGBA(0.2,0.65,1)),
             .color("color2","Second Streak",RGBA(1,0.25,0.1))]),
        optical36("apertureReflection", "Aperture Reflection", 4,
            "A polygonal reflection of source highlights follows the selected aperture, instead of drawing a canned star flare.",
            [.number("radius","Reflection Radius",32,1,240,unit:"px"),
             .number("sides","Aperture Blades",6,3,12,step:1),.angle("angle","Aperture Rotation",15)]),
        optical36("spectralHalo", "Spectral Halo", 5,
            "Red, green and blue highlight halos spread at different radii, with a continuous dispersion control.",
            [.number("radius","Halo Radius",20,1,240,unit:"px"),
             .number("dispersion","Dispersion",45,0,100,unit:"%"),
             .number("width","Halo Thickness",2,0.5,40,unit:"px")])
    ]

    private static func optical36(_ id: String, _ name: String, _ mode: UInt32,
                                  _ summary: String, _ controls: [ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi36.light."+id,name:name,category:.color,aeMatchNames:[],summary:summary,
            params:controls + [.number("threshold","Highlight Threshold",55,0,100,unit:"%"),
                .number("softness","Source Softness",2,0,24,unit:"px"),
                .number("intensity","Intensity",1.2,0,8),
                .number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)],
            margin:{ effect,time in
                func value(_ key:String) -> Double {
                    effect.params[key]?.number(at:time) ?? controls.first(where:{$0.id==key})?.defaultValue.number(at:time) ?? 0
                }
                let reach=max(value("radius"),value("length"))
                let width=value("width")
                let softness=effect.params["softness"]?.number(at:time) ?? 2
                return reach*1.65+3*(width+softness)
            },stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 || v29(ctx,"intensity")<=0 { return ctx.input }
                let emission=lightPrep25(ctx,threshold:v29(ctx,"threshold")/100)
                let width=v29(ctx,"width")+v29(ctx,"softness")
                let softened=ctx.gpu.gaussian(ctx,input:emission,sigma:width*ctx.unit)
                var p=EffectParams();p.i.x=mode
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                p.b=SIMD4(Float(center.x*Double(ctx.width)),Float(center.y*Double(ctx.height)),0,0)
                switch mode {
                case 0: p.a=SIMD4(px29(ctx,"radius"),0,0,0)
                case 1:
                    p.a=SIMD4(pc29(ctx,"spacing"),px29(ctx,"dispersion"),0,0)
                    p.i.y=UInt32(v29(ctx,"count"))
                case 2: p.a=SIMD4(f29(ctx,"angle")*Float.pi/180,pc29(ctx,"pull"),0,0)
                case 3:
                    p.a=SIMD4(px29(ctx,"length"),f29(ctx,"angle")*Float.pi/180,px29(ctx,"split"),0)
                    p.c=col29(ctx,"color");p.d=col29(ctx,"color2")
                case 4:
                    p.a=SIMD4(px29(ctx,"radius"),f29(ctx,"angle")*Float.pi/180,0,0)
                    p.i.y=UInt32(v29(ctx,"sides"))
                default: p.a=SIMD4(px29(ctx,"radius"),pc29(ctx,"dispersion"),0,0)
                }
                let shaped=ctx.temp()
                ctx.gpu.run("fxOptical36",ctx.cb,textures:[softened,shaped],params:p,grid:shaped)
                return lightComp25(ctx,base:ctx.input,glow:shaped,
                    intensity:v29(ctx,"intensity")*v29(ctx,"blend")/100,
                    composite:b29(ctx,"only") ? .glowOnly:.over)
            })
    }
    static let batch36: [EffectDefinition] = [
        EffectDefinition(id:"awi36.fractalRidges",name:"Fractal Ridges",category:.generate,aeMatchNames:[],
            summary:"Coupled ridged multifractal with the supplied reference's scale, signed stretch, seed and octave behavior.",
            params:[.number("evolution","Evolution",0,-50,50),.number("scale","Scale",1,0.01,50),
                .number("stretch","Stretch",0,-50,50),.number("intensity","Intensity",1,0.1,1.5),
                .number("seed","Seed",0,0,5),.number("octaves","Octaves",6,1,9,step:1),
                .point("offset","Offset",Vec2(0.5,0.5)),.point("parallax","Parallax",Vec2(0.5,0.5)),
                .color("color","Color 1",.black),.color("color2","Color 2",.white),
                .number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)],
            stage:.pixels { ctx in
                let offset=ctx.effect.params["offset"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                let parallax=ctx.effect.params["parallax"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams()
                p.a=SIMD4(f29(ctx,"scale"),f29(ctx,"stretch"),f29(ctx,"intensity"),f29(ctx,"seed"))
                p.b=col29(ctx,"color"); p.c=col29(ctx,"color2")
                p.d=SIMD4(f29(ctx,"evolution"),Float(-(offset.x-0.5)*2),Float((offset.y-0.5)*2),pc29(ctx,"blend"))
                p.i=SIMD4(b29(ctx,"only") ? 256:0,UInt32(v29(ctx,"octaves")),Float(-(parallax.x-0.5)*2).bitPattern,Float((parallax.y-0.5)*2).bitPattern)
                let output=ctx.temp()
                ctx.gpu.run("fxField36",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            }),
        field36("billowNoise","Billow Noise",1,"Rounded folded noise creates soft puff-like forms.","Billow Detail"),
        field36("hybridNoise","Hybrid Noise",2,"Later noise octaves modulate earlier amplitudes for connected mountain-like structure.","Coupling"),
        field36("multiplicativeNoise","Multiplicative Noise",3,"Noise octaves multiply rather than add, producing deep separated cavities.","Cavity Depth"),
        field36("domainWarpField","Domain Warp Field",4,"One noise field bends the coordinates of another, forming flowing nested contours.","Warp Depth"),
        field36("curlField","Curl Field",5,"The magnitude of a curl-like field forms continuous directional flow filaments.","Flow Curl"),
        field36("cellularDistance","Cellular Distance",6,"Distance to a moving cell seed produces rounded individual basins.","Cell Curvature"),
        field36("cellularSecond","Second-Cell Field",7,"Distance to the second-nearest seed reveals broad linked cellular structure.","Cell Contrast"),
        field36("cellBoundaryField","Cell Boundary Field",8,"The distance gap between nearest seeds isolates thin irregular cell boundaries.","Boundary Width"),
        field36("manhattanCells","Manhattan Cells",9,"Taxicab distance produces angular diamond-shaped cellular regions.","Cell Sharpness"),
        field36("squareCells","Square Cells",10,"Maximum-axis distance produces square cellular basins with irregular centers.","Basin Shape"),
        field36("causticField","Caustic Field",11,"Crossing folded waves create bright water-like caustic networks.","Caustic Tightness"),
        field36("marbleVeins","Marble Veins",12,"Turbulence bends a continuous stone-like vein structure.","Vein Distortion"),
        field36("woodRings","Wood Rings",13,"Irregular concentric growth rings with fine turbulence in their boundaries.","Growth Detail"),
        field36("flowFibers","Flow Fibers",14,"Long fibers follow a continuous low-frequency flow field.","Fiber Curl"),
        field36("moltenChannels","Molten Channels",15,"Thick bright channels follow nested ridge intersections.","Channel Thickness"),
        field36("wispyField","Wispy Field",16,"Anisotropic turbulence stretches into thin smoke-like wisps.","Wisp Stretch"),
        field36("cloudLayers","Cloud Layers",17,"Several differently scaled cloud densities overlap without a flat noise overlay.","Layer Depth"),
        field36("stormFront","Storm Front",18,"A rolling density front separates open sky-like regions from thick turbulence.","Front Contrast"),
        field36("fireTongues","Fire Tongues",19,"Tapered upward-flowing noise tongues create a stylized fire density field.","Tongue Length"),
        field36("flameCells","Flame Cells",20,"Irregular elongated cells produce a cellular flame pattern.","Cell Stretch"),
        field36("plasmaSheets","Plasma Sheets",21,"Interacting curved wave sheets generate smooth high-energy bands.","Sheet Bend"),
        field36("electricFilaments","Electric Filaments",22,"Narrow distorted zero-crossings form branching electric-looking filaments.","Filament Width"),
        field36("sparkField","Spark Field",23,"A sparse field of soft local peaks creates isolated procedural spark cores.","Spark Density"),
        field36("reactionPattern","Reaction Pattern",24,"Coupled periodic fields create organic reaction-like stripes without claiming a fluid simulation.","Pattern Coupling"),
        field36("craterTerrain","Crater Terrain",25,"Cell-distance rings create overlapping crater rims and shallow basins.","Crater Rim"),
        field36("mountainField","Mountain Field",26,"Directional ridged turbulence creates long connected mountain chains.","Ridge Coupling"),
        field36("sandRipples","Sand Ripples",27,"Fine ripples bend across a broad low-frequency terrain field.","Ripple Bend"),
        field36("brushedFibers","Brushed Fibers",28,"Fine directional fibers have independent long and short grain structure.","Fiber Contrast"),
        field36("frostCrystals","Frost Crystals",29,"Angular cellular branches combine with fine noisy crystal edges.","Crystal Spread"),
        field36("veinNetwork","Vein Network",30,"A distorted cell-boundary field forms a connected vein-like network.","Vein Warp"),
        field36("directionalNoise","Directional Noise",31,"Intersecting anisotropic noise gradients form directional streaked structure.","Directionality"),
        field36("gaborField","Gabor Field",32,"Local Gaussian-windowed wave packets produce an oriented grain field.","Packet Frequency"),
        field36("waveletField","Wavelet Field",33,"Several finite-frequency wave layers produce a bounded oscillating field.","Layer Frequency"),
        field36("mosaicTurbulence","Mosaic Turbulence",34,"Independent small turbulence packets meet at visible cell boundaries.","Packet Contrast"),
        field36("turbulentRings","Turbulent Rings",35,"Noisy radial wave fronts fold into broken nested rings.","Ring Turbulence")
    ]
    private static func field36(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ detailName:String) -> EffectDefinition {
        EffectDefinition(id:"awi36."+id,name:name,category:.generate,aeMatchNames:[],summary:summary,
            params:[.number("size","Pattern Size",100,8,600,unit:"px"),.number("detail",detailName,1.2,0.1,4),
                .number("evolution","Evolution",0,-50,50),.number("speed","Evolution Speed",0.3,-3,3),.number("seed","Seed",3,0,1000),
                .point("center","Center",Vec2(0.5,0.5)),.angle("angle","Direction",0),
                .color("color","Low Color",RGBA(hex:0x172C3A)),.color("color2","High Color",RGBA(hex:0xD1C5E9)),
                .number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)],
            stage:.pixels { ctx in
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams()
                p.a=SIMD4(px29(ctx,"size"),f29(ctx,"detail"),f29(ctx,"evolution")+Float(ctx.time)*f29(ctx,"speed"),f29(ctx,"seed"))
                p.b=col29(ctx,"color"); p.c=col29(ctx,"color2")
                p.d=SIMD4(Float(center.x*Double(ctx.width)),Float(center.y*Double(ctx.height)),f29(ctx,"angle") * .pi/180,pc29(ctx,"blend"))
                p.i.x=mode+(b29(ctx,"only") ? 256:0)
                let output=ctx.temp()
                ctx.gpu.run("fxField36",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
}
