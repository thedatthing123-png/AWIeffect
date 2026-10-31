import Foundation
import SwiftUI

/// Direct timeline editing: move clips, trim their ends, reorder layers, drag / copy / paste keyframes.
extension EditorState {
    /// Snaps a time to frames, beat markers and the playhead.
    func snapTime(_ t: Double, tolerance: Double) -> Double {
        var best = t, dist = tolerance
        for c in project.markers + [currentTime, 0, project.duration] where abs(c - t) < dist { best = c; dist = abs(c - t) }
        return project.snapToFrame(best)
    }

    /// Moves a whole clip in time (with all its keyframes), starting from its state when the drag began.
    func moveClip(_ original: Layer, by dt: Double) {
        guard let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return }
        var l = original
        let shift = max(-original.inPoint, dt)
        l.shiftTiming(by: shift, duration: project.duration)
        mutateLayer(at: i) { $0 = l }
    }

    /// Trims a clip edge. Media keeps playing the same frames under the kept part.
    func trimClip(_ original: Layer, start: Bool, by dt: Double) {
        guard let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return }
        var l = original
        let minLen = project.frameDuration
        if start {
            let newIn = min(max(0, original.inPoint + dt), original.outPoint - minLen)
            if l.timeRemap == nil { l.sourceStart = max(0, original.sourceStart + (newIn - original.inPoint) * original.speed) }
            l.inPoint = project.snapToFrame(newIn)
        } else {
            l.outPoint = project.snapToFrame(max(original.inPoint + minLen, original.outPoint + dt))
        }
        mutateLayer(at: i) { $0 = l }
    }

    func reorderLayer(from: Int, to: Int) {
        guard project.layers.indices.contains(from), from != to else { return }
        let target = max(0, min(project.layers.count - 1, to))
        mutate("Reorder Layer") { p in
            let l = p.layers.remove(at: from)
            p.layers.insert(l, at: target)
        }
    }

    /// Moves every keyframe of the selected layer at `from` to `to` (all properties).
    func moveKeyframes(of original: Layer, from: Double, to: Double) {
        guard let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return }
        var l = original
        l.retimeKeys(at: from, to: max(0, project.snapToFrame(to)))
        mutateLayer(at: i) { $0 = l }
    }

    func mutateLayer(at i: Int, _ change: (inout Layer) -> Void) {
        var p = project
        change(&p.layers[i])
        p.modifiedAt = Date()
        project = p
    }

    // MARK: Keyframe clipboard

    /// Copies the selected layer's transform values at the playhead (pastes as keyframes on any layer / time).
    func copyKeyframes() {
        guard let l = selectedLayer else { return }
        let t = currentTime, tr = l.transform
        keyClipboard = KeyClipboard(position: tr.position.value(at: t), scale: tr.scale.value(at: t), rotation: tr.rotation.value(at: t),
                                    opacity: tr.opacity.value(at: t), anchor: tr.anchor.value(at: t))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func pasteKeyframes() {
        guard let c = keyClipboard, selectedLayer != nil else { return }
        let t = currentTime
        mutate("Paste Keyframes") { p in
            guard let i = self.selectedIndex else { return }
            func put<V: Interpolatable>(_ a: inout Animated<V>, _ v: V) {
                a.insertKeyframe(Keyframe(time: t, value: v, interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn))
            }
            put(&p.layers[i].transform.position, c.position); put(&p.layers[i].transform.scale, c.scale)
            put(&p.layers[i].transform.rotation, c.rotation); put(&p.layers[i].transform.opacity, c.opacity)
            put(&p.layers[i].transform.anchor, c.anchor)
        }
    }
}

