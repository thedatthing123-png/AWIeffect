import XCTest
import Metal
@testable import AWIeffect

final class DCTEffectTests:XCTestCase {
    private func process(_ input:[Float],width:Int,height:Int,effect:EffectInstance) throws -> [Float] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let texture=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
        let raw=input.map{Float16($0).bitPattern}
        raw.withUnsafeBytes{texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,
            withBytes:$0.baseAddress!,bytesPerRow:width*8)}
        let definition=try XCTUnwrap(EffectRegistry.definition(effect.typeID))
        guard case .pixels(let run)=definition.stage else { XCTFail("Pixel stage required");return [] }
        let command=try XCTUnwrap(renderer.queue.makeCommandBuffer()),pool=TexturePool(device:renderer.device)
        let result=run(EffectContext(gpu:renderer.fx,cb:command,input:texture,effect:effect,time:0.4,unit:1,pool:pool))
        let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
        let blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:result,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),
            sourceSize:MTLSize(width:width,height:height,depth:1),to:readback,destinationSlice:0,
            destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var values=raw
        values.withUnsafeMutableBytes{readback.getBytes($0.baseAddress!,bytesPerRow:width*8,
            from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
        return values.map{Float(Float16(bitPattern:$0))}
    }
    /// Deliberately direct 2D matrix sums, independent of the cooperative
    /// separable shader's memory layout and barrier ordering.
    private func oracle(_ input:[Float],width:Int,height:Int,method:Int) -> [Float] {
        let data=input.map{Double(Float16($0))}
        var output=data
        func basis(_ k:Int,_ n:Int) -> Double { (k==0 ? sqrt(1.0/8):0.5)*cos(Double(2*n+1)*Double(k)*Double.pi/16) }
        for top in stride(from:0,to:height,by:8) { for left in stride(from:0,to:width,by:8) {
            var block=Array(repeating:SIMD3<Double>(repeating:0),count:64)
            for y in 0..<8 { for x in 0..<8 {
                let index=(min(top+y,height-1)*width+min(left+x,width-1))*4
                let alpha=data[index+3]
                let color=alpha>0.00001 ? SIMD3(data[index],data[index+1],data[index+2])/alpha:SIMD3<Double>(repeating:0)
                let light=color.x*0.299+color.y*0.587+color.z*0.114
                block[y*8+x]=SIMD3(light-0.5,(color.z-light)*0.492,(color.x-light)*0.877)
            }}
            var coefficients=block
            for ky in 0..<8 { for kx in 0..<8 {
                var value=SIMD3<Double>(repeating:0)
                for y in 0..<8 { for x in 0..<8 { value+=block[y*8+x]*basis(kx,x)*basis(ky,y) }}
                if kx+ky>0 {
                    let frequency=hypot(Double(kx),Double(ky))
                    let amount=0.27*(1+pow(max(1,frequency),1.3))*0.0625
                    for channel in 0..<3 {
                        let step=amount*(channel==0 ? 1:1.6)
                        if method==0 { value[channel]=(value[channel]/step).rounded()*step }
                        else { value[channel]=(value[channel]<0 ? -1:1)*max(0,abs(value[channel])-step) }
                    }
                }
                coefficients[ky*8+kx]=value
            }}
            for y in 0..<min(8,height-top) { for x in 0..<min(8,width-left) {
                var value=SIMD3<Double>(repeating:0)
                for ky in 0..<8 { for kx in 0..<8 { value+=coefficients[ky*8+kx]*basis(kx,x)*basis(ky,y) }}
                let light=value.x+0.5,red=light+value.z/0.877,blue=light+value.y/0.492
                let green=(light-0.299*red-0.114*blue)/0.587,index=((top+y)*width+left+x)*4
                for (channel,component) in [red,green,blue].enumerated() { output[index+channel]=max(0,component)*data[index+3] }
            }}
        }}
        return output.map{Float($0)}
    }
    func testPartialBlocksMatchIndependentFrequencyOracle() throws {
        let width=13,height=11
        var pixels=[Float](repeating:0,count:width*height*4)
        for y in 0..<height { for x in 0..<width {
            let index=(y*width+x)*4,alpha:Float=x%7==0 ? 0:0.7
            pixels[index]=Float(0.4+0.3*sin(Double(x)*0.7+Double(y)*0.3))*alpha
            pixels[index+1]=Float(0.35+0.25*cos(Double(y)*0.8))*alpha
            pixels[index+2]=Float(0.4+0.2*sin(Double(x+y)*0.4))*alpha;pixels[index+3]=alpha
        }}
        for method in [0,1] {
            var effect=try XCTUnwrap(EffectRegistry.definition("awi37.dctBlocks")).makeInstance()
            effect.params["amount"] = .number(Animated(27));effect.params["frequency"] = .number(Animated(1.3))
            effect.params["chroma"] = .number(Animated(1.6));effect.params["method"] = .choice(method)
            let actual=try process(pixels,width:width,height:height,effect:effect),expected=oracle(pixels,width:width,height:height,method:method)
            for index in actual.indices {
                XCTAssertEqual(actual[index],expected[index],accuracy:index%4==3 ? 0.001:0.007,"Method \(method), component \(index)")
            }
            effect.params["amount"] = .number(Animated(0))
            XCTAssertEqual(try process(pixels,width:width,height:height,effect:effect),pixels.map{Float(Float16($0))})
        }
    }
    func testNonlinearPassesPreserveAConstantTranslucentField() throws {
        let width=11,height=13
        let pixel:[Float]=[0.12,0.21,0.3,0.375]
        let input=(0..<(width*height)).flatMap{_ in pixel}
        let expected=input.map{Float(Float16($0))}
        for definition in EffectRegistry.nonlinear37 {
            var effect=definition.makeInstance()
            effect.params["iterations"] = .number(Animated(24))
            effect.params["strength"] = .number(Animated(100))
            XCTAssertEqual(try process(input,width:width,height:height,effect:effect),expected,definition.name)
            effect.params["strength"] = .number(Animated(0))
            XCTAssertEqual(try process(input,width:width,height:height,effect:effect),expected,definition.name)
        }
    }
}
