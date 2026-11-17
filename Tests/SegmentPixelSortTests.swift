import XCTest
import Metal
@testable import AWIeffect

final class SegmentPixelSortTests:XCTestCase {
    private let values:[Double]=[0.8,0.3,0.55,0.05,0.72,0.25,0.4,0.98,0.7,0.35,0.6,0.28,0.83,0.45,0.03,0.5,0.82,0.31,0.62]
    private func line(_ effect:EffectInstance?,axis:Int) throws -> [UInt16] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let width=axis==0 ? values.count:4,height=axis==0 ? 4:values.count
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let input=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
        var data=[UInt16](repeating:0,count:width*height*4)
        for y in 0..<height { for x in 0..<width {
            let value=Float16(values[axis==0 ? x:y]).bitPattern,index=(y*width+x)*4
            data[index]=value;data[index+1]=value;data[index+2]=value;data[index+3]=Float16(1).bitPattern
        } }
        data.withUnsafeBytes { input.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*8) }
        let pool=TexturePool(device:renderer.device),command=try XCTUnwrap(renderer.queue.makeCommandBuffer())
        var result:MTLTexture=input
        if let effect {
            let definition=try XCTUnwrap(EffectRegistry.definition(effect.typeID))
            guard case .pixels(let run)=definition.stage else { XCTFail("Expected pixel stage");return [] }
            result=run(EffectContext(gpu:renderer.fx,cb:command,input:input,effect:effect,time:0.4,unit:1,pool:pool))
        }
        let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
        let blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:result,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),
            to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        data.withUnsafeMutableBytes { readback.getBytes($0.baseAddress!,bytesPerRow:width*8,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0) }
        return values.indices.map { index in
            let x=axis==0 ? index:2,y=axis==0 ? 2:index
            return data[(y*width+x)*4]
        }
    }
    func testSortingMatchesIndependentRunOracleOnBothAxesAndDirections() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi31.segmentSort"))
        for axis in [0,1] { for descending in [false,true] {
            var effect=definition.makeInstance()
            effect.params["axis"] = .choice(axis);effect.params["descending"] = .toggle(descending)
            effect.params["length"] = .number(Animated(8))
            effect.params["low"] = .number(Animated(20));effect.params["high"] = .number(Animated(90))
            let original=try line(nil,axis:axis)
            var expected=original
            for window in stride(from:0,to:values.count,by:8) {
                let end=min(window+8,values.count)
                var start=window
                while start<end {
                    if values[start]<0.2 || values[start]>0.9 { start+=1;continue }
                    var stop=start+1
                    while stop<end && values[stop]>=0.2 && values[stop]<=0.9 { stop+=1 }
                    let ordered=original[start..<stop].sorted(by:descending ? (>):(<))
                    expected.replaceSubrange(start..<stop,with:ordered);start=stop
                }
            }
            XCTAssertEqual(try line(effect,axis:axis),expected,"Axis \(axis), descending \(descending)")
        } }
    }
    func testStableHueTiesEmptySelectionAndBlendBypass() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi31.segmentSort"))
        let original=try line(nil,axis:0)
        var effect=definition.makeInstance();effect.params["key"] = .choice(1)
        XCTAssertEqual(original,try line(effect,axis:0),"Equal hue keys must retain original order")
        effect=definition.makeInstance();effect.params["low"] = .number(Animated(95));effect.params["high"] = .number(Animated(10))
        XCTAssertEqual(original,try line(effect,axis:0),"No selected pixels means no reordering")
        effect=definition.makeInstance();effect.params["blend"] = .number(Animated(0))
        XCTAssertEqual(original,try line(effect,axis:0))
    }
    func testImportedChoicesClampBeforeUnsignedGPUConversion() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi31.segmentSort"))
        var invalid=definition.makeInstance(),valid=invalid
        invalid.params["axis"] = .choice(-1);invalid.params["key"] = .choice(Int.max)
        valid.params["axis"] = .choice(0);valid.params["key"] = .choice(2)
        XCTAssertEqual(try line(invalid,axis:0),try line(valid,axis:0))
    }
}
