import Foundation
import Metal
import simd

struct SurfaceParams40 {
    var a=SIMD4<Float>(repeating:0),b=SIMD4<Float>(repeating:0),c=SIMD4<Float>(repeating:0)
    var d=SIMD4<Float>(repeating:0),e=SIMD4<Float>(repeating:0),f=SIMD4<Float>(repeating:0)
    var g=SIMD4<Float>(repeating:0)
    var i=SIMD4<UInt32>(repeating:0)
}

extension EffectRegistry {
    static let surfaces40:[EffectDefinition] = [
        surface40("bend","Bend Surface",0,"Map the image onto a cylindrical sheet with actual perspective and surface lighting.",.angle("amount","Bend Angle",65),[]),
        surface40("twist","Twist Surface",1,"Twist the textured sheet into a helicoid; folds are depth tested rather than painted over one another.",.angle("amount","Twist Angle",100),[]),
        surface40("dome","Dome Surface",2,"Lift the image through a smooth elliptical dome.",height40(22),[.number("frequency","Dome Width",0.7,0.2,2),.number("shape","Aspect",1,0.3,3)]),
        surface40("saddle","Saddle Surface",3,"Bend opposite corners in opposite depth directions through a saddle surface.",height40(30),[]),
        surface40("cone","Cone Wrap",4,"Wrap the source around a tapered cone instead of a constant-radius cylinder.",.angle("amount","Wrap Angle",220),[.number("frequency","Taper",0.5,-0.8,0.8)]),
        surface40("scroll","Scroll Roll",5,"Roll the image along a widening spiral cross section, retaining depth-ordered overlapping turns.",.angle("amount","Roll Angle",350),[.number("frequency","Roll Pitch",0.2,0.02,0.8)]),
        surface40("pleats","Pleated Surface",6,"Fold the textured sheet into connected accordion pleats with geometric depth.",.angle("amount","Fold Angle",40),[.number("frequency","Pleats",6,1,16,step:1)]),
        surface40("ripples","Ripple Surface",7,"Lift the image on damped circular waves without replacing it with a generated water texture.",height40(12),[.number("frequency","Rings",4,0.5,10),.number("shape","Falloff",1,0.1,6)],moving:true),
        surface40("flag","Flag Surface",8,"A pinned edge holds the image while traveling folds lift its free edge.",height40(14),[.number("frequency","Waves",2,0.5,8),.number("shape","Cross Flow",0.3,0,1)],moving:true),
        surface40("drape","Draped Surface",9,"Sag the picture along a catenary-shaped cross section.",height40(25),[.number("frequency","Sag Curve",2,0.5,6)]),
        surface40("mobius","Mobius Ribbon",10,"Wrap the actual source image onto a half-twisted ribbon; this is a textured surface, not a demo solid.",.angle("amount","Ribbon Twist",180),[.number("frequency","Ring Radius",0.8,0.3,1.5),.number("shape","Ribbon Width",0.35,0.1,0.7)]),
        surface40("sBend","S Bend Surface",11,"Bend the two sides of the image in opposite depth directions through a continuous S profile.",.angle("amount","Bend Angle",100),[]),
        surface40("hinges","Hinged Panels",12,"Split the picture into separately hinged textured panels with real overlap ordering.",.angle("amount","Panel Angle",45),[.number("frequency","Panels",4,1,12,step:1),.number("shape","Stagger",0.5,0,1)]),
        surface40("crumple","Crumpled Surface",13,"Continuous seeded folds displace the image mesh in depth, with independent broad and fine creases.",height40(16),[.number("frequency","Fold Scale",4,1,12),.number("shape","Fine Creases",0.5,0,1),.number("seed","Seed",3,0,1000,step:1)],moving:true),
        surface40("weave","Woven Image",14,"Interlace strips cut from the picture, with raised over-under crossings and editable gaps.",height40(12),[.number("frequency","Ribbons",6,2,16,step:1),.number("shape","Ribbon Width",0.65,0.2,0.9)]),
        surface40("gerstner","Gerstner Surface",15,"Traveling trochoidal waves move source points sideways as well as in depth.",height40(10),[.number("frequency","Wave Count",3,0.5,8),.number("shape","Steepness",0.6,0,1)],moving:true),
        surface40("spiralSteps","Spiral Steps",16,"Unwrap the source around a staircase of separated radial panels.",height40(30),[.number("frequency","Steps",8,2,24,step:1),.number("shape","Inner Radius",0.1,0,0.5)]),
        surface40("facets","Faceted Surface",17,"Lift a seeded triangular image mesh and light each physical facet separately.",height40(18),[.number("frequency","Facets",10,2,28,step:1),.number("seed","Seed",3,0,1000,step:1)]),
        surface40("corners","Corner Drape",18,"Control four corner heights and an independent center sag while preserving the source texture.",height40(25),[.number("frequency","Center Sag",0.5,0,1),.number("topLeft","Top Left",-0.5,-1,1),.number("topRight","Top Right",0.5,-1,1),.number("bottomLeft","Bottom Left",0.8,-1,1),.number("bottomRight","Bottom Right",-0.8,-1,1)]),
        surface40("bubbles","Bubble Surface",19,"Lift tiled domes from the image itself, retaining the continuous texture between cells.",height40(12),[.number("frequency","Bubble Grid",4,1,12,step:1),.number("shape","Roundness",0.8,0.2,2)]),
        surface40("relief","Image Relief",20,"Use source brightness as actual mesh height, including perspective, occlusion and surface lighting.",height40(25),[.number("frequency","Height Smoothing",2,0,12,unit:"px"),.number("shape","Height Gamma",1,0.2,3)])
    ]
    private static func height40(_ value:Double) -> ParamDef { .number("amount","Depth",value,-80,80,unit:"%") }
    private static func surface40(_ id:String,_ name:String,_ mode:UInt32,_ summary:String,_ amount:ParamDef,_ controls:[ParamDef],moving:Bool=false) -> EffectDefinition {
        var parameters=[amount]+controls
        if moving { parameters += [.number("evolution","Evolution",0,-10,10),.number("speed","Evolution Speed",0.7,-3,3)] }
        parameters += [.point("center","Surface Center",Vec2(0.5,0.5)),.angle("yaw","View Yaw",-12),.angle("pitch","View Pitch",16),.angle("roll","View Roll",0),
            .number("camera","Perspective Distance",160,60,600,unit:"%"),.number("lighting","Surface Lighting",65,0,100,unit:"%"),
            .angle("light","Light Direction",-45),.angle("lightElevation","Light Elevation",45)]
        if ![12,17].contains(mode) { parameters.append(.choice("quality","Mesh Quality",["Draft","Fine"],1)) }
        parameters.append(.number("blend","Blend",100,0,100,unit:"%"))
        let angular:Bool
        if case .angle=amount.kind { angular=true } else { angular=false }
        return EffectDefinition(id:"awi40.surface."+id,name:name,category:.distort,aeMatchNames:[],summary:summary,params:parameters,
            expandedMargin:{ e,t,size in
                let side=max(size.x,size.y),value=e.params["amount"]?.number(at:t) ?? amount.defaultValue.number(at:t)
                let amplitude=angular ? side*min(1,abs(value)/180):side*abs(value)/100
                return min(side*0.5,side*0.18+amplitude*0.5)
            },stage:.pixels { ctx in
                if v29(ctx,"blend")<=0 { return ctx.input }
                let canvas=ctx.layerPixels ?? SIMD2(Double(ctx.width),Double(ctx.height)),side=max(1,min(canvas.x,canvas.y))
                let center=ctx.effect.params["center"]?.point(at:ctx.time) ?? Vec2(0.5,0.5)
                var p=SurfaceParams40()
                p.a=SIMD4(Float(angular ? v29(ctx,"amount")*Double.pi/180:v29(ctx,"amount")*side/100),f29(ctx,"frequency"),f29(ctx,"shape"),pc29(ctx,"blend"))
                p.b=SIMD4(Float(canvas.x),Float(canvas.y),Float(ctx.width),Float(ctx.height))
                let extent=ctx.inputPixels ?? canvas
                p.g=SIMD4(Float(extent.x),Float(extent.y),0,0)
                p.c=SIMD4(Float(Double(ctx.width)*0.5+(center.x-0.5)*canvas.x),Float(Double(ctx.height)*0.5+(center.y-0.5)*canvas.y),Float(side*v29(ctx,"camera")/100),0)
                p.d=SIMD4(f29(ctx,"yaw") * .pi/180,f29(ctx,"pitch") * .pi/180,f29(ctx,"roll") * .pi/180,f29(ctx,"evolution")+Float(ctx.time)*f29(ctx,"speed"))
                p.e=SIMD4(f29(ctx,"light") * .pi/180,f29(ctx,"lightElevation") * .pi/180,pc29(ctx,"lighting"),f29(ctx,"seed"))
                p.f=SIMD4(f29(ctx,"topLeft"),f29(ctx,"topRight"),f29(ctx,"bottomLeft"),f29(ctx,"bottomRight"))
                let fine=ch29(ctx,"quality")==1
                var columns=fine ? 64:32,rows=columns
                if mode==12 { columns=max(1,min(12,Int(v29(ctx,"frequency").rounded())));rows=columns }
                if mode==16 { columns=max(2,min(24,Int(v29(ctx,"frequency").rounded())));rows=fine ? 32:16 }
                if mode==17 { columns=max(2,min(28,Int(v29(ctx,"frequency").rounded())));rows=columns }
                if mode==14 { columns=min(128,max(2,Int(v29(ctx,"frequency").rounded()))*(fine ? 8:4));rows=columns }
                if mode==19 { columns=min(96,max(1,Int(v29(ctx,"frequency").rounded()))*(fine ? 8:4));rows=columns }
                p.i=SIMD4(mode,UInt32(columns),UInt32(rows),0)
                let height=mode==20 ? ctx.gpu.gaussian(ctx,input:ctx.input,sigma:v29(ctx,"frequency")*ctx.unit):ctx.input
                guard let surface=SurfaceGPU40.encode(ctx,params:p,height:height) else { return ctx.input }
                if v29(ctx,"blend")>=100 { return surface }
                var mix=EffectParams();mix.a.x=pc29(ctx,"blend")
                let output=ctx.temp();ctx.gpu.run("fxTimeComposite33",ctx.cb,textures:[ctx.input,output,surface],params:mix,grid:output)
                return output
            })
    }
}

