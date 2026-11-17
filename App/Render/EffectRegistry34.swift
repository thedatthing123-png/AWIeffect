import Foundation
import Metal
import simd

extension EffectRegistry {
    static let cameraTransitions34: [EffectDefinition] = [
        cameraTransition34("curvedWhip","Curved Whip",0,
            "The image follows a curved exit while rotating along the arc. Shutter samples follow the keyed Completion curve.",
            .angle("detail","Arc Bend",65)),
        cameraTransition34("cornerTumble","Corner Tumble",1,
            "A falling card tilts through perspective around the selected pivot, with shutter integration along its keyed movement.",
            .angle("detail","Card Tilt",70)),
        cameraTransition34("spiralPull","Spiral Pull",2,
            "The picture contracts and winds around an editable pivot. Blur follows the actual keyed winding movement.",
            .number("detail","Turns",1.25,-4,4)),
        cameraTransition34("splitFold","Split Fold",3,
            "Two image halves hinge apart in perspective and leave in opposite directions, with motion following the completion keys.",
            .angle("detail","Fold Angle",65))
    ]
    private static func cameraTransition34(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ detail:ParamDef) -> EffectDefinition {
        EffectDefinition(id:"awi34.camera."+id,name:name,category:.transition,aeMatchNames:[],summary:summary,
            params:[.number("completion","Completion",50,0,100,unit:"%"),detail,
                .angle("angle","Direction",0),.point("center","Pivot",Vec2(0.5,0.5)),
                .number("shutter","Shutter Time",16.7,0,100,unit:"ms"),
                .choice("ease","Progress Curve",easeOptions28,0),.number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                let progress=v29(ctx,"completion")/100
                if progress<=0 || v29(ctx,"blend")<=0 { return ctx.input }
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams();p.i.x=mode
                p.a=SIMD4(Float(progress),f29(ctx,"detail"),f29(ctx,"angle")*Float.pi/180,pc29(ctx,"blend"))
                p.b=SIMD4(Float(center.x),Float(center.y),0,0)
                // Eight composition-time samples of the real animation curve. A held
                // completion value stays sharp, even when the shutter is nonzero.
                let animated=ctx.effect.params["completion"]
                for index in 0..<8 {
                    let t=ctx.time+(Double(index)/7-0.5)*v29(ctx,"shutter")/1000
                    let value=min(max((animated?.number(at:t) ?? 50)/100,0),1)
                    let sample=Float(ease28(value,ch29(ctx,"ease")))
                    if index<4 { p.c[index]=sample } else { p.d[index-4]=sample }
                }
                p.i.y=(p.c==SIMD4<Float>(repeating:p.c.x) && p.d==p.c) ? 1:8
                let output=ctx.temp()
                ctx.gpu.run("fxCameraTransition34",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
    static let batch34: [EffectDefinition] = [
        reveal34("bayerDissolve","Bayer Dissolve",0,"Ordered dither coverage removes pixels in a structured threshold progression.","Threshold Bias"),
        reveal34("voronoiBreakup","Voronoi Breakup",1,"Irregular cell centers open at different times, then join into a continuous reveal.","Cell Irregularity"),
        reveal34("spiralPeel","Spiral Peel",2,"A spiral-shaped peel gently twists the source as the boundary travels inward.","Spiral Pitch"),
        reveal34("concentricShutter","Concentric Shutter",3,"Successive circular rings close with staggered angular timing.","Ring Stagger"),
        reveal34("petalClose","Petal Close",4,"A soft multi-lobed petal aperture closes toward an editable center.","Petal Depth"),
        reveal34("tangledWipe","Tangled Wipe",5,"Interlocking curved channels consume the layer in a continuous tangled pattern.","Channel Curl"),
        reveal34("crackReveal","Cracked Glass Reveal",6,"Cell-boundary fractures widen into missing pieces like a cracked pane opening.","Crack Irregularity"),
        reveal34("brickShutter","Brick Shutter",7,"Staggered brick-shaped regions close from alternating edges.","Row Stagger"),
        reveal34("dotCollapse","Dot Collapse",8,"The picture collapses into shrinking dots on an offset lattice.","Dot Stretch"),
        reveal34("ringApertures","Ring Apertures",9,"Many small ring-shaped apertures consume the layer from their local centers.","Ring Offset"),
        reveal34("pixelCascade","Pixel Cascade",10,"Cell columns fall through a cascading threshold pattern with different column delays.","Cascade Delay"),
        reveal34("fractureIris","Fracture Iris",11,"A jagged radial boundary expands along seeded angular fault lines.","Fault Depth"),
        reveal34("filmGateJam","Film Gate Jam",12,"Two uneven gate edges close in while the remaining picture shifts vertically.","Gate Unevenness"),
        reveal34("paperRip","Paper Rip",13,"A broad tear with layered irregular fibers travels across the layer.","Tear Roughness"),
        reveal34("brushStrokeWipe","Brush Stroke Wipe",14,"Parallel strokes with uneven rounded ends cover the image one stroke at a time.","Stroke Stagger"),
        reveal34("circuitDissolve","Circuit Dissolve",15,"Right-angle trace paths spread through the layer before their surrounding cells disappear.","Trace Spread"),
        reveal34("ribbonShutter","Ribbon Shutter",16,"Sinuous ribbon apertures close at different rates, retaining smooth curved borders.","Ribbon Bend"),
        reveal34("cellSpiral","Cell Spiral",17,"Each tile closes along its own spiral path, with timing linked across the grid.","Spiral Turns"),
        reveal34("contourDissolve","Contour Dissolve",18,"Animated-looking topographic bands expand through a continuous terrain threshold.","Contour Depth"),
        reveal34("swarmDissolve","Swarm Dissolve",19,"Offset cell apertures drift apart before disappearing, creating a scattered swarm boundary.","Cell Drift"),
        reveal34("crosshatchReveal","Crosshatch Reveal",20,"Two sets of diagonal hatch marks widen until the whole layer is removed.","Crossing Angle"),
        reveal34("weaveShutter","Weave Shutter",21,"Interlaced horizontal and vertical shutters close with alternating over-under timing.","Weave Stagger"),
        reveal34("chromaticEdgeWipe","Chromatic Edge Wipe",22,"A ragged directional boundary carries source-derived color separation along its moving edge.","Color Separation"),
        reveal34("scanlineShutdown","Scanline Shutdown",23,"Scan groups collapse into a central luminous-looking source strip, then close completely.","Line Stagger")
    ]
    private static func reveal34(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ detailName:String) -> EffectDefinition {
        EffectDefinition(id:"awi34."+id,name:name,category:.transition,aeMatchNames:[],summary:summary,
            params:[.number("completion","Completion",50,0,100,unit:"%"),.number("softness","Edge Softness",3,0,40,unit:"px"),
                .number("count","Pattern Count",8,2,30),.number("detail",detailName,0.8,0.1,3),
                .point("center","Center",Vec2(0.5,0.5)),.angle("angle","Direction",0),
                .toggle("reverse","Reverse Direction",false),.choice("ease","Progress Curve",easeOptions28,0),
                .number("blend","Blend",100,0,100,unit:"%")],
            stage:.pixels { ctx in
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams()
                p.a=SIMD4(Float(ease28(v29(ctx,"completion")/100,ch29(ctx,"ease"))),px29(ctx,"softness"),f29(ctx,"count"),f29(ctx,"detail"))
                p.b=SIMD4(Float(center.x),Float(center.y),f29(ctx,"angle") * .pi/180,pc29(ctx,"blend"))
                p.i=SIMD4(mode,b29(ctx,"reverse") ? 1:0,0,0)
                let output=ctx.temp()
                ctx.gpu.run("fxReveal34",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
}
