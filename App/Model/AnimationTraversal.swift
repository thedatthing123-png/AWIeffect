import Foundation

/// The single inventory used by timeline indicators, key movement and clip movement.
struct AnimationTraversal {
    enum Operation { case inspect, retime(Double, Double), moveTimes([Double], Double), shift(Double), scaleTime(Double, Double), reverse(Double) }
    var operation: Operation
    var times: [Double] = []
    var markers: [Double: UUID] = [:]
    /// Only this effect's keyframes are visited (keyframe focus while an effect is open).
    var onlyEffect: UUID? = nil
    /// Set by `.moveTimes` when a moved key would land on an unmoved key of the same property. Nothing is removed;
    /// the caller rejects the whole move (moving keys never destroys another key).
    var collided = false
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
            var moved = Set<UUID>()
            for i in value.keyframes.indices where selected.contains(where: { abs($0 - value.keyframes[i].time) < keyframeTimeEpsilon }) {
                value.keyframes[i].time += delta
                moved.insert(value.keyframes[i].id)
            }
            // A key dropped on another key of the same property is a collision: keep both, flag it, the caller rejects.
            let landed = value.keyframes.filter { moved.contains($0.id) }.map(\.time)
            if value.keyframes.contains(where: { k in !moved.contains(k.id) && landed.contains { abs($0 - k.time) < keyframeTimeEpsilon } }) {
                collided = true
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
        if let only = visit.onlyEffect {
            for i in effects.indices where effects[i].id == only { traverseEffect(i, &visit) }
            return
        }
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
        stroke.traverse(&visit)
        if shapeContents != nil {
            for i in shapeContents!.indices { shapeContents![i].component?.traverse(&visit) }
        }
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
        for i in effects.indices { traverseEffect(i, &visit) }
        traverseText(&visit)
    }

    private mutating func traverseEffect(_ i: Int, _ visit: inout AnimationTraversal) {
        do {
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
    }

    private mutating func traverseText(_ visit: inout AnimationTraversal) {
        if text != nil {
            visit.apply(&text!.fill)
            visit.apply(&text!.tracking)
            visit.apply(&text!.lineSpacing)
            visit.apply(&text!.pathOffset)
            if text!.counter != nil { visit.apply(&text!.counter!.value) }
            visit.apply(&text!.baselineShift)
            if text!.style != nil { text!.style!.traverse(&visit) }
            // Real 3D text: depth, bevel, materials and environment keyframes show on the timeline too.
            if var t3 = text!.text3D {
                visit.apply(&t3.extrusion); visit.apply(&t3.bevelSize)
                visit.apply(&t3.environmentIntensity); visit.apply(&t3.environmentRotation)
                for k in 0..<3 {
                    var m = k == 0 ? t3.front : (k == 1 ? t3.bevel : t3.side)
                    visit.apply(&m.color); visit.apply(&m.metalness); visit.apply(&m.roughness); visit.apply(&m.emission)
                    visit.apply(&m.clearcoat); visit.apply(&m.opacity); visit.apply(&m.transmission)
                    if k == 0 { t3.front = m } else if k == 1 { t3.bevel = m } else { t3.side = m }
                }
                text!.text3D = t3
            }
            for i in text!.animators.indices {
                var sels = text!.animators[i].allSelectors
                for k in sels.indices { sels[k].traverse(&visit) }
                text!.animators[i].allSelectors = sels
                text!.animators[i].properties.traverse(&visit)
                if var fx = text!.animators[i].letterEffects {
                    for k in fx.indices { fx[k].traverseParams(&visit) }
                    text!.animators[i].letterEffects = fx
                }
            }
        }
        if shapeOps != nil {
            visit.apply(&shapeOps!.offset)
            visit.apply(&shapeOps!.pucker)
            visit.apply(&shapeOps!.roundCorners)
            if shapeOps!.twist != nil {
                visit.apply(&shapeOps!.twist!.angle)
                visit.apply(&shapeOps!.twist!.center)
            }
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


// MARK: - Text Studio fields (every Animated value, so keyframe tools see them)

extension TextSelector {
    mutating func traverse(_ visit: inout AnimationTraversal) {
        visit.apply(&start)
        visit.apply(&end)
        visit.apply(&offset)
        visit.apply(&amount)
        visit.apply(&frequency)
        visit.apply(&spread)
        visit.apply(&easeHighAnim)
        visit.apply(&easeLowAnim)
        visit.apply(&minAmountAnim)
        visit.apply(&maxAmountAnim)
        visit.apply(&seedAnim)
        visit.apply(&beatAttack)
        visit.apply(&beatDecay)
    }
}

extension TextAnimatorProperties {
    mutating func traverse(_ visit: inout AnimationTraversal) {
        visit.apply(&position)
        visit.apply(&scale)
        visit.apply(&rotation)
        visit.apply(&opacity)
        visit.apply(&fill)
        visit.apply(&tracking)
        visit.apply(&skew)
        visit.apply(&blur)
        visit.apply(&characterOffset)
        visit.apply(&rotationX)
        visit.apply(&rotationY)
        visit.apply(&positionZ)
        visit.apply(&outline)
        visit.apply(&anchor)
        visit.apply(&fillOpacity)
        visit.apply(&strokeWidth)
        visit.apply(&strokeColor)
        visit.apply(&baselineShift)
        visit.apply(&glow)
        visit.apply(&hueShift)
        visit.apply(&directionalBlur)
        visit.apply(&directionalBlurAngle)
        visit.apply(&scramble)
        visit.apply(&lineSpacing)
    }
}

extension TextStyleStack {
    mutating func traverse(_ visit: inout AnimationTraversal) {
        for i in fills.indices {
            for k in fills[i].colors.indices { visit.apply(&fills[i].colors[k]) }
            visit.apply(&fills[i].angle)
            visit.apply(&fills[i].opacity)
            visit.apply(&fills[i].radialScale)
        }
        for i in strokes.indices {
            visit.apply(&strokes[i].color)
            visit.apply(&strokes[i].width)
            visit.apply(&strokes[i].opacity)
        }
        for i in shadows.indices {
            visit.apply(&shadows[i].color)
            visit.apply(&shadows[i].opacity)
            visit.apply(&shadows[i].angle)
            visit.apply(&shadows[i].distance)
            visit.apply(&shadows[i].blur)
        }
        if glow != nil {
            visit.apply(&glow!.color)
            visit.apply(&glow!.radius)
            visit.apply(&glow!.intensity)
        }
    }
}

extension EffectInstance {
    /// Visits this effect's animated parameters (letter effects inside text animators).
    mutating func traverseParams(_ visit: inout AnimationTraversal) {
        for key in params.keys.sorted() {
            guard let value = params[key] else { continue }
            switch value {
            case .number(var a): visit.apply(&a); params[key] = .number(a)
            case .point(var a): visit.apply(&a); params[key] = .point(a)
            case .color(var a): visit.apply(&a); params[key] = .color(a)
            default: break
            }
        }
    }
}
