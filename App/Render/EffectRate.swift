import Foundation

/// The integral of a rate curve. Each sample depends only on the authored
/// curve and requested time, so seeking and export share the same phase.
enum EffectRate {
    static func phase(_ effect: EffectInstance, key: String, time: Double,
                      range: ClosedRange<Double>, fallback: Double = 0, origin: Double = 0) -> Double {
        let setting = effect.value(key)
        func rate(_ t: Double) -> Double {
            min(range.upperBound, max(range.lowerBound, setting?.number(at: t) ?? fallback))
        }
        guard case .number(let animation)? = setting, animation.keyframes.count > 1, time != origin else {
            return (time - origin) * rate(time)
        }
        let start = min(origin, time), end = max(origin, time)
        var cursor = start, total = 0.0
        func integrate(to upper: Double) -> Double {
            // Four-point Gauss–Legendre. Interior samples also preserve hold
            // keys without sampling the value jump on a segment boundary.
            let half = (upper - cursor) / 2
            let mid = cursor + half
            return half * (0.6521451549 * (rate(mid - 0.3399810436 * half) + rate(mid + 0.3399810436 * half))
                         + 0.3478548451 * (rate(mid - 0.8611363116 * half) + rate(mid + 0.8611363116 * half)))
        }
        for key in animation.keyframes {
            if key.time <= cursor { continue }
            if key.time >= end { break }
            total += integrate(to: key.time)
            cursor = key.time
        }
        total += integrate(to: end)
        return time < origin ? -total : total
    }
}
