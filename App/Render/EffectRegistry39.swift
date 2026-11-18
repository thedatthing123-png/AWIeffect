import Foundation
import Metal
import simd

/// Remaining expansion: data-map operators. RG vectors are centered at 0.5;
/// tangent-space normals use RGB in [0,1]. These are editable processing tools,
/// not look presets, and source coverage is retained unless a matte is requested.
extension EffectRegistry {
    static let data39:[EffectDefinition] = [
        data39("gradient","Gradient Vectors",0,"Convert image luminance derivatives into an RG displacement field.", [.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Vector Strength",3,0.1,12)]),
        data39("curl","Vector Curl",1,"Measure signed local rotation in a centered RG vector map.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Response",2,0.1,12)]),
        data39("divergence","Vector Divergence",2,"Measure local expansion and contraction in an RG vector map.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Response",2,0.1,12)]),
        data39("strain","Vector Strain",3,"Extract directional stretch, compression or shear from the symmetric vector Jacobian.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Response",2,0.1,12),.choice("option","Measure",["Stretch","Compression","Shear"],0)]),
        data39("jacobian","Vector Fold Map",4,"Show the signed area change of a displacement field; negative values identify foldovers.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Displacement Scale",4,0.1,16)]),
        data39("normalize","Vector Normalize",5,"Set vector length while preserving each pixel's direction; zero vectors remain zero.",[.number("gain","Target Length",0.7,0.05,2)]),
        data39("angle","Vector Angle",6,"Map vector direction into editable angular bands, independent of vector magnitude.",[.number("count","Angular Cycles",2,0.1,12),.angle("angle","Phase",20)]),
        data39("length","Vector Length",7,"Extract vector magnitude as a grayscale field with editable gain and bias.",[.number("gain","Gain",0.8,0.1,4),.number("bias","Bias",0,-1,1)]),
        data39("angleSnap","Vector Angle Snap",8,"Quantize vector directions to a chosen angular lattice without quantizing their lengths.",[.number("count","Directions",8,2,32,step:1),.angle("angle","Lattice Phase",15)]),
        data39("lengthSnap","Vector Length Snap",9,"Quantize vector lengths while retaining continuous direction.",[.number("count","Length Levels",5,2,24,step:1),.number("gain","Maximum Length",1,0.1,4)]),
        data39("rotate","Vector Rotate",10,"Rotate RG vector values without rotating or resampling the image grid.",[.angle("angle","Vector Rotation",35)]),
        data39("polarBasis","Vector Polar Basis",11,"Convert vectors between Cartesian axes and the radial/tangential basis around a point.",[.point("center","Basis Center",Vec2(0.5,0.5)),.choice("option","Conversion",["To Radial / Tangent","To Cartesian"],0)]),
        data39("advect","Vector Advection",12,"Transport a vector map along its own field using midpoint integration, instead of a single offset lookup.",[.number("travel","Travel",24,-120,120,unit:"px"),.number("count","Integration Steps",8,1,24,step:1)]),
        data39("trace","Vector Streamlines",13,"Integrate a procedural noise texture along the vector field to expose continuous streamlines.",[.number("travel","Trace Length",40,1,160,unit:"px"),.number("count","Trace Samples",16,4,32,step:1),.number("grain","Noise Size",2,0.5,12,unit:"px"),.number("seed","Seed",3,0,1000,step:1),.number("speed","Noise Speed",1,-4,4)]),
        data39("curvature","Vector Curvature",14,"Measure how the field direction turns along its own flow, rather than measuring curl alone.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Response",4,0.1,20)]),
        data39("laplacian","Vector Laplacian",15,"Extract the spatial second derivative of an RG vector field.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Response",2,0.1,12)]),
        data39("heightNormal","Height to Normal",16,"Build a tangent-space RGB normal map from image luminance or coverage.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Height Strength",5,0.1,24),.choice("option","Height Source",["Luminance","Alpha"],0)]),
        data39("normalStrength","Normal Strength",17,"Strengthen or flatten a normal map's surface slopes, then restore unit-length normals.",[.number("gain","Slope Strength",2,0,8)]),
        data39("normalRotate","Normal Rotate",18,"Rotate encoded 3D normal directions while leaving their pixel positions unchanged.",[.angle("angle","Yaw",30),.angle("pitch","Pitch",20),.angle("roll","Roll",0)]),
        data39("normalFacing","Normal Facing Matte",19,"Select encoded normals facing an editable direction, with a soft angular threshold.",[.angle("angle","Direction",45),.angle("pitch","Elevation",35),.number("threshold","Facing Threshold",0.2,-1,1),.number("softness","Softness",0.2,0.01,1),.choice("option","Output",["Cutout","Matte"],0)]),
        data39("normalLight","Normal Surface Light",20,"Shade an actual RGB normal map with diffuse and specular lighting; this does not derive relief from brightness.",[.angle("angle","Light Direction",-45),.angle("pitch","Light Elevation",40),.number("ambient","Ambient",0.15,0,1),.number("diffuse","Diffuse",0.8,0,3),.number("specular","Specular",0.6,0,4),.number("gloss","Gloss",32,2,128),.color("color","Surface Color",RGBA(0.45,0.7,0.9))]),
        data39("normalCurvature","Normal Curvature",21,"Extract surface curvature from the spatial change of normalized RGB surface normals.",[.number("radius","Derivative Spacing",1,0.5,12,unit:"px"),.number("gain","Response",3,0.1,16)]),
        data39("normalSlope","Normal / Slope",22,"Convert between tangent-space normals and centered RG surface slopes, with protected grazing angles.",[.number("gain","Slope Scale",1,0.1,8),.number("threshold","Minimum Z",0.1,0.02,0.8),.choice("option","Conversion",["Normal to Slope","Slope to Normal"],0)]),
        data39("normalReflection","Normal Reflection",23,"Reflect a chosen environment layer through the encoded normal map.",[.angle("angle","Environment Rotation",20),.number("gain","Reflection Exposure",1,0.1,4)]),
        data39("normalRefraction","Normal Refraction",24,"Refract a chosen layer using encoded surface normals, optical thickness and spectral dispersion.",[.number("ior","Index of Refraction",1.45,1.01,2.5),.number("travel","Optical Thickness",32,1,160,unit:"px"),.number("dispersion","Dispersion",0.04,0,0.3)]),
        data39("normalCombine","Reorient Normals",25,"Combine a detail normal layer with a base normal map using reoriented, whiteout or linear normal blending.",[.number("gain","Detail Strength",1,0,4),.choice("option","Normal Blend",["Reoriented","Whiteout","Linear"],0)])
    ]
    private static func data39(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ controls:[ParamDef]) -> EffectDefinition {
        EffectDefinition(id:"awi39.data."+id,name:name,category:mode==19 ? .keying:.color,aeMatchNames:[],summary:summary,
            params:controls+[.number("blend","Blend",100,0,100,unit:"%")],stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                if mode>=23 && ctx.reference==nil { return ctx.input }
                if mode==25 && v29(ctx,"gain")<=0 { return ctx.input }
                var p=EffectParams()
                p.a=SIMD4(max(0.5,px29(ctx,"radius")),f29(ctx,"gain"),f29(ctx,"bias"),pc29(ctx,"blend"))
                p.b=SIMD4(f29(ctx,"count"),f29(ctx,"angle") * .pi/180,f29(ctx,"pitch") * .pi/180,f29(ctx,"roll") * .pi/180)
                p.c=SIMD4(px29(ctx,"travel"),f29(ctx,"threshold"),f29(ctx,"softness"),max(0.5,px29(ctx,"grain")))
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                p.d=SIMD4(Float(center.x*Double(ctx.width)),Float(center.y*Double(ctx.height)),Float(ctx.time)*f29(ctx,"speed"),f29(ctx,"seed"))
                p.i=SIMD4(mode,UInt32(ch29(ctx,"option")),0,0)
                if mode==20 { p.a.x=f29(ctx,"ambient");p.a.y=f29(ctx,"diffuse");p.a.z=f29(ctx,"specular");p.b.x=f29(ctx,"gloss");p.c=col29(ctx,"color") }
                if mode==24 { p.a.y=f29(ctx,"ior");p.a.z=f29(ctx,"dispersion") }
                let output=ctx.temp()
                ctx.gpu.run("fxData39",ctx.cb,textures:[ctx.input,output,ctx.reference ?? ctx.input],params:p,grid:output)
                return output
            })
    }
}
