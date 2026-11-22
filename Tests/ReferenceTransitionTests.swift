import XCTest
import Metal
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class ReferenceTransitionTests: XCTestCase {
    private var harness: (MTLDevice, MTLCommandQueue, EffectGPU)?
    private func resources() throws -> (MTLDevice, MTLCommandQueue, EffectGPU) {
        if let harness { return harness }
        guard let device=MTLCreateSystemDefaultDevice() else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        let queue=try XCTUnwrap(device.makeCommandQueue()),library=try XCTUnwrap(device.makeDefaultLibrary())
        let result=(device,queue,try EffectGPU(device:device,library:library))
        harness=result;return result
    }
    private func render(_ definition: EffectDefinition, _ effect: EffectInstance, width: Int = 128, height: Int = 96,
                        empty: Bool = false, time: Double = 0.4) throws -> [Float16] {
        let (device,queue,gpu)=try resources()
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared; descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        let input = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var pixels = [Float16](repeating: 0, count: width * height * 4)
        if !empty {
            for y in 0..<height { for x in 0..<width {
                let u = Float(x) / Float(width), v = Float(y) / Float(height)
                let a: Float = x > 4 && y > 4 && x < width-5 && y < height-5 ? 0.7 : 0
                let index = (y*width+x)*4
                pixels[index] = Float16(u*a); pixels[index+1] = Float16(v*a)
                pixels[index+2] = Float16((x/9+y/7)%2 == 0 ? a : a*0.2); pixels[index+3] = Float16(a)
            } }
        }
        pixels.withUnsafeBytes { input.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: width*8) }
        let buffer = try XCTUnwrap(queue.makeCommandBuffer()), pool = TexturePool(device: device)
        let context = EffectContext(gpu: gpu, cb: buffer, input: input, effect: effect, time: time, unit: 1, pool: pool,
                                    layerPixels: SIMD2(Double(width),Double(height)))
        guard case .pixels(let encode) = definition.stage else { throw RenderError.pipeline("Expected pixel transition") }
        let output = encode(context)
        let readback = try XCTUnwrap(device.makeBuffer(length: pixels.count*2, options: .storageModeShared))
        let blit = try XCTUnwrap(buffer.makeBlitCommandEncoder())
        blit.copy(from: output, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: width, height: height, depth: 1), to: readback, destinationOffset: 0,
                  destinationBytesPerRow: width*8, destinationBytesPerImage: width*height*8)
        blit.endEncoding(); buffer.commit(); buffer.waitUntilCompleted()
        XCTAssertEqual(buffer.status, .completed, buffer.error?.localizedDescription ?? definition.name)
        return Array(UnsafeBufferPointer(start: readback.contents().assumingMemoryBound(to: Float16.self), count: pixels.count))
    }

    func testCompletionEndpointsAndEmptyArtworkAtDifferentAspectRatios() throws {
        for definition in EffectRegistry.referenceTransitions {
            for size in [(128,96),(96,160)] {
                var effect = definition.makeInstance()
                let start = try render(definition,effect,width:size.0,height:size.1)
                let identity=EffectDefinition(id:"fixture.identity",name:"Identity",category:.color,aeMatchNames:[],summary:"",params:[],stage:.pixels { $0.input })
                XCTAssertEqual(start,try render(identity,identity.makeInstance(),width:size.0,height:size.1))
                XCTAssertTrue(start.contains { $0 > 0 })
                effect.params["progress"] = .number(Animated(100))
                XCTAssertTrue(try render(definition,effect,width:size.0,height:size.1).allSatisfy { $0 == 0 })
                effect.params["progress"] = .number(Animated(55))
                XCTAssertTrue(try render(definition,effect,width:size.0,height:size.1,empty:true).allSatisfy { $0 == 0 })
                let middle = try render(definition,effect,width:size.0,height:size.1)
                XCTAssertNotEqual(middle,start)
                XCTAssertTrue(middle.contains { $0 > 0 })
                XCTAssertTrue(middle.allSatisfy { Float($0).isFinite })
                for i in stride(from: 0,to:middle.count,by:4) {
                    XCTAssertLessThanOrEqual(Float(middle[i+3]),1)
                    for c in 0..<3 { XCTAssertLessThanOrEqual(Float(middle[i+c]),Float(middle[i+3])+0.002) }
                }
            }
        }
    }
    func testOlderInstancesHaveExactDefaultsAndDeterministicSeeds() throws {
        for definition in EffectRegistry.referenceTransitions {
            let defaults = definition.makeInstance()
            var missing = defaults; missing.params.removeAll()
            XCTAssertEqual(try render(definition,defaults),try render(definition,missing))
            var mid = defaults; mid.params["progress"] = .number(Animated(55))
            XCTAssertEqual(try render(definition,mid),try render(definition,mid))
            var changed = mid; changed.params["seed"] = .number(Animated(17.3))
            XCTAssertNotEqual(try render(definition,mid),try render(definition,changed))
        }
    }
    func testFractalWarpAxisKeepsTheOtherCoordinateFixedAndOldXYUnchanged() throws {
        let definition = EffectRegistry.fractalWarp
        var effect = definition.makeInstance(); effect.params["magnitude"] = .number(Animated(0.25))
        var old = effect; old.params.removeValue(forKey:"axis")
        XCTAssertEqual(try render(definition,effect),try render(definition,old))
        effect.params["axis"] = .choice(1); let x = try render(definition,effect)
        effect.params["axis"] = .choice(2); let y = try render(definition,effect)
        XCTAssertNotEqual(x,y)
        for row in 24..<72 { for column in 24..<104 {
            let index=(row*128+column)*4
            XCTAssertEqual(Float(x[index+1]),Float(Float16(Float(row)/96*0.7)),accuracy:0.002)
            XCTAssertEqual(Float(y[index]),Float(Float16(Float(column)/128*0.7)),accuracy:0.002)
        } }
    }
    func testWriteTransitionMotionReview() throws {
        let folder=URL(fileURLWithPath:"/tmp/awi-reference-review")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        for definition in EffectRegistry.referenceTransitions {
            let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent(definition.id+"-motion.gif") as CFURL,UTType.gif.identifier as CFString,16,nil))
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            var effect=definition.makeInstance(),progress=Animated(0.0)
            progress.insertKeyframe(Keyframe(time:0,value:0.0));progress.insertKeyframe(Keyframe(time:1,value:100.0))
            effect.params["progress"] = .number(progress)
            for frame in 0..<16 {
                let pixels=try render(definition,effect,time:Double(frame)/15)
                var bytes=[UInt8](repeating:0,count:pixels.count)
                for index in stride(from:0,to:pixels.count,by:4) {
                    let a=max(0,min(1,Float(pixels[index+3])))
                    for channel in 0..<3 { bytes[index+channel]=UInt8((max(0,min(1,a>0 ? Float(pixels[index+channel])/a : 0))*255).rounded()) }
                    bytes[index+3]=UInt8((a*255).rounded())
                }
                let provider=try XCTUnwrap(CGDataProvider(data:Data(bytes) as CFData))
                let image=try XCTUnwrap(CGImage(width:128,height:96,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:512,
                    space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent))
                CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
                if frame==8 { try UIImage(cgImage:image).pngData()?.write(to:folder.appendingPathComponent(definition.id+".png")) }
            }
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
