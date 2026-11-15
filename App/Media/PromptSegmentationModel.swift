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

    init(modelDirectory: URL? = nil) throws {
        // Match the reference Core ML demo's supported CPU/GPU execution path.
        let configuration = MLModelConfiguration(); configuration.computeUnits = .cpuAndGPU
        #if targetEnvironment(simulator)
        // The simulator's virtual GPU returned constant-zero mask tensors for these
        // models. Exercise the same network on CPU there; devices keep GPU execution.
        configuration.computeUnits = .cpuOnly
        #endif
        func load(_ name: String) throws -> MLModel {
            guard let url = modelDirectory?.appendingPathComponent(name + ".mlmodelc") ?? Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                throw InteractiveSelection.SelectionError.invalidImage
            }
            return try MLModel(contentsOf: url, configuration: configuration)
        }
        encoder = try load("SAM2_1TinyImageEncoderFLOAT16")
        promptEncoder = try load("SAM2_1TinyPromptEncoderFLOAT16")
        decoder = try load("SAM2_1TinyMaskDecoderFLOAT16")
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
        let coordinateType = promptEncoder.modelDescription.inputDescriptionsByName["points"]?.multiArrayConstraint?.dataType ?? .float32
        let labelType = promptEncoder.modelDescription.inputDescriptionsByName["labels"]?.multiArrayConstraint?.dataType ?? .int32
        let coordinates = try MLMultiArray(shape: [1, NSNumber(value: prompts.count), 2], dataType: coordinateType)
        let labels = try MLMultiArray(shape: [1, NSNumber(value: prompts.count)], dataType: labelType)
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
        guard let masks = (output.featureValue(for: "low_res_masks_to_fp32") ?? output.featureValue(for: "low_res_masks"))?.multiArrayValue,
              let scores = (output.featureValue(for: "scores_to_fp32") ?? output.featureValue(for: "scores"))?.multiArrayValue else {
            throw InteractiveSelection.SelectionError.modelOutput("Decoder output keys: \(output.featureNames)")
        }
        guard masks.shape.count == 4 else { throw InteractiveSelection.SelectionError.modelOutput("Mask shape: \(masks.shape)") }
        let count = masks.shape[1].intValue, height = masks.shape[2].intValue, width = masks.shape[3].intValue
        // Use Core ML's typed tensor bridge for a contiguous view of GPU-backed FP16 output.
        let logits = MLShapedArray<Float>(converting: masks).scalars
        guard logits.count == count * width * height, logits.allSatisfy(\.isFinite) else {
            throw InteractiveSelection.SelectionError.modelOutput("Invalid mask tensor values")
        }
        let candidates = (0..<min(count, scores.count)).map { index in
            var bytes = [UInt8](repeating: 0, count: width * height)
            for y in 0..<height { for x in 0..<width {
                let logit = logits[index * width * height + y * width + x]
                let probability = 1 / (1 + exp(-min(30, max(-30, logit))))
                bytes[y * width + x] = UInt8(min(255, max(0, probability * 255)))
            } }
            return SegmentationCandidate(bytes: bytes, width: width, height: height, score: scores[index].floatValue)
        }
        #if DEBUG
        let ranges = candidates.map { candidate in "score=\(candidate.score) alpha=\(candidate.bytes.min() ?? 0)...\(candidate.bytes.max() ?? 0)" }
        print("SAM2 mask shape \(masks.shape), logit range \(logits.min() ?? 0)...\(logits.max() ?? 0), \(ranges)")
        #endif
        return candidates
    }
}
