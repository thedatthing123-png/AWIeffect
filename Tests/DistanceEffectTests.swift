import XCTest
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class DistanceEffectTests:XCTestCase {
    func testCatalogPlacementAndDistinctDefinitions() {
        XCTAssertEqual(EffectRegistry.distance41.count,10)
        XCTAssertEqual(Set(EffectRegistry.distance41.map(\.id)).count,10)
        for definition in EffectRegistry.distance41 {
            let expected:EffectSection
            switch definition.id {
            case "awi41.contour.map","awi41.contour.vectors":expected = .data
            case "awi41.contour.extend","awi41.contour.ridges":expected = .keying
            case "awi41.contour.light":expected = .glow
            case "awi41.contour.bands":expected = .stylize
            default:expected = .distort
            }
            XCTAssertEqual(EffectSection.of(definition),expected,definition.name)
        }
    }
    private static let imageURL=FileManager.default.temporaryDirectory.appendingPathComponent("distance-fixture-\(UUID().uuidString).png")
    private static func prepareImage() {
        if FileManager.default.fileExists(atPath:imageURL.path) { return }
        var bytes=[UInt8](repeating:0,count:160*160*4)
        for y in 0..<160 { for x in 0..<160 {
            let u=Double(x)+0.5,v=Double(y)+0.5
            let outer=min((hypot((u-65)/1.1,v-75)-48),hypot(u-112,v-108)-25)
            let hole=13-hypot(u-62,v-72)
            let signed=max(outer,hole),alpha=min(1,max(0,0.5-signed/5))
            let colors=[0.5+0.4*sin(u*0.11+v*0.03),0.5+0.4*cos(v*0.13),0.3+0.6*u/160]
            let index=(y*160+x)*4
            for channel in 0..<3 { bytes[index+channel]=UInt8((colors[channel]*alpha*255).rounded()) }
            bytes[index+3]=UInt8((alpha*255).rounded())
        }}
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),let image=CGImage(width:160,height:160,bitsPerComponent:8,bitsPerPixel:32,
            bytesPerRow:640,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
            provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent),
            let destination=CGImageDestinationCreateWithURL(imageURL as CFURL,UTType.png.identifier as CFString,1,nil) else {
            XCTFail("Could not create distance fixture");return
        }
        CGImageDestinationAddImage(destination,image,nil);XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    static func scene(_ effect:EffectInstance?,onAdjustment:Bool=false) -> Project {
        prepareImage()
        var project=Project.new(name:"Contour distances",width:160,height:160,fps:30,duration:2,background:RGBA(0,0,0,0))
        var layer=project.makeLayer(name:"Cutout with a hole",content:.image(fileName:imageURL.path,pixelWidth:160,pixelHeight:160),size:Vec2(160,160))
        if let effect,!onAdjustment { layer.effects=[effect] }
        project.layers=[layer]
        if let effect,onAdjustment {
            var adjustment=project.makeLayer(name:"Contour processing",content:.adjustment,size:Vec2(160,160))
            adjustment.effects=[effect];project.layers.insert(adjustment,at:0)
        }
        return project
    }
    private func render(_ effect:EffectInstance?,adjustment:Bool=false) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:Self.scene(effect,onAdjustment:adjustment),time:0.4,preserveAlpha:true,
            mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    func testDefaultsMissingParametersAndBlendBypass() throws {
        for adjustment in [false,true] {
            let original=try render(nil,adjustment:adjustment)
            for definition in EffectRegistry.distance41 {
                var effect=definition.makeInstance()
                let actual=try render(effect,adjustment:adjustment)
                XCTAssertGreaterThan(zip(original,actual).filter{abs(Int($0.0)-Int($0.1))>2}.count,50,definition.name)
                XCTAssertEqual(actual,try render(EffectInstance(typeID:definition.id,params:[:]),adjustment:adjustment),definition.name)
                effect.params["blend"] = .number(Animated(0))
                XCTAssertEqual(original,try render(effect,adjustment:adjustment),definition.name)
            }
        }
    }

    /// This independent oracle enumerates every threshold crossing and searches
    /// every seed, rather than simulating the GPU's jump propagation schedule.
    private func seeds(_ alpha:[Float],width:Int,height:Int,threshold:Float) -> [SIMD2<Float>] {
        let neighbors=[(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,-1),(-1,1),(1,1)]
        var result=[SIMD2<Float>]()
        for y in 0..<height { for x in 0..<width {
            let value=alpha[y*width+x],point=SIMD2(Float(x)+0.5,Float(y)+0.5)
            var best:SIMD2<Float>?,bestDistance=Float.greatestFiniteMagnitude
            for (dx,dy) in neighbors {
                let nx=x+dx,ny=y+dy
                let neighbor:Float=nx>=0 && nx<width && ny>=0 && ny<height ? alpha[ny*width+nx]:0
                if (value>=threshold)==(neighbor>=threshold) { continue }
                let fraction=min(1,max(0,(threshold-value)/(neighbor-value)))
                let seed=SIMD2(min(Float(width),max(0,point.x+Float(dx)*fraction)),min(Float(height),max(0,point.y+Float(dy)*fraction)))
                let delta=seed-point,distance=delta.x*delta.x+delta.y*delta.y
                if distance<bestDistance { best=seed;bestDistance=distance }
            }
            if let best { result.append(best) }
        }}
        return result
    }
    private func texture(_ values:[Float],width:Int,height:Int,renderer:Renderer) throws -> MTLTexture {
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let texture=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),raw=values.map{Float16($0).bitPattern}
        raw.withUnsafeBytes{texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*8)}
        return texture
    }
    func testFloodDistancesAgainstExhaustiveOracleOnNonSquareShapes() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let width=39,height=27
        var alpha=[Float](repeating:0,count:width*height)
        for y in 0..<height { for x in 0..<width {
            // Concave union, hole, isolated island, and a shape touching the border.
            let inside=(x>=4 && x<22 && y>=3 && y<23) || (x>=18 && x<31 && y>=13 && y<22) || (x>34 && y<5)
            let hole=x>=9 && x<14 && y>=8 && y<15
            alpha[y*width+x]=inside && !hole ? 1:0
        }}
        let input=try texture(alpha.flatMap{[$0*0.3,$0*0.6,$0*0.9,$0]},width:width,height:height,renderer:renderer)
        let command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
        let effect=try XCTUnwrap(EffectRegistry.definition("awi41.contour.map")).makeInstance()
        let context=EffectContext(gpu:renderer.fx,cb:command,input:input,effect:effect,time:0,unit:1,pool:pool)
        let field=try XCTUnwrap(DistanceField41.encode(context))
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rg32Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared
        let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:field,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),
            to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var actual=[Float](repeating:0,count:width*height*2)
        actual.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:width*8,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
        let candidates=seeds(alpha,width:width,height:height,threshold:0.5)
        XCTAssertFalse(candidates.isEmpty)
        for y in 0..<height { for x in 0..<width {
            let point=SIMD2(Float(x)+0.5,Float(y)+0.5),index=(y*width+x)*2
            let nearest=candidates.map{hypot($0.x-point.x,$0.y-point.y)}.min()!
            let measured=hypot(actual[index]-point.x,actual[index+1]-point.y)
            XCTAssertGreaterThanOrEqual(actual[index],0)
            XCTAssertLessThanOrEqual(abs(measured-nearest),0.75,"Distance error at \(x),\(y)")
        }}
    }
    func testEmptyInputStaysEmptyAndWarpCoverageIsPreserved() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for definition in EffectRegistry.distance41 {
            let command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
            let empty=try texture([Float](repeating:0,count:13*9*4),width:13,height:9,renderer:renderer)
            guard case .pixels(let run)=definition.stage else { return XCTFail("Expected pixel operation") }
            let result=run(EffectContext(gpu:renderer.fx,cb:command,input:empty,effect:definition.makeInstance(),time:0.4,unit:1,pool:pool))
            let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:13,height:9,mipmapped:false)
            descriptor.storageMode = .shared
            let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),blit=try XCTUnwrap(command.makeBlitCommandEncoder())
            blit.copy(from:result,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:13,height:9,depth:1),
                to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
            blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
            var raw=[UInt16](repeating:0,count:13*9*4)
            raw.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:13*8,from:MTLRegionMake2D(0,0,13,9),mipmapLevel:0)}
            XCTAssertTrue(raw.allSatisfy{$0==0},definition.name)
        }
        let original=try render(nil)
        for id in ["pull","refract","flow","fold"] {
            let output=try render(try XCTUnwrap(EffectRegistry.definition("awi41.contour."+id)).makeInstance())
            for index in stride(from:3,to:original.count,by:4) { XCTAssertEqual(original[index],output[index],id) }
        }
    }
}
