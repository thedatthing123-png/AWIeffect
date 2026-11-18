import Foundation
import Metal
import simd

extension EffectRegistry {
    static let projection42:[EffectDefinition] = [
        projection42("view","Panorama View",0,"Extract a true rectilinear camera view from an equirectangular image; animate yaw, pitch and roll.",110,15,165),
        projection42("rotate","Panorama Reorient",1,"Rotate the spherical image in 3D and write it back in equirectangular coordinates."),
        projection42("cube","Cube Atlas",2,"Convert an equirectangular image into six perspective cube faces in a 3 by 2 atlas."),
        projection42("fromCube","Cube to Panorama",3,"Decode a 3 by 2 cube atlas into a continuous spherical panorama."),
        projection42("octa","Octahedral Map",4,"Pack the whole spherical image into an octahedral square, retaining both hemispheres."),
        projection42("fromOcta","Octahedral to Panorama",5,"Unfold an octahedral environment image into equirectangular space."),
        projection42("dualFish","Dual Fisheye Map",6,"Pack a spherical image into front and rear equidistant 180-degree fisheye discs."),
        projection42("fromDualFish","Dual Fisheye to Panorama",7,"Unwrap two side-by-side equidistant fisheye discs into a full sphere."),
        projection42("cylinder","Cylindrical Panorama",8,"View a panorama on a cylinder, preserving vertical lines without rectilinear edge stretching.",210,30,360),
        projection42("panini","Panini Panorama",9,"Use cylindrical stereographic perspective for wide compositions with straighter verticals and radial lines.",210,30,300),
        projection42("mercator","Mercator Panorama",10,"Remap latitude logarithmically to retain local angular shapes away from the poles.",260,30,360),
        projection42("equalArea","Equal-Area Panorama",11,"Use a cylindrical equal-area map: equal image areas represent equal solid angles.",180,30,360)
    ]
    private static func projection42(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ field:Double?=nil,_ low:Double=0,_ high:Double=0) -> EffectDefinition {
        var controls:[ParamDef]=[]
        if let field { controls.append(.number("field","Horizontal Field of View",field,low,high,unit:"°")) }
        controls += [.angle("yaw","Yaw",20),.angle("pitch","Pitch",12),.angle("roll","Roll",0),
            .choice("sampling","Sampling",["Bilinear","4 Samples"],1),.number("blend","Blend",100,0,100,unit:"%")]
        return EffectDefinition(id:"awi42.projection."+id,name:name,category:.distort,aeMatchNames:[],summary:summary,params:controls,
            stage:.pixels { ctx in
                guard v29(ctx,"blend")>0 else { return ctx.input }
                let extent=ctx.inputPixels ?? ctx.layerPixels ?? SIMD2(Double(ctx.width),Double(ctx.height))
                var p=EffectParams();p.a=SIMD4(Float(extent.x),Float(extent.y),f29(ctx,"field") * .pi/180,pc29(ctx,"blend"))
                p.b=SIMD4(f29(ctx,"yaw") * .pi/180,f29(ctx,"pitch") * .pi/180,f29(ctx,"roll") * .pi/180,0)
                p.i=SIMD4(mode,UInt32(ch29(ctx,"sampling")),0,0)
                let output=ctx.temp();ctx.gpu.run("fxProjection42",ctx.cb,textures:[ctx.input,output],params:p,grid:output);return output
            })
    }
}
