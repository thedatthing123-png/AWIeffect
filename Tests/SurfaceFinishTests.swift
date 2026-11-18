import XCTest
import Metal
@testable import AWIeffect

final class SurfaceFinishTests:XCTestCase {
    private func render(_ effect:EffectInstance?,adjustment:Bool=false) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:DistanceEffectTests.scene(effect,onAdjustment:adjustment),time:0.4,
            preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    func testDefaultsFallbacksBypassAndCoverageOnBothLayerTypes() throws {
        for adjustment in [false,true] {
            let original=try render(nil,adjustment:adjustment)
            for definition in EffectRegistry.finishes44 {
                var effect=definition.makeInstance()
                let output=try render(effect,adjustment:adjustment)
                XCTAssertGreaterThan(zip(original,output).filter{abs(Int($0.0)-Int($0.1))>2}.count,50,definition.name)
                XCTAssertEqual(output,try render(EffectInstance(typeID:definition.id,params:[:]),adjustment:adjustment),definition.name)
                for index in stride(from:3,to:original.count,by:4) { XCTAssertEqual(original[index],output[index],definition.name) }
                effect.params["blend"] = .number(Animated(0))
                XCTAssertEqual(original,try render(effect,adjustment:adjustment),definition.name)
            }
        }
    }
    private func process(_ effect:EffectInstance,pixel:[Float]) throws -> [Float] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:1,height:1,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let input=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),raw=pixel.map{Float16($0).bitPattern}
        raw.withUnsafeBytes{input.replace(region:MTLRegionMake2D(0,0,1,1),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:8)}
        let command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
        let definition=try XCTUnwrap(EffectRegistry.definition(effect.typeID))
        guard case .pixels(let run)=definition.stage else { XCTFail("Expected pixel effect");return [] }
        let output=run(EffectContext(gpu:renderer.fx,cb:command,input:input,effect:effect,time:0.4,unit:1,pool:pool))
        let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:output,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:1,height:1,depth:1),
            to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var result=raw
        result.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:8,from:MTLRegionMake2D(0,0,1,1),mipmapLevel:0)}
        return result.map{Float(Float16(bitPattern:$0))}
    }
    /// Independent flat-plane reflection oracle: no procedural height evaluation,
    /// texture sampling, finite-difference normals or tangent construction is shared.
    private func flatOracle(_ pixel:[Float],mode:Int) -> [Float] {
        let input=pixel.map{Double(Float16($0))},alpha=input[3]
        let direction=25.0*Double.pi/180,azimuth = -45.0*Double.pi/180,elevation=45.0*Double.pi/180
        let light=[cos(azimuth)*cos(elevation),sin(azimuth)*cos(elevation),sin(elevation)]
        let length=sqrt(light[0]*light[0]+light[1]*light[1]+pow(1+light[2],2))
        let halfway=[light[0]/length,light[1]/length,(1+light[2])/length]
        let rough=0.34*0.34,ax=max(0.003,rough*(mode==0 ? 0.18:mode==2 ? 0.5:1)),ay=max(0.003,rough*(mode==0 ? 1.8:mode==2 ? 1.6:1))
        func tangent(_ vector:[Double]) -> Double { vector[0]*cos(direction)+vector[1]*sin(direction) }
        func bitangent(_ vector:[Double]) -> Double { -vector[0]*sin(direction)+vector[1]*cos(direction) }
        let denominator=pow(tangent(halfway)/ax,2)+pow(bitangent(halfway)/ay,2)+halfway[2]*halfway[2]
        let distribution=1/(Double.pi*ax*ay*denominator*denominator)
        let g=2/(1+sqrt(1+(pow(tangent(light)*ax,2)+pow(bitangent(light)*ay,2))/(light[2]*light[2])))
        var result=[Float]()
        for channel in 0..<3 {
            let albedo=pow(input[channel]/alpha,2.2)
            var f0=0.04*0.5+min(1,albedo)*0.5
            if mode==7 {
                let wavelength=[650.0,510.0,475.0][channel],path=4*Double.pi*1.45*420*halfway[2]
                let coating=0.04+0.25*(0.5+0.5*cos(path/wavelength));f0=f0*0.3+coating*0.7
            }
            let fresnel=f0+(1-f0)*pow(1-halfway[2],5)
            let specular=fresnel*distribution*g/4
            let energy=albedo*0.3+(albedo*0.5*light[2]/Double.pi+specular)*2
            result.append(Float(pow(energy,1/2.2)*alpha))
        }
        return result+[Float(alpha)]
    }
    func testFlatSurfacesMatchReflectionOracleAndEmptyInputStaysEmpty() throws {
        let pixel:[Float]=[0.28,0.42,0.56,0.7]
        for (mode,definition) in EffectRegistry.finishes44.enumerated() {
            var effect=definition.makeInstance()
            effect.params["depth"] = .number(Animated(0));effect.params["relief"] = .number(Animated(0))
            effect.params["metal"] = .number(Animated(50))
            effect.params["light"] = .number(Animated(-45));effect.params["elevation"] = .number(Animated(45))
            effect.params["roughness"] = .number(Animated(0.34))
            if mode==3 { effect.params["special"] = .number(Animated(0)) }
            if mode==5 { effect.params["dispersion"] = .number(Animated(0)) }
            let actual=try process(effect,pixel:pixel),expected=flatOracle(pixel,mode:mode)
            for channel in 0..<4 { XCTAssertEqual(actual[channel],expected[channel],accuracy:0.004,"\(definition.name) channel \(channel)") }
            XCTAssertEqual(try process(definition.makeInstance(),pixel:[0,0,0,0]),[0,0,0,0],definition.name)
        }
    }
    func testCatalogPlacementAndNoDuplicateNames() {
        XCTAssertEqual(EffectRegistry.finishes44.count,8)
        XCTAssertEqual(Set(EffectRegistry.finishes44.map(\.name)).count,8)
        for definition in EffectRegistry.finishes44 { XCTAssertEqual(EffectSection.of(definition),.threeD) }
    }
}
