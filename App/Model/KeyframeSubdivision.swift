import Foundation

extension Animated {
    /// Insert on the current curve, retaining its timing shape instead of restarting an ease at the new key.
    mutating func insertSampledKey(at time: Double) {
        guard !hasKeyframe(at: time) else { return }
        let sample = value(at: time)
        guard let k = keyframes.indices.dropLast().first(where: { keyframes[$0].time < time && time < keyframes[$0 + 1].time }) else {
            insertKeyframe(Keyframe(time: time, value: sample)); return
        }
        let a = keyframes[k], b = keyframes[k + 1]
        let x = (time - a.time) / (b.time - a.time)
        var key = Keyframe(time: time, value: sample, interpolation: a.interpolation)
        key.reversedSegment = a.reversedSegment
        if let curve = a.curve, a.interpolation == .bezier {
            let start = curve.window?.start ?? 0, end = curve.window?.end ?? 1
            let split = start + (end - start) * (a.reversedSegment == true ? 1 - x : x)
            var left = curve, right = curve
            left.window = .init(start: a.reversedSegment == true ? split : start, end: a.reversedSegment == true ? end : split)
            right.window = .init(start: a.reversedSegment == true ? start : split, end: a.reversedSegment == true ? split : end)
            keyframes[k].curve = left; key.curve = right
        } else if a.interpolation == .bezier {
            var lo = 0.0, hi = 1.0
            for _ in 0..<48 {
                let u = (lo + hi) / 2
                if BezierTiming.bezier(u, 0, a.easeOut.x, b.easeIn.x, 1) < x { lo = u } else { hi = u }
            }
            let u = (lo + hi) / 2
            let p0 = Vec2.zero, p1 = Vec2(a.easeOut.x,a.easeOut.y), p2 = Vec2(b.easeIn.x,b.easeIn.y), p3 = Vec2(1,1)
            let q0 = Vec2.lerp(p0,p1,u), q1 = Vec2.lerp(p1,p2,u), q2 = Vec2.lerp(p2,p3,u)
            let r0 = Vec2.lerp(q0,q1,u), r1 = Vec2.lerp(q1,q2,u), split = Vec2.lerp(r0,r1,u)
            if abs(split.y) > 1e-9 && abs(1 - split.y) > 1e-9 {
                keyframes[k].easeOut = EaseHandle(x: q0.x / split.x,y: q0.y / split.y)
                key.easeIn = EaseHandle(x: r0.x / split.x,y: r0.y / split.y)
                key.easeOut = EaseHandle(x: (r1.x - split.x) / (1 - split.x),y: (r1.y - split.y) / (1 - split.y))
                keyframes[k + 1].easeIn = EaseHandle(x: (q2.x - split.x) / (1 - split.x),y: (q2.y - split.y) / (1 - split.y))
            }
        }
        insertKeyframe(key)
    }
}
