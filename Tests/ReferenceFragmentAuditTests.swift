import XCTest
import Metal
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

/// Exercise every translated reference through the native adapter, including
/// overlapping effects retained internally for comparison rather than shown twice.
final class ReferenceFragmentAuditTests: XCTestCase {
    private func audit(part: Int) throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("SKIP-GPU: Metal unavailable") }
        let queue = try XCTUnwrap(device.makeCommandQueue())
        let library = try XCTUnwrap(device.makeDefaultLibrary())
        let gpu = try EffectGPU(device: device, library: library)
        let size = 128
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: size, height: size, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .shared
        let input = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var fixture = [Float16](repeating: 0, count: size * size * 4)
        for y in 0..<size { for x in 0..<size {
            let u = Float(x) / Float(size - 1), v = Float(y) / Float(size - 1)
            let distance = hypot(u - 0.5, (v - 0.5) * 1.2)
            let alpha = max(0, min(1, (0.47 - distance) * 128))
            let stripe: Float = (x / 9 + y / 11) % 2 == 0 ? 1 : 0.15
            let offset = (y * size + x) * 4
            fixture[offset] = Float16(u * stripe * alpha)
            fixture[offset + 1] = Float16(v * stripe * alpha)
            fixture[offset + 2] = Float16((1 - u * v) * alpha)
            fixture[offset + 3] = Float16(alpha)
        } }
        fixture.withUnsafeBytes { bytes in
            input.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: size * 8)
        }
        // A second, differently colored layer exercises real reference-texture
        // bindings (color transfer, displacement and background-reading passes).
        let reference = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        var referencePixels=fixture
        for index in stride(from:0,to:fixture.count,by:4) {
            referencePixels[index]=fixture[index+2];referencePixels[index+1]=fixture[index];referencePixels[index+2]=fixture[index+1]
        }
        referencePixels.withUnsafeBytes { reference.replace(region:MTLRegionMake2D(0,0,size,size),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:size*8) }
        func render(_ definition: ReferenceFragmentDefinition, missing: Bool = false, time: Double = 0.4, animate: Bool = false,
                    overrides: [String:ParamValue] = [:]) throws -> [Float16] {
            let pool = TexturePool(device: device)
            let buffer = try XCTUnwrap(queue.makeCommandBuffer())
            var effect = definition.definition.makeInstance()
            if missing { effect.params.removeAll() }
            effect.params.merge(overrides,uniquingKeysWith: { _,new in new })
            if animate, let parameter = definition.parameters.first(where: {
                let key = $0.definition.id.lowercased()
                return key.contains("phase") || key.contains("evolution") || key.hasPrefix("progress")
            }) {
                let pd = parameter.definition
                if case .number(let low, let high, _, _) = pd.kind {
                    let initial = pd.defaultValue.number(at: 0)
                    let end = min(high, max(low, initial + (high - low) * 0.05))
                    var curve = Animated(initial)
                    curve.insertKeyframe(Keyframe(time: 0, value: initial))
                    curve.insertKeyframe(Keyframe(time: 2, value: end))
                    effect.params[pd.id] = .number(curve)
                }
            }
            let context = EffectContext(gpu: gpu, cb: buffer, input: input, effect: effect, time: time,
                unit: 1, pool: pool, reference:reference, layerPixels: SIMD2(Double(size), Double(size)), compositionPixels: SIMD2(Double(size), Double(size)))
            let output = gpu.referenceFragments.render(definition, context)
            let readback = try XCTUnwrap(device.makeBuffer(length: size * size * 8, options: .storageModeShared))
            let blit = try XCTUnwrap(buffer.makeBlitCommandEncoder())
            blit.copy(from: output, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: size, height: size, depth: 1), to: readback, destinationOffset: 0,
                destinationBytesPerRow: size * 8, destinationBytesPerImage: size * size * 8)
            blit.endEncoding()
            buffer.commit(); buffer.waitUntilCompleted()
            XCTAssertEqual(buffer.status, .completed, definition.name + ": " + (buffer.error?.localizedDescription ?? ""))
            return Array(UnsafeBufferPointer(start: readback.contents().assumingMemoryBound(to: Float16.self), count: size * size * 4))
        }
        let folder = URL(fileURLWithPath: "/tmp/awi-reference-review")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var report: [[String: Any]] = []
        for (index, definition) in ReferenceFragmentCatalog.all.enumerated() where index % 8 == part {
            try autoreleasepool {
                let output = try render(definition)
                let old = try render(definition, missing: true)
                XCTAssertEqual(output, old, definition.name + " has incorrect missing-parameter fallbacks")
                XCTAssertTrue(output.allSatisfy { Float($0).isFinite }, definition.name + " emitted invalid values")
                let difference = zip(output, fixture).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(output.count)
                report.append(["id": definition.id, "name": definition.name, "defaultDifference": difference,
                    "parameters": definition.parameters.map { $0.definition.id }])
                func image(_ output: [Float16]) throws -> CGImage {
                    var bytes = [UInt8](repeating: 0, count: size * size * 4)
                    for pixel in 0..<(size * size) {
                        let alpha = max(0, min(1, Float(output[pixel * 4 + 3])))
                        for channel in 0..<3 {
                            let raw = alpha > 0.00001 ? Float(output[pixel * 4 + channel]) / alpha : 0
                            let value = raw.isFinite ? raw : 0
                            bytes[pixel * 4 + channel] = UInt8((max(0, min(1, value)) * 255).rounded())
                        }
                        bytes[pixel * 4 + 3] = UInt8((alpha * 255).rounded())
                    }
                    let provider = try XCTUnwrap(CGDataProvider(data: Data(bytes) as CFData))
                    return try XCTUnwrap(CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                        decode: nil, shouldInterpolate: true, intent: .defaultIntent))
                }
                try UIImage(cgImage: image(output)).pngData()?.write(to: folder.appendingPathComponent(definition.id + ".png"))
                if ReferenceFragmentCatalog.publicCandidates.contains(where: { $0.id == definition.id }) {
                    var preview: [String:ParamValue] = [:]
                    // Neutral utilities need an intentional setting in review
                    // images, while missing-default checks above stay untouched.
                    if definition.id == "awi.amref.ec2cdadc6c8df" { preview["hue"] = .choice(2);preview["sat"] = .choice(0) }
                    if definition.id == "awi.amref.e5ad5e1e9a0fb" { preview["flickerThreshold"] = .number(Animated(0)) }
                    var instance=definition.definition.makeInstance();instance.params.merge(preview,uniquingKeysWith:{_,new in new})
                    try JSONEncoder().encode(instance).write(to:folder.appendingPathComponent(definition.id+"-review-settings.json"))
                    let configured=try render(definition,overrides:preview)
                    try UIImage(cgImage:image(configured)).pngData()?.write(to:folder.appendingPathComponent(definition.id+"-configured.png"))
                    let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
                        folder.appendingPathComponent(definition.id + "-motion.gif") as CFURL,
                        UTType.gif.identifier as CFString, 8, nil))
                    CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
                    for frame in 0..<8 {
                        let pixels = try render(definition, time: Double(frame) / 4, animate: true, overrides:preview)
                        CGImageDestinationAddImage(destination, try image(pixels),
                            [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.25]] as CFDictionary)
                    }
                    XCTAssertTrue(CGImageDestinationFinalize(destination), definition.name)
                    var controlReport: [[String:Any]] = []
                    for parameter in definition.parameters {
                        guard case .number(let low,let high,_,_) = parameter.definition.kind else { continue }
                        let key=parameter.definition.id
                        var configured=preview
                        if definition.id == "awi.amref.e8404b5764d4f", key == "seed" { configured["strength"] = .number(Animated(0.35)) }
                        if definition.id == "awi.amref.ec88108d754e8" {
                            if key == "density" { configured["preset"] = .choice(5) }
                            if ["colorR","colorG","colorB"].contains(key) { configured["colorMode"] = .choice(1) }
                        }
                        if definition.id == "awi.amref.e7b0d60717ad7", key == "quality" { configured["solidity"] = .number(Animated(0.35)) }
                        let base=try render(definition,overrides:configured)
                        var difference=0.0
                        for fraction in [0.02,0.6] {
                            var variant=configured;variant[key] = .number(Animated(low+(high-low)*fraction))
                            let changed=try render(definition,overrides:variant)
                            difference=max(difference,zip(base,changed).reduce(0.0){ $0+abs(Double($1.0)-Double($1.1)) }/Double(base.count))
                        }
                        controlReport.append(["parameter":key,"observedDifference":difference,"requiresModeReview":difference<0.00001])
                    }
                    try JSONSerialization.data(withJSONObject:controlReport,options:[.prettyPrinted,.sortedKeys])
                        .write(to:folder.appendingPathComponent(definition.id+"-controls.json"))
                }
            }
        }
        XCTAssertTrue(gpu.referenceFragments.diagnostics.isEmpty, "Reference pipeline failures: \(gpu.referenceFragments.diagnostics)")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("report-\(part).json"))
    }
    func testReferenceShadersPart0() throws { try audit(part: 0) }
    func testReferenceShadersPart1() throws { try audit(part: 1) }
    func testReferenceShadersPart2() throws { try audit(part: 2) }
    func testReferenceShadersPart3() throws { try audit(part: 3) }
    func testReferenceShadersPart4() throws { try audit(part: 4) }
    func testReferenceShadersPart5() throws { try audit(part: 5) }
    func testReferenceShadersPart6() throws { try audit(part: 6) }
    func testReferenceShadersPart7() throws { try audit(part: 7) }
}
