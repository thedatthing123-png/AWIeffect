import XCTest
import Metal
@testable import AWIeffect

final class PoissonEffectTests:XCTestCase {
    func testFamilyPlacementAndDistinctDefinitions() {
        XCTAssertEqual(EffectRegistry.poisson45.count,4)
        XCTAssertEqual(Set(EffectRegistry.poisson45.map(\.id)).count,4)
        for (index,definition) in EffectRegistry.poisson45.enumerated() {
            XCTAssertEqual(EffectSection.of(definition),index<2 ? .data:.stylize)
        }
    }
    private func process(_ pixels:[Float],width:Int,height:Int,effect:EffectInstance) throws -> [Float] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let input=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),raw=pixels.map{Float16($0).bitPattern}
        raw.withUnsafeBytes{input.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:width*8)}
        let command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
        let definition=try XCTUnwrap(EffectRegistry.definition(effect.typeID))
        guard case .pixels(let run)=definition.stage else { XCTFail("Expected pixel effect");return [] }
        let result=run(EffectContext(gpu:renderer.fx,cb:command,input:input,effect:effect,time:0.4,unit:1,pool:pool))
        let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor)),blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:result,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),sourceSize:MTLSize(width:width,height:height,depth:1),
            to:readback,destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var resultBits=raw
        resultBits.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:width*8,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
        return resultBits.map{Float(Float16(bitPattern:$0))}
    }
    func testIntegratingKnownGradientsAndNormalsRecoversPeriodicHeight() throws {
        let width=16,height=8
        func value(_ x:Int,_ y:Int) -> Double { 0.2*cos(2*Double.pi*Double(x)/Double(width))+0.1*sin(2*Double.pi*Double(y)/Double(height)) }
        for normal in [false,true] {
            var pixels=[Float]()
            for y in 0..<height { for x in 0..<width {
                let gx=value(x+1,y)-value(x,y),gy=value(x,y+1)-value(x,y)
                if normal {
                    let length=sqrt(gx*gx+gy*gy+1)
                    pixels += [Float(0.5-gx/length*0.5),Float(0.5-gy/length*0.5),Float(0.5+0.5/length),1]
                } else { pixels += [Float(gx*0.5+0.5),Float(gy*0.5+0.5),0.5,1] }
            }}
            var effect=try XCTUnwrap(EffectRegistry.definition(normal ? "awi45.poisson.normalHeight":"awi45.poisson.gradientHeight")).makeInstance()
            effect.params["range"] = .number(Animated(1))
            let output=try process(pixels,width:width,height:height,effect:effect)
            for y in 0..<height { for x in 0..<width {
                let index=(y*width+x)*4,expected=Float(0.5+value(x,y))
                for channel in 0..<3 { XCTAssertEqual(output[index+channel],expected,accuracy:0.006,"Height at \(x),\(y)") }
                XCTAssertEqual(output[index+3],1)
            }}
            for strength in [-1.0,0.0] {
                effect.params["strength"] = .number(Animated(strength))
                let changed=try process(pixels,width:width,height:height,effect:effect)
                for y in 0..<height { for x in 0..<width {
                    XCTAssertEqual(changed[(y*width+x)*4],Float(0.5+value(x,y)*strength),accuracy:0.006)
                }}
            }
        }
    }
    /// Direct DFT sums, independent of GPU bit-reversal, butterfly scheduling,
    /// scratch-buffer parity and inverse normalization.
    private func tileOracle(_ pixels:[Float],width:Int,height:Int,vertical:Double) -> [Float] {
        let data=pixels.map{Double(Float16($0))},count=width*height
        var force=[SIMD3<Double>](repeating:.zero,count:count)
        func color(_ x:Int,_ y:Int) -> SIMD3<Double> { let index=(y*width+x)*4;return SIMD3(data[index],data[index+1],data[index+2]) }
        for y in 0..<height { for x in 0..<width {
            let index=y*width+x,c=color(x,y)
            if x==0 { force[index]+=color(width-1,y)-c };if x==width-1 { force[index]+=color(0,y)-c }
            if y==0 { force[index]+=(color(x,height-1)-c)*vertical };if y==height-1 { force[index]+=(color(x,0)-c)*vertical }
        }}
        var real=force,imaginary=force
        for ky in 0..<height { for kx in 0..<width {
            let index=ky*width+kx;real[index] = .zero;imaginary[index] = .zero
            if kx==0 && ky==0 { continue }
            for y in 0..<height { for x in 0..<width {
                let phase=2*Double.pi*(Double(kx*x)/Double(width)+Double(ky*y)/Double(height))
                real[index]+=force[y*width+x]*cos(phase);imaginary[index]-=force[y*width+x]*sin(phase)
            }}
            let denominator=2*cos(2*Double.pi*Double(kx)/Double(width))-2+vertical*(2*cos(2*Double.pi*Double(ky)/Double(height))-2)
            real[index]/=denominator;imaginary[index]/=denominator
        }}
        var result=data
        for y in 0..<height { for x in 0..<width {
            var smooth=SIMD3<Double>.zero
            for ky in 0..<height { for kx in 0..<width {
                let phase=2*Double.pi*(Double(kx*x)/Double(width)+Double(ky*y)/Double(height)),index=ky*width+kx
                smooth+=real[index]*cos(phase)-imaginary[index]*sin(phase)
            }}
            for channel in 0..<3 { result[(y*width+x)*4+channel]=max(0,data[(y*width+x)*4+channel]-smooth[channel]/Double(count)) }
        }}
        return result.map{Float($0)}
    }
    func testPeriodicDecompositionMatchesIndependentDFTOnRectangularImage() throws {
        let width=16,height=8
        var pixels=[Float]()
        for y in 0..<height { for x in 0..<width {
            pixels += [Float(x)/Float(width-1),Float(y)/Float(height-1),Float(0.3+0.1*sin(2*Double.pi*(Double(x)/Double(width)+Double(y)/Double(height)))),1]
        }}
        var effect=try XCTUnwrap(EffectRegistry.definition("awi45.poisson.tile")).makeInstance()
        effect.params["vertical"] = .number(Animated(0.7))
        let actual=try process(pixels,width:width,height:height,effect:effect),expected=tileOracle(pixels,width:width,height:height,vertical:0.7)
        for index in actual.indices { XCTAssertEqual(actual[index],expected[index],accuracy:0.003,"Periodic component channel \(index)") }
    }
    func testLinearGradientReshapeIsIdentityAndEmptyInputsStayEmpty() throws {
        let width=8,height=4
        var pixels=[Float]()
        for y in 0..<height { for x in 0..<width { pixels += [Float(x)/8,Float(y)/4,0.4,1] } }
        var effect=try XCTUnwrap(EffectRegistry.definition("awi45.poisson.reshape")).makeInstance()
        effect.params["exponent"] = .number(Animated(1))
        let output=try process(pixels,width:width,height:height,effect:effect)
        for index in pixels.indices { XCTAssertEqual(output[index],Float(Float16(pixels[index])),accuracy:0.002) }
        for definition in EffectRegistry.poisson45 {
            let empty=[Float](repeating:0,count:8*4*4)
            XCTAssertEqual(try process(empty,width:8,height:4,effect:definition.makeInstance()),empty,definition.name)
        }
    }
    func testDefaultFallbackBypassAndCoverageOnLayersAndAdjustments() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        func render(_ effect:EffectInstance?,_ adjustment:Bool) throws -> [UInt8] {
            try XCTUnwrap(renderer.renderPixels(project:DataEffectTests.scene(effect,onAdjustment:adjustment),time:0.4,
                preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
        }
        for adjustment in [false,true] {
            let original=try render(nil,adjustment)
            for definition in EffectRegistry.poisson45 {
                var effect=definition.makeInstance();let result=try render(effect,adjustment)
                XCTAssertGreaterThan(zip(original,result).filter{abs(Int($0.0)-Int($0.1))>2}.count,50,definition.name)
                XCTAssertEqual(result,try render(EffectInstance(typeID:definition.id,params:[:]),adjustment),definition.name)
                effect.params["blend"] = .number(Animated(0));XCTAssertEqual(original,try render(effect,adjustment),definition.name)
            }
        }
    }
    func testPartialCoverageRemainsPremultiplied() throws {
        let pixel:[Float]=[0.25,0.25,0.5,0.5],pixels=Array(repeating:pixel,count:8).flatMap{$0}
        for (index,definition) in EffectRegistry.poisson45.enumerated() {
            let output=try process(pixels,width:4,height:2,effect:definition.makeInstance())
            let expected:[Float]=index<2 ? [0.25,0.25,0.25,0.5]:pixel
            for channel in output.indices { XCTAssertEqual(output[channel],expected[channel%4],accuracy:0.001,definition.name) }
        }
    }
}
