import Foundation
import SwiftUI

/// Feature "plugins" built in (the kind of AE scripts editors install for workflow, not looks):
/// Flow-style easing presets, Motion 2-style Excite (inertial bounce), Loop (loopOut cycle / ping-pong),
/// anchor-point grid, and Sure Target-style camera aim.
extension EditorState {
    enum EasePreset: String, CaseIterable, Identifiable {
        case easyEase = "Easy Ease", easeOut = "Ease Out (fast → slow)", easeIn = "Ease In (slow → fast)", strong = "Strong Ease", linear = "Linear"
        var id: String { rawValue }
        var handles: (out: EaseHandle, into: EaseHandle, interp: Interpolation) {
            switch self {
            case .easyEase: return (.easyOut, .easyIn, .bezier)
            case .easeOut: return (EaseHandle(x: 0.1, y: 0.9), EaseHandle(x: 0.3, y: 1), .bezier)
            case .easeIn: return (EaseHandle(x: 0.7, y: 0), EaseHandle(x: 0.9, y: 0.1), .bezier)
            case .strong: return (EaseHandle(x: 0.8, y: 0), EaseHandle(x: 0.2, y: 1), .bezier)
            case .linear: return (.linearOut, EaseHandle(x: 2.0 / 3.0, y: 2.0 / 3.0), .linear)
            }
        }
    }

    /// Applies an easing curve to every transform keyframe of the selected layer (Flow / Ease and Wizz style).
    func applyEase(_ e: EasePreset) {
        guard selectedIndex != nil else { return }
        let h = e.handles
        func ease<V: Interpolatable>(_ a: inout Animated<V>) {
            for k in a.keyframes.indices { a.keyframes[k].interpolation = h.interp; a.keyframes[k].easeOut = h.out; a.keyframes[k].easeIn = h.into }
        }
        mutate("Ease: \(e.rawValue)") { p in
            guard let i = self.selectedIndex else { return }
            ease(&p.layers[i].transform.position); ease(&p.layers[i].transform.scale); ease(&p.layers[i].transform.rotation)
            ease(&p.layers[i].transform.opacity); ease(&p.layers[i].transform.anchor)
            ease(&p.layers[i].transform.rotationX); ease(&p.layers[i].transform.rotationY); ease(&p.layers[i].transform.positionZ)
        }
    }

    private var animatedTransformKeys: [PropertyKey] {
        guard let l = selectedLayer else { return [] }
        var k: [PropertyKey] = []
        if l.transform.position.isAnimated { k.append(.position) }
        if l.transform.scale.isAnimated { k.append(.scale) }
        if l.transform.rotation.isAnimated { k.append(.rotation) }
        if l.transform.opacity.isAnimated { k.append(.opacity) }
        return k
    }

    /// Motion 2 "Excite": springy overshoot after every keyframe (inertial bounce expression).
    func applyExcite(amplitude: Double = 0.06, frequency: Double = 2.4, decay: Double = 5) {
        let keys = animatedTransformKeys
        guard let l = selectedLayer, !keys.isEmpty else { return }
        for key in keys {
            let times = keyTimes(l, key)
            let src = """
            var k = [\(times.map { String(format: "%.4f", $0) }.joined(separator: ","))];
            var n = -1; for (var i = 0; i < k.length; i++) { if (k[i] <= time) n = i; }
            if (n < 1) { value } else {
              var t = time - k[n]; var dt = 0.02;
              var v = div(sub(valueAtTime(k[n] - 0.001), valueAtTime(k[n] - 0.001 - dt)), dt);
              add(value, mul(v, \(amplitude) * Math.sin(t * \(frequency) * 2 * Math.PI) / Math.exp(t * \(decay))));
            }
            """
            setExpression(key, src)
        }
    }

    /// AE loopOut: repeat the keyframed animation forever (cycle) or back and forth (ping-pong).
    func applyLoop(pingPong: Bool) {
        let keys = animatedTransformKeys
        guard let l = selectedLayer, !keys.isEmpty else { return }
        for key in keys {
            let times = keyTimes(l, key)
            guard let a = times.first, let b = times.last, b > a else { continue }
            let span = b - a
            let src = pingPong
                ? "if (time <= \(b)) { value } else { var c = Math.floor((time - \(a)) / \(span)); var f = ((time - \(a)) % \(span)); valueAtTime(c % 2 == 0 ? \(a) + f : \(b) - f) }"
                : "if (time <= \(b)) { value } else { valueAtTime(\(a) + ((time - \(a)) % \(span))) }"
            setExpression(key, src)
        }
    }

    func clearMotionExpressions() {
        for k in [PropertyKey.position, .scale, .rotation, .opacity] { setExpression(k, nil) }
    }

    private func keyTimes(_ l: Layer, _ key: PropertyKey) -> [Double] {
        switch key {
        case .position: return l.transform.position.keyframes.map(\.time)
        case .scale: return l.transform.scale.keyframes.map(\.time)
        case .rotation: return l.transform.rotation.keyframes.map(\.time)
        case .opacity: return l.transform.opacity.keyframes.map(\.time)
        default: return []
        }
    }

    /// Moves the anchor to one of 9 points of the layer's box without the layer jumping (Motion 2 anchor tool).
    func anchorGrid(_ ax: Double, _ ay: Double) {
        guard let l = selectedLayer else { return }
        let t = currentTime
        let hs = Renderer.layerHalfSize(l, time: t)
        let target = Vec2(ax * hs.x, ay * hs.y)
        let M = Renderer.layerMatrix(l, time: t, renderScale: 1, includeEffects: false)
        let w = M * SIMD3(target.x, target.y, 1)
        mutate("Anchor Point") { p in
            guard let i = self.selectedIndex else { return }
            p.layers[i].transform.anchor.set(target, at: t)
            p.layers[i].transform.position.set(Vec2(w.x, w.y), at: t)
        }
    }

    /// Sure Target style: points the active camera at the selected layer (keyframed at the playhead).
    func aimCameraAtSelected() {
        guard let target = selectedLayer, let ci = project.layers.firstIndex(where: { $0.content == .camera }) else { return }
        let t = currentTime
        let cam = project.layers[ci].transform
        let cp = cam.position.value(at: t), cz = cam.positionZ.value(at: t)
        let tp = target.transform.position.value(at: t), tz = target.transform.positionZ.value(at: t)
        let d = SIMD3(tp.x - cp.x, tp.y - cp.y, tz - cz)
        let yaw = atan2(d.x, d.z) * 180 / .pi
        let pitch = -atan2(d.y, (d.x * d.x + d.z * d.z).squareRoot()) * 180 / .pi
        mutate("Aim Camera") { p in
            p.layers[ci].transform.rotationY.set(yaw, at: t)
            p.layers[ci].transform.rotationX.set(pitch, at: t)
        }
    }
}
