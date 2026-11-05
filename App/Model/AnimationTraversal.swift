import Foundation

/// The single inventory used by timeline indicators, key movement and clip movement.
struct AnimationTraversal {
    enum Operation { case inspect, retime(Double, Double), moveTimes([Double], Double), shift(Double), scaleTime(Double, Double), reverse(Double) }
    var operation: Operation
    var times: [Double] = []
    var markers: [Double: UUID] = [:]
    mutating func apply<V: Interpolatable>(_ value: inout Animated<V>) {
        switch operation {
        case .reverse(let sum): value.reverseKeys(around: sum)
        case .inspect:
            times += value.keyframeTimes
            for key in value.keyframes {
                let time = (key.time * 10000).rounded() / 10000
                if markers[time] == nil { markers[time] = key.id }
            }
        case .moveTimes(let selected, let delta):
            for i in value.keyframes.indices where selected.contains(where: { abs($0 - value.keyframes[i].time) < keyframeTimeEpsilon }) {
                value.keyframes[i].time += delta
            }
            value.keyframes.sort { $0.time < $1.time }
        case .retime(let from, let to): value.retime(at: from, to: to)
        case .shift(let dt): value.shift(by: dt)
        case .scaleTime(let origin, let factor):
            for i in value.keyframes.indices { value.keyframes[i].time = origin + (value.keyframes[i].time - origin) * factor }
            value.keyframes.sort { $0.time < $1.time }
        }
    }
    mutating func apply<V: Interpolatable>(_ value: inout Animated<V>?) {
        guard var existing = value else { return }
        apply(&existing); value = existing
    }
}

extension Layer {
    mutating func traverseAnimations(_ visit: inout AnimationTraversal) {
        if let frozen = timeFX?.freezeAt {
            switch visit.operation {
            case .shift(let delta): timeFX?.freezeAt = frozen + delta
            case .scaleTime(let origin, let factor): timeFX?.freezeAt = origin + (frozen - origin) * factor
            case .reverse(let sum): timeFX?.freezeAt = sum - frozen
            default: break
            }
        }
        visit.apply(&transform.anchor)
        visit.apply(&transform.position)
        visit.apply(&transform.scale)
        visit.apply(&transform.rotation)
        visit.apply(&transform.opacity)
        visit.apply(&transform.positionZ)
        visit.apply(&transform.rotationX)
        visit.apply(&transform.rotationY)
        visit.apply(&size)
        visit.apply(&fill)
        visit.apply(&cornerRadius)
        visit.apply(&sides)
        visit.apply(&innerRatio)
        visit.apply(&volume)
        visit.apply(&extrude)
        visit.apply(&timeRemap)
        visit.apply(&path)
        for i in masks.indices {
            visit.apply(&masks[i].path)
            visit.apply(&masks[i].feather)
            visit.apply(&masks[i].opacity)
            visit.apply(&masks[i].expansion)
        }
        if camera != nil {
            visit.apply(&camera!.zoom)
            visit.apply(&camera!.focusDistance)
            visit.apply(&camera!.aperture)
            visit.apply(&camera!.blurLevel)
        }
        if light != nil {
            visit.apply(&light!.color)
            visit.apply(&light!.intensity)
            visit.apply(&light!.coneAngle)
            visit.apply(&light!.coneFeather)
            visit.apply(&light!.falloffRadius)
        }
        if model3D != nil {
            visit.apply(&model3D!.yaw)
            visit.apply(&model3D!.pitch)
            visit.apply(&model3D!.roll)
            visit.apply(&model3D!.color)
            visit.apply(&model3D!.lightAngle)
            visit.apply(&model3D!.lightIntensity)
        }
        for i in effects.indices {
            for key in effects[i].params.keys.sorted() {
                guard let value = effects[i].params[key] else { continue }
                switch value {
                case .number(var a): visit.apply(&a); effects[i].params[key] = .number(a)
                case .point(var a): visit.apply(&a); effects[i].params[key] = .point(a)
                case .color(var a): visit.apply(&a); effects[i].params[key] = .color(a)
                default: break
                }
            }
        }
        if text != nil {
            visit.apply(&text!.fill)
            visit.apply(&text!.tracking)
            visit.apply(&text!.lineSpacing)
            visit.apply(&text!.pathOffset)
            if text!.counter != nil { visit.apply(&text!.counter!.value) }
            for i in text!.animators.indices {
                visit.apply(&text!.animators[i].selector.start)
                visit.apply(&text!.animators[i].selector.end)
                visit.apply(&text!.animators[i].selector.offset)
                visit.apply(&text!.animators[i].selector.amount)
                visit.apply(&text!.animators[i].selector.frequency)
                visit.apply(&text!.animators[i].selector.spread)
                visit.apply(&text!.animators[i].properties.position)
                visit.apply(&text!.animators[i].properties.scale)
                visit.apply(&text!.animators[i].properties.rotation)
                visit.apply(&text!.animators[i].properties.opacity)
                visit.apply(&text!.animators[i].properties.fill)
                visit.apply(&text!.animators[i].properties.tracking)
                visit.apply(&text!.animators[i].properties.skew)
                visit.apply(&text!.animators[i].properties.blur)
                visit.apply(&text!.animators[i].properties.characterOffset)
                visit.apply(&text!.animators[i].properties.rotationX)
                visit.apply(&text!.animators[i].properties.rotationY)
                visit.apply(&text!.animators[i].properties.positionZ)
                visit.apply(&text!.animators[i].properties.outline)
            }
        }
        if shapeOps != nil {
            visit.apply(&shapeOps!.offset)
            visit.apply(&shapeOps!.pucker)
            if shapeOps!.repeater != nil {
                visit.apply(&shapeOps!.repeater!.copies)
                visit.apply(&shapeOps!.repeater!.position)
                visit.apply(&shapeOps!.repeater!.scale)
                visit.apply(&shapeOps!.repeater!.rotation)
                visit.apply(&shapeOps!.repeater!.startOpacity)
                visit.apply(&shapeOps!.repeater!.endOpacity)
            }
            if shapeOps!.wiggle != nil {
                visit.apply(&shapeOps!.wiggle!.size)
                visit.apply(&shapeOps!.wiggle!.detail)
                visit.apply(&shapeOps!.wiggle!.speed)
            }
            if shapeOps!.zigzag != nil {
                visit.apply(&shapeOps!.zigzag!.size)
                visit.apply(&shapeOps!.zigzag!.ridges)
            }
        }
    }
}
