import Foundation
import Metal
import simd

extension EffectRegistry {
    static let batch35: [EffectDefinition] = [
        shape35("arcStroke","Arc Stroke",0,"An open circular stroke with an editable sweep angle.",.number("detail","Sweep",230,10,350,unit:"°")),
        shape35("cornerBrackets","Corner Brackets",1,"Four independent corner brackets around a rectangular target.",.number("detail","Arm Length",28,5,48,unit:"%")),
        shape35("cropMarks","Crop Marks",2,"Print-style crop lines outside an adjustable square boundary.",.number("detail","Mark Gap",10,1,35,unit:"%")),
        shape35("filmPerforations","Film Perforations",3,"A frame border with repeated sprocket perforations on both sides.",.number("detail","Perforations",10,3,30,step:1)),
        shape35("speedFan","Speed Fan",4,"A narrow directional fan of tapered speed streaks with varied lengths.",.number("detail","Streak Count",18,4,60,step:1)),
        shape35("impactSpikes","Impact Spikes",5,"Sharp uneven impact spikes around an empty center, suitable for manga hits.",.number("detail","Spikes",22,5,60,step:1)),
        shape35("rippleRing","Ripple Ring",6,"A continuous wavy ring silhouette, with controllable wave count.",.number("detail","Waves",12,2,40,step:1)),
        shape35("progressRing","Progress Ring",7,"A circular progress stroke with a clear open end and editable completion.",.number("detail","Completion",72,1,99,unit:"%")),
        shape35("pointerArrow","Pointer Arrow",8,"A clean single pointer arrow with an independent arrowhead length.",.number("detail","Head Length",30,10,60,unit:"%")),
        shape35("chevronTrail","Chevron Trail",9,"A row of chevron marks with independent count and stroke thickness.",.number("detail","Chevrons",5,2,12,step:1)),
        shape35("dimensionLines","Dimension Lines",10,"A dimension line with perpendicular end caps and an adjustable center gap.",.number("detail","Center Gap",20,2,60,unit:"%")),
        shape35("speechBubble","Speech Bubble",11,"A rounded speech balloon outline with a triangular tail.",.number("detail","Tail Length",25,5,50,unit:"%")),
        shape35("captionBurst","Caption Burst",12,"A closed manga caption outline with irregular radial lobes.",.number("detail","Lobes",14,5,40,step:1)),
        shape35("lensReticle","Lens Reticle",13,"Four curved targeting brackets and short center ticks.",.number("detail","Bracket Opening",35,5,75,unit:"%")),
        shape35("rulerMarks","Ruler Marks",14,"A ruled line with major and minor measurement ticks.",.number("detail","Ticks",20,5,60,step:1)),
        shape35("spiralStroke","Spiral Stroke",15,"A thin Archimedean spiral stroke with editable turns.",.number("detail","Turns",3,1,8)),
        shape35("lissajousCurve","Lissajous Curve",16,"An implicit harmonic loop with adjacent frequency ratios.",.number("detail","Frequency",3,2,8,step:1)),
        shape35("roundedPanel","Rounded Panel",17,"A rounded rectangular outline with continuous corner control.",.number("detail","Corner Radius",25,1,48,unit:"%")),
        shape35("tornStrip","Torn Strip",18,"A horizontal torn-paper strip silhouette with uneven edges.",.number("detail","Edge Roughness",40,5,90,unit:"%")),
        shape35("sprocketFrame","Sprocket Frame",19,"A perforated rectangular strip frame with repeated short edge slots.",.number("detail","Slot Count",16,4,40,step:1)),
        shape35("crosshairStroke","Crosshair Stroke",20,"Four crosshair arms around a controllable open center.",.number("detail","Center Gap",20,1,70,unit:"%")),
        shape35("registrationMarks","Registration Marks",21,"Offset print registration circles and crosses around the center.",.number("detail","Mark Spacing",30,10,70,unit:"%")),
        shape35("doubleArrow","Double Arrow",22,"A two-headed dimension arrow with adjustable arrowhead length.",.number("detail","Head Length",20,5,40,unit:"%")),
        shape35("angleBracket","Angle Bracket",23,"A technical angle guide with an arc and two radial arms.",.number("detail","Angle",65,10,150,unit:"°")),
        particle35("particlePetals","Falling Petals",24,"Petal-shaped particles flutter and rotate as they fall.",RGBA(hex:0xFFC3D7),RGBA(hex:0xC17FA4)),
        particle35("particleFeathers","Floating Feathers",25,"Long feather silhouettes drift sideways with a soft quill.",RGBA(hex:0xE6E3E2),RGBA(hex:0x9AAAC8)),
        particle35("particleMeteor","Meteor Shower",26,"Directional meteor heads carry tapered source-free streak tails.",RGBA(hex:0xF7DE9A),RGBA(hex:0x9CCAE9)),
        particle35("particlePaper","Paper Shreds",27,"Rectangular paper scraps tumble with varying apparent width.",RGBA(hex:0xF5D3AB),RGBA(hex:0xBE91C9)),
        particle35("particleRibbons","Ribbon Streamers",28,"Curved ribbon strips descend while bending along their length.",RGBA(hex:0xF1B194),RGBA(hex:0x9ABBDD)),
        particle35("particleInk","Ink Specks",29,"Small irregular ink blots drift in a soft uneven field.",RGBA(hex:0x37313F),RGBA(hex:0x67556B)),
        particle35("particleHail","Hail",30,"Small faceted hail particles fall quickly with a short directional trail.",RGBA(hex:0xD4EDF0),RGBA(hex:0x97B9D0)),
        particle35("particleAsh","Ashfall",31,"Dark torn ash flakes flutter with depth-dependent fall rates.",RGBA(hex:0x9D9595),RGBA(hex:0x494654)),
        particle35("particleSeeds","Floating Seeds",32,"Tiny seed heads and short stems float through the image.",RGBA(hex:0xE5DDAD),RGBA(hex:0xB1C9B2)),
        particle35("particleComets","Comet Dust",33,"Soft dust heads have curved tapered tails and independently varying brightness.",RGBA(hex:0xF2C6DB),RGBA(hex:0xA5B9F1)),
        particle35("particleTriangles","Triangle Debris",34,"Small flat triangular fragments drift and tumble.",RGBA(hex:0xE9BF91),RGBA(hex:0xBAA8DE)),
        particle35("particleHollow","Hollow Sparks",35,"Open ring-shaped sparks drift without filling their centers.",RGBA(hex:0xF4D28F),RGBA(hex:0xDDACAA)),
        particle35("particleThreads","Thread Drift",36,"Short flexible thread particles curl as they pass through the frame.",RGBA(hex:0xC8D3E5),RGBA(hex:0xDCC2D8)),
        particle35("particleBokehStreaks","Bokeh Streaks",37,"Soft elongated particles stream in one direction with a bright middle.",RGBA(hex:0xA8D4EA),RGBA(hex:0xE5B2CC)),
        particle35("particleDiamond","Diamond Dust",38,"Fine diamond-shaped glitter varies in size and brightness across the field.",RGBA(hex:0xD6D6F3),RGBA(hex:0xA9D1C7)),
        particle35("particleSpore","Spore Drift",39,"Rounded organic spores drift with a soft translucent center.",RGBA(hex:0xD1DDA8),RGBA(hex:0x93BEB4))
    ]
    private static func shape35(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ detail:ParamDef) -> EffectDefinition {
        let edge:ParamDef = [5,18].contains(mode) ? .number("width","Edge Softness",1,0.5,10,unit:"px") : .number("width","Stroke Width",5,0.5,40,unit:"px")
        return generator35(id,name,mode,summary,[.number("size","Size",110,15,600,unit:"px"),edge,detail],particle:false,color:RGBA(hex:0xE3C5FA),color2:.white)
    }
    private static func particle35(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ first:RGBA,_ second:RGBA) -> EffectDefinition {
        generator35(id,name,mode,summary,[.number("size","Particle Size",4,0.5,25,unit:"px"),.number("count","Density",10,2,35),
            .number("speed","Speed",0.5,-3,3),.number("turbulence","Drift",0.6,0,2),.number("seed","Seed",3,0,1000,step:1)],particle:true,color:first,color2:second)
    }
    private static func generator35(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef],particle:Bool,color:RGBA,color2:RGBA) -> EffectDefinition {
        var parameters=controls
        parameters += [.point("center","Center",Vec2(0.5,0.5)),.angle("angle","Direction",0),.color("color","Color",color)]
        if particle { parameters.append(.color("color2","End Color",color2)) }
        parameters += [.number("blend","Blend",100,0,100,unit:"%"),.toggle("only","Effect Only",false)]
        return EffectDefinition(id:"awi35."+id,name:name,category:.generate,aeMatchNames:[],summary:summary,
            params:parameters,
            stage:.pixels { ctx in
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=EffectParams()
                p.a=particle ? SIMD4(px29(ctx,"size"),f29(ctx,"count"),Float(ctx.time)*f29(ctx,"speed"),f29(ctx,"turbulence"))
                             : SIMD4(px29(ctx,"size"),px29(ctx,"width"),f29(ctx,"detail"),0)
                p.b=col29(ctx,"color"); p.d=col29(ctx,"color2")
                p.c=SIMD4(Float(center.x*Double(ctx.width)),Float(center.y*Double(ctx.height)),f29(ctx,"angle") * .pi/180,pc29(ctx,"blend"))
                p.i=SIMD4(mode,b29(ctx,"only") ? 1:0,particle ? 1:0,Float(v29(ctx,"seed")).bitPattern)
                let output=ctx.temp()
                ctx.gpu.run("fxGenerate35",ctx.cb,textures:[ctx.input,output],params:p,grid:output)
                return output
            })
    }
}
