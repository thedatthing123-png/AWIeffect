import XCTest
import Metal
@testable import AWIeffect

final class TemporalAnalysisTests:XCTestCase {
    private func process(_ effect:EffectInstance,levels:[Float]) throws -> [Float] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:1,height:1,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        var frames:[MTLTexture]=[]
        for level in levels {
            let texture=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
            let raw=[level,level,level,Float(1)].map{Float16($0).bitPattern}
            raw.withUnsafeBytes{texture.replace(region:MTLRegionMake2D(0,0,1,1),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:8)}
            frames.append(texture)
        }
        let input=try XCTUnwrap(frames.last),command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
        var context=EffectContext(gpu:renderer.fx,cb:command,input:input,effect:effect,time:0.4,unit:1,pool:pool)
        context.temporalSample={ time in frames[min(frames.count-1,max(0,Int((time/0.4*Double(frames.count-1)).rounded())))] }
        let definition=try XCTUnwrap(EffectRegistry.definition(effect.typeID))
        guard case .pixels(let run)=definition.stage else { XCTFail("Expected pixel effect");return [] }
        let output=run(context),readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:output,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:1,height:1,depth:1),
            to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var result=[UInt16](repeating:0,count:4)
        result.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:8,from:MTLRegionMake2D(0,0,1,1),mipmapLevel:0)}
        return result.map{Float(Float16(bitPattern:$0))}
    }
    func testVarianceRankAndAccelerationMatchIndependentWindowMath() throws {
        let levels:[Float]=[0,0.25,0.5,0.75,1,0.25]
        var effect=try XCTUnwrap(EffectRegistry.definition("awi43.time.variance")).makeInstance()
        effect.params["gain"] = .number(Animated(1))
        let mean=levels.reduce(0,+)/Float(levels.count)
        let variance=levels.reduce(Float(0)){$0+($1-mean)*($1-mean)}/Float(levels.count)
        XCTAssertEqual(try process(effect,levels:levels)[0],sqrt(variance),accuracy:0.001)
        effect=try XCTUnwrap(EffectRegistry.definition("awi43.time.rank")).makeInstance()
        effect.params["rank"] = .number(Animated(70))
        XCTAssertEqual(try process(effect,levels:levels)[0],0.625,accuracy:0.001)
        effect=try XCTUnwrap(EffectRegistry.definition("awi43.time.acceleration")).makeInstance()
        effect.params["gain"] = .number(Animated(1))
        XCTAssertEqual(try process(effect,levels:[0.1,0.2,0.5])[0],0.2,accuracy:0.001)
    }
    func testConstantWindowHasNoVarianceAccelerationOrFrequencyEnergy() throws {
        for id in ["variance","acceleration","frequency"] {
            let effect=try XCTUnwrap(EffectRegistry.definition("awi43.time."+id)).makeInstance()
            let levels=[Float](repeating:0.4,count:id=="acceleration" ? 3:id=="frequency" ? 8:6)
            let actual=try process(effect,levels:levels)
            XCTAssertEqual(actual[0],0,accuracy:0.001,id);XCTAssertEqual(actual[3],1,accuracy:0.001,id)
        }
    }
    func testFamilyUsesTemporalSamplingAndTimeBrowser() {
        XCTAssertEqual(EffectRegistry.temporalAnalysis43.count,9)
        for definition in EffectRegistry.temporalAnalysis43 {
            XCTAssertTrue(EffectRegistry.temporalIDs33.contains(definition.id));XCTAssertEqual(EffectSection.of(definition),.time)
        }
    }
}
