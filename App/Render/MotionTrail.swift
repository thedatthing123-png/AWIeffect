import Foundation
import Metal
import simd

extension EffectRegistry {
    static let motionTrail = EffectDefinition(
        id: MotionTrail.id, name: "Trail", category: .motion, aeMatchNames: [],
        summary: "A continuous ribbon behind a moving layer, with adjustable width, color and fade.",
        params: [
            .number("lifetime", "Lifetime", 0.45, 0.02, 3, step: 0.01, unit: " s"),
            .number("length", "Maximum Length", 0, 0, 6000, unit: " px"),
            .number("headWidth", "Head Width", 24, 0, 1000, unit: " px"),
            .number("tailWidth", "Tail Width", 0, 0, 1000, unit: " px"),
            .number("taper", "Taper Curve", 1, 0.15, 5, step: 0.05),
            .color("headColor", "Head Color", RGBA(0.83, 0.69, 1)),
            .color("tailColor", "Tail Color", RGBA(0.47, 0.20, 0.94)),
            .number("headAlpha", "Head Opacity", 90, 0, 100, unit: "%"),
            .number("tailAlpha", "Tail Opacity", 0, 0, 100, unit: "%"),
            .number("offsetX", "Attachment X", 0, -2048, 2048, unit: " px"),
            .number("offsetY", "Attachment Y", 0, -2048, 2048, unit: " px")
        ], stage: .motionTrail)
}

enum MotionTrail {
    static let id = "awi.motionTrail"

    static func isVisible(_ effect: EffectInstance) -> Bool {
        effect.typeID == id && effect.isEnabled && !EffectStackR4.isMuted(effect)
    }

    // Match the Metal vertex layout. Side interpolates across the ribbon for edge antialiasing.
    private struct Vertex {
        var positionAndSide: SIMD4<Float>
        var color: SIMD4<Float>
    }

    private struct Sample {
        var position: SIMD2<Double>
        var age: Double
    }

    static func pipeline(device: MTLDevice, library: MTLLibrary) throws -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "motionTrailVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "motionTrailFragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = Renderer.compFormat
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func encode(_ effect: EffectInstance, layer: Layer, project: Project, camera: CameraState,
                       time: Double, scale: Double, opacity: Double, target: MTLTexture,
                       buffer: MTLCommandBuffer, pipeline: MTLRenderPipelineState) {
        func number(_ id: String, _ limits: ClosedRange<Double>) -> Double {
            let value = effect.number(id, time)
            return value.isFinite ? min(limits.upperBound, max(limits.lowerBound, value)) : limits.lowerBound
        }
        let lifetime = number("lifetime", 0.02...3)
        let span = min(lifetime, time - layer.inPoint)
        let mix = EffectStackR4.mix(effect, time) / 100 * min(1, opacity)
        guard span.isFinite, span > 0, mix > 0 else { return }

        let maxDistance = number("length", 0...6000) * scale
        let offset = Vec2(number("offsetX", -2048...2048), number("offsetY", -2048...2048))
        let count = max(2, min(48, Int(ceil(span * 90))))
        let bounds = SIMD2(Double(target.width), Double(target.height))
        let coordinateLimit = max(bounds.x, bounds.y) * 16
        var path: [Sample] = []
        var distance = 0.0
        var reachedLengthLimit = false
        for index in 0...count {
            let elapsed = span * Double(index) / Double(count)
            let t = time - elapsed
            var posed = layer
            if let parent = layer.parentID, let inherited = Renderer.parentAffine(parent, in: project, time: t) {
                let position = layer.transform.position.value(at: t)
                let point = inherited.m * SIMD3(position.x, position.y, 1)
                let size = layer.transform.scale.value(at: t)
                posed.transform.position = Animated(Vec2(point.x, point.y))
                posed.transform.rotation = Animated(layer.transform.rotation.value(at: t) + inherited.rot)
                posed.transform.scale = Animated(Vec2(size.x * inherited.scale.x, size.y * inherited.scale.y))
                posed.transform.positionZ = Animated(layer.transform.positionZ.value(at: t) + Renderer.chainZ(parent, in: project, time: t))
            }
            let anchor = posed.transform.anchor.value(at: t) + offset
            let transform = Renderer.placementMatrix(posed, camera: camera, time: t, renderScale: scale)
            let projected = transform * SIMD3(anchor.x, anchor.y, 1)
            guard projected.z > 0.01 else { break }
            let point = SIMD2(projected.x, projected.y) / projected.z
            guard abs(point.x) < coordinateLimit, abs(point.y) < coordinateLimit else { break }
            let age = elapsed / lifetime
            if let last = path.last {
                let length = simd_distance(last.position, point)
                if length < 0.05 { continue }
                if maxDistance > 0, distance + length >= maxDistance {
                    let fraction = (maxDistance - distance) / length
                    path.append(Sample(position: last.position + (point - last.position) * fraction,
                                       age: last.age + (age - last.age) * fraction))
                    reachedLengthLimit = true
                    break
                }
                distance += length
            }
            path.append(Sample(position: point, age: age))
        }
        guard path.count > 1 else { return }

        let headWidth = number("headWidth", 0...1000) * scale / 2
        let tailWidth = number("tailWidth", 0...1000) * scale / 2
        let tailAge = reachedLengthLimit ? max(0.01, path[path.count - 1].age) : 1
        let taper = number("taper", 0.15...5)
        let head = effect.color("headColor", time).simd, tail = effect.color("tailColor", time).simd
        let headAlpha = number("headAlpha", 0...100) / 100
        let tailAlpha = number("tailAlpha", 0...100) / 100
        var vertices: [Vertex] = []
        for index in path.indices {
            let sample = path[index]
            let incoming = sample.position - path[max(0, index - 1)].position
            let outgoing = path[min(path.count - 1, index + 1)].position - sample.position
            let direction = simd_length_squared(outgoing) > 0 ? simd_normalize(outgoing) : simd_normalize(incoming)
            let previous = simd_length_squared(incoming) > 0 ? simd_normalize(incoming) : direction
            let normal = SIMD2(-direction.y, direction.x)
            let blend = normal + SIMD2(-previous.y, previous.x)
            let bisector = simd_length_squared(blend) > 0.01 ? simd_normalize(blend) : normal
            let age = min(1, sample.age / tailAge)
            let radius = headWidth + (tailWidth - headWidth) * pow(age, taper)
            let edge = bisector * (radius / max(0.5, simd_dot(normal, bisector)))
            var color = head + (tail - head) * Float(age)
            color.w *= Float(mix * (headAlpha + (tailAlpha - headAlpha) * age))
            for side in [-1.0, 1.0] {
                let point = (sample.position + edge * side) / bounds
                vertices.append(Vertex(positionAndSide: SIMD4(Float(point.x * 2 - 1), Float(1 - point.y * 2), Float(side), 0),
                                       color: color))
            }
        }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .load
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.setRenderPipelineState(pipeline)
        vertices.withUnsafeBufferPointer { data in
            if let first = data.baseAddress {
                encoder.setVertexBytes(first, length: data.count * MemoryLayout<Vertex>.stride, index: 0)
            }
        }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: vertices.count)
        encoder.endEncoding()
    }
}
