import XCTest
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

/// Rich deterministic fixtures, including actual reference maps. Never compare an effect
/// with its map present against a baseline that silently removed the map layer.
final class Expansion50EffectTests:XCTestCase {
    func testJunctionFlaresSeeFlatCutoutCornersAndKeepEmptyInputEmpty()throws {
        let side=48
        var source=[Float](repeating:0,count:side*side*4)
        for y in 12..<36 { for x in 12..<36 {
            let i=(y*side+x)*4
            source[i]=0.8;source[i+1]=0.5;source[i+2]=0.2;source[i+3]=1
        }}
        let recipe=try XCTUnwrap(CraftPresets33.layerRecipes.first{$0.name=="Corner Spark Sweep"})
        let effect=try XCTUnwrap(recipe.effects.first?.make(start:0,duration:1))
        let rendered=try process(source,reference:nil,width:side,height:side,effect:effect)
        XCTAssertGreaterThan(zip(source,rendered).filter{abs($0.0-$0.1)>0.01}.count,20,"Junction light must see constant-color alpha corners, not only internal texture")
        let empty=[Float](repeating:0,count:source.count)
        XCTAssertTrue(try process(empty,reference:nil,width:side,height:side,effect:effect).allSatisfy{$0==0})
    }
    static let definitions=EffectRegistry.spectral46+EffectRegistry.interactions47+EffectRegistry.craft48
    static func contains(_ id:String)->Bool { id.hasPrefix("awi46.") || id.hasPrefix("awi47.") || id.hasPrefix("awi48.") }
    private static let directory=FileManager.default.temporaryDirectory.appendingPathComponent("expansion50-\(UUID().uuidString)")
    private static func image(_ kind:String)->URL {
        let url=directory.appendingPathComponent(kind+".png")
        if FileManager.default.fileExists(atPath:url.path) { return url }
        try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let side=160
        var bytes=[UInt8](repeating:255,count:side*side*4)
        for y in 0..<side { for x in 0..<side {
            let sx=kind=="translated" ? x-9:x,sy=kind=="translated" ? y+5:y
            let u=(Double(sx)+0.5)/160,v=(Double(sy)+0.5)/160
            let pattern=0.5+0.20*sin(u*57+sin(v*19))+0.15*cos(v*83)+0.1*sin((u+v)*131)
            var rgb=[pattern,0.5+0.3*sin(u*17+v*11),0.5+0.3*cos(v*23-u*9)]
            if (sx/13+sy/17)%3==0 { rgb=rgb.map{$0*0.3} }
            if kind=="map" { rgb=[Double(x)/159,Double(y)/159,0.5+0.45*sin(Double(x)*0.12)*cos(Double(y)*0.1)] }
            if kind=="depth" { let depth=0.5+0.45*sin(Double(x)*0.12)*cos(Double(y)*0.1);rgb=[depth,depth,depth] }
            if kind=="normal" {
                let nx=0.6*sin(u*15),ny=0.6*cos(v*17),nz=sqrt(max(0.01,1-nx*nx-ny*ny));rgb=[nx*0.5+0.5,ny*0.5+0.5,nz*0.5+0.5]
            }
            if kind=="psf" { let r=hypot((Double(x)-79.5)/13,(Double(y)-79.5)/6);rgb=Array(repeating:exp(-r*r*0.5),count:3) }
            if kind=="palette" { rgb=[0.5+0.5*sin(u*6.28+v),0.5+0.5*cos(u*6.28-v*3),0.2+0.7*u] }
            let index=(y*side+x)*4
            for channel in 0..<3 { bytes[index+channel]=UInt8((min(1,max(0,rgb[channel]))*255).rounded()) }
        }}
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),let image=CGImage(width:side,height:side,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent),let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { XCTFail("Fixture creation failed");return url }
        CGImageDestinationAddImage(destination,image,nil);XCTAssertTrue(CGImageDestinationFinalize(destination));return url
    }
    static func scene(_ effect:EffectInstance,onAdjustment:Bool=false)->Project {
        // Contour tools need a real alpha edge, not a full opaque photograph.
        if ["awi48.craft.stitch","awi48.craft.fringe","awi48.craft.burn","awi47.layer.matte"].contains(effect.typeID) {
            if effect.typeID != "awi47.layer.matte" { return DistanceEffectTests.scene(effect,onAdjustment:onAdjustment) }
        }
        var project=Project.new(name:"Expansion 50",width:160,height:160,fps:30,duration:3,background:RGBA(0,0,0,0))
        let key=effect.typeID.components(separatedBy:".").last ?? ""
        let kind=key=="convolve" ? "psf":["correlate","register"].contains(key) ? "translated":key=="normalLight" ? "normal":key=="palette" ? "palette":["shadow","occlusion","fog","parallax","focus","refract"].contains(key) ? "depth":"map"
        var reference=project.makeLayer(name:"Reference map",content:.image(fileName:image(kind).path,pixelWidth:160,pixelHeight:160),size:Vec2(160,160))
        // References are visible under the opaque source so the renderer can resolve them.
        reference.transform.position=Animated(Vec2(80,80))
        var layer=project.makeLayer(name:"Detailed artwork",content:.image(fileName:image("source").path,pixelWidth:160,pixelHeight:160),size:Vec2(160,160))
        var selected=effect
        if EffectRegistry.layerRefIDs.contains(effect.typeID) { selected.text=["layer":reference.id.uuidString] }
        if key=="matte" { layer=project.makeLayer(name:"Coverage",content:.shape(.star),size:Vec2(120,100));layer.fill=Animated(RGBA(0.7,0.3,0.8,0.7)) }
        layer.effects=[selected];project.layers=[layer]
        if EffectRegistry.layerRefIDs.contains(effect.typeID) { project.layers.append(reference) }
        // These are pixel operators on the current image; adjustment routing uses
        // the same map-bearing source rather than flattening the reference into it.
        return project
    }
    private func pixels(_ effect:EffectInstance)throws->[UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:Self.scene(effect),time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    private func difference(_ a:[UInt8],_ b:[UInt8])->Double { guard a.count==b.count else { return .infinity };return zip(a,b).reduce(0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(max(1,a.count)) }
    func testFiftyDistinctDefinitionsAndReferenceRegistration() {
        XCTAssertEqual(Self.definitions.count,50)
        XCTAssertEqual(Set(Self.definitions.map(\.id)).count,50)
        XCTAssertEqual(Set(Self.definitions.map(\.name)).count,50)
        for definition in EffectRegistry.interactions47 { XCTAssertTrue(EffectRegistry.layerRefIDs.contains(definition.id)) }
        for definition in Self.definitions { XCTAssertNotEqual(EffectSection.of(definition),.other,definition.name) }
    }
    func testDefaultsChangeRichSourceAndBlendZeroIsExact() throws {
        for definition in Self.definitions {
            let effect=definition.makeInstance();var bypass=effect;bypass.isEnabled=false
            let baseline=try pixels(bypass),processed=try pixels(effect)
            XCTAssertGreaterThan(difference(baseline,processed),0.05,definition.name+" default is invisible on its intended fixture")
            var zero=effect;zero.params["blend"] = .number(Animated(0))
            XCTAssertEqual(try pixels(zero),baseline,definition.name+" Blend zero must bypass exactly")
        }
    }
    func testOldSerializedInstancesUseIdenticalParameterFallbacks() throws {
        for definition in Self.definitions {
            let effect=definition.makeInstance();var legacy=effect;legacy.params=[:]
            XCTAssertEqual(try pixels(effect),try pixels(legacy),definition.name+" fallback differs from authored defaults")
        }
    }
    func testReferenceOperatorsWithoutReferenceAreExactBypasses() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for definition in Self.definitions where EffectRegistry.layerRefIDs.contains(definition.id) {
            var project=Self.scene(definition.makeInstance());project.layers[0].effects[0].text=nil
            let actual=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            project.layers[0].effects=[]
            let expected=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            XCTAssertEqual(actual,expected,definition.name)
        }
    }
    func testDissolveAndBurnEndpoints() throws {
        for id in ["awi47.layer.dissolve","awi48.craft.burn"] {
            let definition=try XCTUnwrap(EffectRegistry.definition(id));var effect=definition.makeInstance(),bypass=effect;bypass.isEnabled=false
            let parameter=id.hasSuffix("burn") ? "first":"amount"
            effect.params[parameter] = .number(Animated(0));XCTAssertEqual(try pixels(effect),try pixels(bypass),id+" starts unchanged")
            effect.params[parameter] = .number(Animated(id.hasSuffix("burn") ? 1000:100))
            if id.hasSuffix("burn") { effect.params["only"] = .toggle(true) }
            let cleared=try pixels(effect)
            if id.hasSuffix("burn") { XCTAssertEqual(cleared.max(),0,"Burn must fully consume a small image at maximum depth") }
            else { XCTAssertGreaterThan(difference(cleared,try pixels(bypass)),1) }
        }
    }
    func testReferenceNumericControlsRespond() throws {
        // Generic numeric-control tests intentionally omit reference effects. Exercise
        // their actual maps here instead of counting an unconfigured no-op as coverage.
        for definition in Self.definitions where EffectRegistry.layerRefIDs.contains(definition.id) {
            for parameter in definition.params {
                guard case .number(let lo,let hi,_,_)=parameter.kind else { continue }
                var low=definition.makeInstance(),high=low
                low.params[parameter.id] = .number(Animated(lo+(hi-lo)*0.02));high.params[parameter.id] = .number(Animated(lo+(hi-lo)*0.6))
                // Perfect alignment cannot reveal search-range differences. The matching
                // fixture is displaced nine pixels, straddling the small-search limit.
                XCTAssertGreaterThan(difference(try pixels(low),try pixels(high)),0.01,definition.name+" / "+parameter.name)
            }
        }
    }
    private func process(_ pixels:[Float],reference:[Float]?,width:Int=16,height:Int=16,effect:EffectInstance)throws->[Float] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        func upload(_ values:[Float])throws->MTLTexture {
            let texture=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),bits=values.map{Float16($0).bitPattern}
            bits.withUnsafeBytes{texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*8)};return texture
        }
        let input=try upload(pixels),map=try reference.map{try upload($0)},command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
        let definition=try XCTUnwrap(EffectRegistry.definition(effect.typeID))
        guard case .pixels(let run)=definition.stage else { XCTFail("Expected pixel operator");return [] }
        var context=EffectContext(gpu:renderer.fx,cb:command,input:input,effect:effect,time:0.4,unit:1,pool:pool)
        context.reference=map;context.layerPixels=SIMD2(Double(width),Double(height));context.inputPixels=context.layerPixels
        let result=run(context),readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:result,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var bits=[UInt16](repeating:0,count:width*height*4)
        bits.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:width*8,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
        return bits.map{Float(Float16(bitPattern:$0))}
    }
    func testChannelArithmeticAndAlphaPackingAgainstScalarOracle() throws {
        let source=Array(repeating:[Float]([0.3,0.2,0.1,0.5]),count:256).flatMap{$0}
        let reference=Array(repeating:[Float]([0.4,0.6,0.8,1]),count:256).flatMap{$0}
        let calculate=try XCTUnwrap(EffectRegistry.definition("awi47.layer.calculate")).makeInstance()
        let output=try process(source,reference:reference,effect:calculate)
        for index in stride(from:0,to:output.count,by:4) {
            for (channel,expected) in [Float]([0.12,0.12,0.08,0.5]).enumerated() { XCTAssertEqual(output[index+channel],expected,accuracy:0.002) }
        }
        var pack=try XCTUnwrap(EffectRegistry.definition("awi47.layer.pack")).makeInstance()
        pack.params["option"] = .choice(3);pack.params["channel"] = .choice(0)
        let packed=try process(source,reference:reference,effect:pack)
        for index in stride(from:0,to:packed.count,by:4) {
            for (channel,expected) in [Float]([0.24,0.16,0.08,0.4]).enumerated() { XCTAssertEqual(packed[index+channel],expected,accuracy:0.002) }
        }
    }
    func testAbsoluteUVIdentityAndConstantVectorTransport() throws {
        var source=[Float](),map=[Float](),velocity=[Float]()
        for y in 0..<16 { for x in 0..<16 {
            let u=(Float(x)+0.5)/16,v=(Float(y)+0.5)/16
            source += [u,v,0.2,1];map += [u,v,0.5,1];velocity += [0.75,0.5,0.5,1]
        }}
        let identity=try XCTUnwrap(EffectRegistry.definition("awi47.layer.uv")).makeInstance()
        let unchanged=try process(source,reference:map,effect:identity)
        for index in source.indices { XCTAssertEqual(unchanged[index],source[index],accuracy:0.002) }
        var advect=try XCTUnwrap(EffectRegistry.definition("awi47.layer.advect")).makeInstance()
        advect.params["distance"] = .number(Animated(4))
        let shifted=try process(source,reference:velocity,effect:advect)
        for y in 2..<14 { for x in 2..<12 { let index=(y*16+x)*4
            XCTAssertEqual(shifted[index],source[index+8],accuracy:0.003)
            XCTAssertEqual(shifted[index+1],source[index+1],accuracy:0.003)
        }}
    }
    func testQuadratureHasKnownSineResponseAndPreservesMean() throws {
        var source=[Float]()
        for _ in 0..<16 { for x in 0..<16 { let value=Float(0.5+0.2*cos(2*Double.pi*Double(x)/16));source += [value,value,value,1] }}
        var effect=try XCTUnwrap(EffectRegistry.definition("awi46.spectral.quadrature")).makeInstance()
        effect.params["angle"] = .number(Animated(0))
        let result=try process(source,reference:nil,effect:effect)
        for y in 0..<16 { for x in 0..<16 {
            let expected=Float(0.5-0.2*sin(2*Double.pi*Double(x)/16))
            XCTAssertEqual(result[(y*16+x)*4],expected,accuracy:0.004)
            XCTAssertEqual(result[(y*16+x)*4+3],1,accuracy:0.001)
        }}
    }

}
