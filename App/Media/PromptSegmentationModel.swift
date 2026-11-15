import Foundation
import CoreML
import CoreGraphics
import CoreVideo

struct SegmentationPrompt {
    let point: CGPoint // normalized, top-left origin
    let positive: Bool
}

struct SegmentationCandidate {
    let bytes: [UInt8]
    let width: Int
    let height: Int
    let score: Float
}

/// Apple/Hugging Face's SAM 2 Core ML interface. SAM 2 stretches the image to a
/// square, unlike SAM 1's letterboxing. Points follow exactly the same transform.
/// Owned exclusively by InteractiveSelection's actor.
final class PromptSegmentationModel {
    private let encoder: MLModel
    private let promptEncoder: MLModel
    private let decoder: MLModel
    private var features: [String: Any] = [:]

    init() throws {
        let configuration = MLModelConfiguration(); configuration.computeUnits = .all
        func load(_ name: String) throws -> MLModel {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                throw InteractiveSelection.SelectionError.invalidImage
            }
            return try MLModel(contentsOf: url, configuration: configuration)
        }
        encoder = try load("SAM2TinyImageEncoderFLOAT16")
        promptEncoder = try load("SAM2TinyPromptEncoderFLOAT16")
        decoder = try load("SAM2TinyMaskDecoderFLOAT16")
    }

    func setImage(_ image: CGImage) throws {
        features = [:]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 1024, 1024, kCVPixelFormatType_32BGRA,
                                        [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { throw InteractiveSelection.SelectionError.invalidImage }
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1024, height: 1024, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(buffer, []); throw InteractiveSelection.SelectionError.invalidImage
        }
        context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        let output = try encoder.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)]))
        for name in ["image_embedding", "feats_s0", "feats_s1"] {
            guard let value = output.featureValue(for: name)?.multiArrayValue else { throw InteractiveSelection.SelectionError.invalidImage }
            features[name] = value
        }
    }

    func predict(_ prompts: [SegmentationPrompt]) throws -> [SegmentationCandidate] {
        guard !features.isEmpty, !prompts.isEmpty, prompts.count <= 14 else { throw InteractiveSelection.SelectionError.invalidImage }
        let coordinates = try MLMultiArray(shape: [1, NSNumber(value: prompts.count), 2], dataType: .float16)
        let labels = try MLMultiArray(shape: [1, NSNumber(value: prompts.count)], dataType: .float16)
        for (index, prompt) in prompts.enumerated() {
            coordinates[index * 2] = NSNumber(value: Double(prompt.point.x) * 1024)
            coordinates[index * 2 + 1] = NSNumber(value: Double(prompt.point.y) * 1024)
            labels[index] = NSNumber(value: prompt.positive ? 1 : 0)
        }
        let promptFeatures = try promptEncoder.prediction(from: MLDictionaryFeatureProvider(dictionary: ["points": coordinates, "labels": labels]))
        var input = features
        guard let sparse = promptFeatures.featureValue(for: "sparse_embeddings")?.multiArrayValue,
              let dense = promptFeatures.featureValue(for: "dense_embeddings")?.multiArrayValue else { throw InteractiveSelection.SelectionError.invalidImage }
        input["sparse_embedding"] = sparse; input["dense_embedding"] = dense
        let output = try decoder.prediction(from: MLDictionaryFeatureProvider(dictionary: input))
        guard let masks = output.featureValue(for: "low_res_masks")?.multiArrayValue,
              let scores = output.featureValue(for: "scores")?.multiArrayValue,
              masks.shape.count == 4 else { throw InteractiveSelection.SelectionError.noRegion }
        let count = masks.shape[1].intValue, height = masks.shape[2].intValue, width = masks.shape[3].intValue
        let strides = masks.strides.map(\.intValue)
        // Respect Core ML's actual tensor strides, including FP16 alignment padding.
        func value(_ offset: Int) -> Float {
            if masks.dataType == .float16 { return Float(Float16(bitPattern: masks.dataPointer.assumingMemoryBound(to: UInt16.self)[offset])) }
            return masks.dataPointer.assumingMemoryBound(to: Float.self)[offset]
        }
        return (0..<min(count, scores.count)).map { index in
            var bytes = [UInt8](repeating: 0, count: width * height)
            for y in 0..<height { for x in 0..<width {
                let logit = value(index * strides[1] + y * strides[2] + x * strides[3])
                let probability = 1 / (1 + exp(-min(30, max(-30, logit))))
                bytes[y * width + x] = UInt8(min(255, max(0, probability * 255)))
            } }
            return SegmentationCandidate(bytes: bytes, width: width, height: height, score: scores[index].floatValue)
        }
    }
}