extension EditorState {
    func copyEffects() {
        guard let l = selectedLayer, !l.effects.isEmpty else { return }
        effectClipboard = l.effects
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func pasteEffects() {
        guard !effectClipboard.isEmpty, selectedIndex != nil else { return }
        let fx = effectClipboard.map { e -> EffectInstance in var c = e; c.id = UUID(); return c }
        mutate("Paste Effects") { p in if let i = self.selectedIndex { p.layers[i].effects += fx } }
    }

    /// One-tap audio fades (volume keyframes at the clip edges).
    func audioFade(in fadeIn: Bool, seconds: Double = 0.6) {
        guard let i = selectedIndex else { return }
        mutate(fadeIn ? "Audio Fade In" : "Audio Fade Out") { p in
            let l = p.layers[i]
            let v = l.volume.value(at: fadeIn ? l.inPoint + seconds : l.outPoint - seconds)
            let a = fadeIn ? l.inPoint : max(l.inPoint, l.outPoint - seconds)
            let b = fadeIn ? min(l.outPoint, l.inPoint + seconds) : l.outPoint
            p.layers[i].volume.insertKeyframe(Keyframe(time: a, value: fadeIn ? 0 : v, interpolation: .linear))
            p.layers[i].volume.insertKeyframe(Keyframe(time: b, value: fadeIn ? v : 0, interpolation: .linear))
        }
        AudioPreview.shared.invalidate()
    }
}

struct KeyClipboard: Equatable {
    var position: Vec2, scale: Vec2, rotation: Double, opacity: Double, anchor: Vec2
}

extension Animated {
    mutating func retime(at from: Double, to: Double) {
        guard let k = keyframes.firstIndex(where: { abs($0.time - from) < 1e-4 }) else { return }
        keyframes.removeAll { abs($0.time - to) < 1e-4 && abs($0.time - from) >= 1e-4 }
        if let j = keyframes.firstIndex(where: { abs($0.time - from) < 1e-4 }) { keyframes[j].time = to }
        _ = k
        keyframes.sort { $0.time < $1.time }
    }
}

extension Layer {
    /// Moves keys at one time to another across every animatable property.
    mutating func retimeKeys(at from: Double, to: Double) {
        transform.position.retime(at: from, to: to); transform.scale.retime(at: from, to: to); transform.rotation.retime(at: from, to: to)
        transform.opacity.retime(at: from, to: to); transform.anchor.retime(at: from, to: to)
        transform.rotationX.retime(at: from, to: to); transform.rotationY.retime(at: from, to: to); transform.positionZ.retime(at: from, to: to)
        size.retime(at: from, to: to); fill.retime(at: from, to: to); cornerRadius.retime(at: from, to: to)
        sides.retime(at: from, to: to); innerRatio.retime(at: from, to: to); volume.retime(at: from, to: to); extrude.retime(at: from, to: to)
        timeRemap?.retime(at: from, to: to); path?.retime(at: from, to: to)
        for i in effects.indices {
            for (k, v) in effects[i].params {
                switch v {
                case .number(var a): a.retime(at: from, to: to); effects[i].params[k] = .number(a)
                case .point(var a): a.retime(at: from, to: to); effects[i].params[k] = .point(a)
                case .color(var a): a.retime(at: from, to: to); effects[i].params[k] = .color(a)
                default: break
                }
            }
        }
        for i in masks.indices { masks[i].path.retime(at: from, to: to) }
        if camera != nil { camera!.zoom.retime(at: from, to: to); camera!.focusDistance.retime(at: from, to: to); camera!.aperture.retime(at: from, to: to); camera!.blurLevel.retime(at: from, to: to) }
        if model3D != nil { model3D!.yaw.retime(at: from, to: to); model3D!.pitch.retime(at: from, to: to); model3D!.roll.retime(at: from, to: to); model3D!.color.retime(at: from, to: to) }
        if light != nil { light!.color.retime(at: from, to: to); light!.intensity.retime(at: from, to: to); light!.coneAngle.retime(at: from, to: to); light!.coneFeather.retime(at: from, to: to); light!.falloffRadius.retime(at: from, to: to) }
        if text != nil { text!.fill.retime(at: from, to: to); text!.tracking.retime(at: from, to: to) }
    }
}
