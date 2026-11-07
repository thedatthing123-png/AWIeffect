import Foundation

extension Animated {
    mutating func pasteShapeKeys(_ source: Self, delta: Double) {
        for original in source.keyframes {
            var key = original; key.id = UUID(); key.time += delta; insertKeyframe(key)
        }
    }
}

extension ShapeComponent {
    mutating func pasteKeys(_ s: Self, delta d: Double) {
        path.pasteShapeKeys(s.path, delta: d); size.pasteShapeKeys(s.size, delta: d)
        roundness.pasteShapeKeys(s.roundness, delta: d); sides.pasteShapeKeys(s.sides, delta: d)
        innerRatio.pasteShapeKeys(s.innerRatio, delta: d); position.pasteShapeKeys(s.position, delta: d)
        scale.pasteShapeKeys(s.scale, delta: d); rotation.pasteShapeKeys(s.rotation, delta: d)
        opacity.pasteShapeKeys(s.opacity, delta: d); fill.pasteShapeKeys(s.fill, delta: d)
        stroke.pasteKeys(s.stroke, delta: d)
        if let g = s.fillGradient { if fillGradient == nil { fillGradient = g.withoutKeys }; fillGradient?.pasteKeys(g, delta: d) }
        if let g = s.strokeGradient { if strokeGradient == nil { strokeGradient = g.withoutKeys }; strokeGradient?.pasteKeys(g, delta: d) }
        if let o = s.ops { if ops == nil { ops = ShapeOps() }; ops?.pasteKeys(o, delta: d) }
    }
}
extension ShapeStroke {
    mutating func pasteKeys(_ s: Self, delta d: Double) {
        color.pasteShapeKeys(s.color, delta: d); width.pasteShapeKeys(s.width, delta: d)
        trimStart.pasteShapeKeys(s.trimStart, delta: d); trimEnd.pasteShapeKeys(s.trimEnd, delta: d)
        trimOffset.pasteShapeKeys(s.trimOffset, delta: d)
    }
}
extension ShapeGradient {
    var withoutKeys: Self {
        var g = self; g.start.keyframes = []; g.end.keyframes = []; g.first.keyframes = []; g.last.keyframes = []; return g
    }
    mutating func pasteKeys(_ s: Self, delta d: Double) {
        start.pasteShapeKeys(s.start, delta: d); end.pasteShapeKeys(s.end, delta: d)
        first.pasteShapeKeys(s.first, delta: d); last.pasteShapeKeys(s.last, delta: d)
    }
}
extension ShapeOps {
    mutating func pasteKeys(_ s: Self, delta d: Double) {
        func put<V>(_ dest: inout Animated<V>?, _ src: Animated<V>?) where V: Interpolatable {
            guard let src, src.isAnimated else { return }
            var value = dest ?? Animated(src.staticValue); value.pasteShapeKeys(src, delta: d); dest = value
        }
        put(&offset, s.offset); put(&pucker, s.pucker); put(&roundCorners, s.roundCorners)
        if let src = s.twist {
            if twist == nil { twist = TwistOp() }
            twist?.angle.pasteShapeKeys(src.angle, delta: d); twist?.center.pasteShapeKeys(src.center, delta: d)
        }
        if let src = s.repeater {
            if repeater == nil { repeater = RepeaterOp() }
            repeater?.copies.pasteShapeKeys(src.copies, delta: d); repeater?.position.pasteShapeKeys(src.position, delta: d)
            repeater?.scale.pasteShapeKeys(src.scale, delta: d); repeater?.rotation.pasteShapeKeys(src.rotation, delta: d)
            repeater?.startOpacity.pasteShapeKeys(src.startOpacity, delta: d); repeater?.endOpacity.pasteShapeKeys(src.endOpacity, delta: d)
        }
        if let src = s.wiggle {
            if wiggle == nil { wiggle = WiggleOp() }
            wiggle?.size.pasteShapeKeys(src.size, delta: d); wiggle?.detail.pasteShapeKeys(src.detail, delta: d); wiggle?.speed.pasteShapeKeys(src.speed, delta: d)
        }
        if let src = s.zigzag {
            if zigzag == nil { zigzag = ZigZagOp() }
            zigzag?.size.pasteShapeKeys(src.size, delta: d); zigzag?.ridges.pasteShapeKeys(src.ridges, delta: d)
        }
    }
}