/// GPU-only regular meshes. Pipeline/depth resources are cached; geometry is
/// generated by vertex_id, so no per-frame CPU mesh arrays or buffers are built.
enum SurfaceGPU40 {
    private struct Pipeline { var render:MTLRenderPipelineState;var depth:MTLDepthStencilState }
    private struct DepthKey:Hashable { var device:UInt64;var width:Int;var height:Int }
    private struct DepthEntry { var texture:MTLTexture;var serial:UInt64 }
    private static let lock=NSLock()
    private static var pipelines:[UInt64:Pipeline]=[:],depths:[DepthKey:DepthEntry]=[:]
    private static var serial:UInt64=0
    private static func resources(_ device:MTLDevice,width:Int,height:Int) -> (Pipeline,MTLTexture)? {
        lock.lock();defer{lock.unlock()};serial &+= 1
        let pipeline:Pipeline
        if let saved=pipelines[device.registryID] { pipeline=saved }
        else {
            guard let library=device.makeDefaultLibrary(),let vertex=library.makeFunction(name:"surfaceVertex40"),let fragment=library.makeFunction(name:"surfaceFragment40") else { return nil }
            let descriptor=MTLRenderPipelineDescriptor();descriptor.vertexFunction=vertex;descriptor.fragmentFunction=fragment
            descriptor.colorAttachments[0].pixelFormat = .rgba16Float;descriptor.depthAttachmentPixelFormat = .depth32Float
            descriptor.colorAttachments[0].isBlendingEnabled=true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one;descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one;descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            let depth=MTLDepthStencilDescriptor();depth.depthCompareFunction = .less;depth.isDepthWriteEnabled=true
            guard let render=try? device.makeRenderPipelineState(descriptor:descriptor),let state=device.makeDepthStencilState(descriptor:depth) else { return nil }
            pipeline=Pipeline(render:render,depth:state);pipelines[device.registryID]=pipeline
        }
        let key=DepthKey(device:device.registryID,width:width,height:height)
        let texture:MTLTexture
        if let saved=depths[key] { texture=saved.texture }
        else {
            let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:width,height:height,mipmapped:false)
            descriptor.storageMode = .private;descriptor.usage = .renderTarget
            guard let made=device.makeTexture(descriptor:descriptor) else { return nil };texture=made
        }
        depths[key]=DepthEntry(texture:texture,serial:serial)
        var cost=depths.values.reduce(0){$0+$1.texture.width*$1.texture.height*4}
        while depths.count>4 || cost>48*1024*1024 {
            guard let oldest=depths.filter({$0.key != key}).min(by:{$0.value.serial<$1.value.serial}) else { break }
            cost-=oldest.value.texture.width*oldest.value.texture.height*4;depths[oldest.key]=nil
        }
        return (pipeline,texture)
    }
    static func encode(_ ctx:EffectContext,params:SurfaceParams40,height:MTLTexture) -> MTLTexture? {
        let output=ctx.temp()
        guard let (pipeline,depth)=resources(ctx.gpu.device,width:output.width,height:output.height) else { return nil }
        let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=output
        pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,0)
        pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare;pass.depthAttachment.clearDepth=1
        guard let encoder=ctx.cb.makeRenderCommandEncoder(descriptor:pass) else { return nil }
        encoder.setRenderPipelineState(pipeline.render);encoder.setDepthStencilState(pipeline.depth);encoder.setCullMode(.none)
        encoder.setViewport(MTLViewport(originX:0,originY:0,width:Double(output.width),height:Double(output.height),znear:0,zfar:1))
        var p=params;p.b.z=Float(output.width);p.b.w=Float(output.height)
        encoder.setVertexBytes(&p,length:MemoryLayout<SurfaceParams40>.stride,index:0)
        encoder.setFragmentBytes(&p,length:MemoryLayout<SurfaceParams40>.stride,index:0)
        encoder.setVertexTexture(height,index:0);encoder.setFragmentTexture(ctx.input,index:0)
        encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:Int(p.i.y*p.i.z)*6,instanceCount:p.i.x==14 ? 2:1)
        encoder.endEncoding();return output
    }
}
