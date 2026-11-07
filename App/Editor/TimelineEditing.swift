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
        let previousStart = (live.project ?? project).layers.first(where: { $0.id == original.id })?.inPoint ?? original.inPoint
        let delta = l.inPoint - previousStart
        let members = original.isGroup ? Self.descendantIDs(of: original.id, in: project) : []
        mutateLayer(at: i) { $0 = l }
        for index in project.layers.indices where members.contains(project.layers[index].id) {
            mutateLayer(at: index) { $0.shiftTiming(by: delta, duration: project.duration) }
        }
    }

    /// Trims a clip edge. Media keeps playing the same frames under the kept part and can't be trimmed past its
    /// first / last source frame. Trimming a group trims its parts to the group's new range too.
    func trimClip(_ original: Layer, start: Bool, by dt: Double) {
        guard let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return }
        var l = original
        let minLen = project.frameDuration
        let bounds = Self.mediaTrimBounds(original, sourceLength: mediaSourceLength(original))
        if start {
            var newIn = min(max(0, project.snapToFrame(original.inPoint + dt)), original.outPoint - minLen)
            if let lo = bounds.earliestIn { newIn = min(max(newIn, lo), original.outPoint - minLen) }
            if l.timeRemap == nil { l.sourceStart = original.sourceStart + (newIn - original.inPoint) * original.speed }
            l.inPoint = newIn
        } else {
            var newOut = project.snapToFrame(max(original.inPoint + minLen, original.outPoint + dt))
            if let hi = bounds.latestOut { newOut = max(original.inPoint + minLen, min(newOut, hi)) }
            l.outPoint = newOut
        }
        mutateLayer(at: i) { $0 = l }
        guard original.isGroup else { return }
        // Parts are trimmed from their state before the drag began, so dragging the edge back out restores them.
        let base = editStartProject ?? project
        let members = Self.descendantIDs(of: original.id, in: base)
        for child in base.layers where members.contains(child.id) {
            guard let index = (live.project ?? project).layers.firstIndex(where: { $0.id == child.id }) else { continue }
            let trimmed = Self.clamped(child, toIn: l.inPoint, out: l.outPoint, minLength: minLen)
            if trimmed != (live.project ?? project).layers[index] { mutateLayer(at: index) { $0 = trimmed } }
        }
    }

    /// Source length (s) of a video / audio clip, nil when unknown or not media.
    func mediaSourceLength(_ l: Layer) -> Double? {
        switch l.content {
        case .video(let f, _, _, _):
            let d = VideoSources.shared.duration(mediaURL(f))
            return d > 0 ? d : nil
        case .audio(_, let d): return d > 0 ? d : nil
        default: return nil
        }
    }

    /// Earliest in-point / latest out-point that keep a media clip inside its source (nil = unbounded).
    nonisolated static func mediaTrimBounds(_ l: Layer, sourceLength: Double?) -> (earliestIn: Double?, latestOut: Double?) {
        guard l.isMedia, l.timeRemap == nil, l.speed > 1e-6 else { return (nil, nil) }
        let lo = l.inPoint - max(0, l.sourceStart) / l.speed
        let hi = sourceLength.map { l.inPoint + max(0, $0 - l.sourceStart) / l.speed }
        return (lo, hi)
    }

    /// A group part cut to the group's range (source timing kept). Parts fully outside stay as they are.
    nonisolated static func clamped(_ child: Layer, toIn lo: Double, out hi: Double, minLength: Double) -> Layer {
        var c = child
        guard c.outPoint > lo, c.inPoint < hi else { return c }
        if c.inPoint < lo {
            if c.timeRemap == nil { c.sourceStart += (lo - c.inPoint) * c.speed }
            c.inPoint = lo
        }
        if c.outPoint > hi { c.outPoint = max(c.inPoint + minLength, hi) }
        return c
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
    func moveKeyframes(of original: Layer, from: Double, to: Double, effect: UUID? = nil) {
        _ = moveKeyframeSelection(of: original, times: [from], by: to - from, effect: effect)
    }

    /// A snapshot and a relative delta keep a drag independent of redraws and finger hit-testing.
    /// Occupied destinations are rejected; moving keys never silently deletes another key.
    @discardableResult
    func moveKeyframeSelection(of original: Layer, times: [Double], by delta: Double, effect: UUID? = nil) -> Double? {
        guard delta.isFinite, times.allSatisfy({ $0.isFinite }), !original.isLocked, let earliest = times.min(),
              let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return nil }
        let frameDelta = ((earliest + delta) * project.fps).rounded() / project.fps - earliest
        let shift = max(-earliest, min(frameDelta, (project.autoLength ? 3600 : project.duration) - (times.max() ?? earliest)))
        // Keys of different properties may share a time. A key landing on a key of the SAME property rejects the
        // whole move (nil): nothing is deleted and the layer stays as it was (a drag just holds its last valid spot).
        var layer = original
        var visit = AnimationTraversal(operation: .moveTimes(times, shift))
        visit.onlyEffect = effect
        layer.traverseAnimations(&visit)
        if visit.collided { return nil }
        mutateLayer(at: i) { $0 = layer }
        return shift
    }

    func mutateLayer(at i: Int, _ change: (inout Layer) -> Void) {
        // Mid-drag edits go to the live copy (otherwise they'd be overwritten when the finger lifts).
        if isLiveGesture, var lp = live.project, lp.layers.indices.contains(i) {
            change(&lp.layers[i]); lp.modifiedAt = Date(); live.project = lp
            return
        }
        var p = project
        change(&p.layers[i])
        p.fitAutoLength()
        p.modifiedAt = Date()
        project = p
    }

    // MARK: Keyframe clipboard

    /// Copies the selected layer's real keyframes: every animated property (transform, 3D, size, fill, corner,
    /// polygon, volume, extrusion and effect parameters) with its easing and relative timing.
    func copyKeyframes() {
        guard let l = selectedLayer else { return }
        keyClipboard = KeyClipboard(layer: l, at: currentTime)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Pastes the copied keys onto the selected layer with the earliest copied key at the playhead.
    func pasteKeyframes() {
        guard let c = keyClipboard, let i = selectedIndex else { return }
        let t = project.snapToFrame(currentTime)
        mutate("Paste Keyframes") { p in
            guard p.layers.indices.contains(i) else { return }
            c.paste(into: &p.layers[i], at: t)
        }
    }
}

extension EditorState {
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

/// Copied keyframes. `source` holds the copied layer's animations; times are pasted relative to `earliest`.
struct KeyClipboard: Equatable {
    var source: Layer
    var earliest: Double

    /// With no keys on the layer, its transform values at `time` are copied as one key each (pasted as keys).
    init(layer: Layer, at time: Double) {
        if let first = Self.copiedTimes(of: layer).min() { source = layer; earliest = first; return }
        var l = layer
        func key<V: Interpolatable>(_ a: inout Animated<V>) {
            a.insertKeyframe(Keyframe(time: time, value: a.value(at: time), interpolation: .bezier, easeOut: .easyOut, easeIn: .easyIn))
        }
        key(&l.transform.position); key(&l.transform.scale); key(&l.transform.rotation)
        key(&l.transform.opacity); key(&l.transform.anchor)
        source = l; earliest = time
    }

    /// Times of every key this clipboard copies (the properties `paste` writes).
    static func copiedTimes(of l: Layer) -> [Double] {
        let tr = l.transform
        var times = tr.anchor.keyframeTimes + tr.position.keyframeTimes + tr.scale.keyframeTimes + tr.rotation.keyframeTimes
        times += tr.opacity.keyframeTimes + tr.positionZ.keyframeTimes + tr.rotationX.keyframeTimes + tr.rotationY.keyframeTimes
        times += l.size.keyframeTimes + l.fill.keyframeTimes + l.cornerRadius.keyframeTimes + l.sides.keyframeTimes
        times += l.innerRatio.keyframeTimes + l.volume.keyframeTimes + l.extrude.keyframeTimes
        for fx in l.effects {
            for value in fx.params.values {
                switch value {
                case .number(let a): times += a.keyframeTimes
                case .point(let a): times += a.keyframeTimes
                case .color(let a): times += a.keyframeTimes
                default: break
                }
            }
        }
        return times
    }

    /// Adds the copied keys to `target` (fresh ids, easing kept), shifted so the earliest lands at `time`.
    /// A key at the same time on the same property is replaced by the pasted one (paste = AE paste).
    func paste(into target: inout Layer, at time: Double) {
        let dt = time - earliest
        func put<V: Interpolatable>(_ dst: inout Animated<V>, _ src: Animated<V>) {
            for k in src.keyframes {
                var key = k; key.id = UUID(); key.time = k.time + dt
                dst.insertKeyframe(key)
            }
        }
        let s = source
        put(&target.transform.anchor, s.transform.anchor)
        put(&target.transform.position, s.transform.position)
        put(&target.transform.scale, s.transform.scale)
        put(&target.transform.rotation, s.transform.rotation)
        put(&target.transform.opacity, s.transform.opacity)
        put(&target.transform.positionZ, s.transform.positionZ)
        put(&target.transform.rotationX, s.transform.rotationX)
        put(&target.transform.rotationY, s.transform.rotationY)
        put(&target.size, s.size)
        put(&target.fill, s.fill)
        put(&target.cornerRadius, s.cornerRadius)
        put(&target.sides, s.sides)
        put(&target.innerRatio, s.innerRatio)
        put(&target.volume, s.volume)
        put(&target.extrude, s.extrude)
        // Effects: keys go onto the first not-yet-used effect of the same type; a missing effect is added.
        var used = Set<UUID>()
        for fx in s.effects {
            let animated = fx.params.filter { entry in
                switch entry.value {
                case .number(let a): return a.isAnimated
                case .point(let a): return a.isAnimated
                case .color(let a): return a.isAnimated
                default: return false
                }
            }
            guard !animated.isEmpty else { continue }
            let j: Int
            if let found = target.effects.indices.first(where: { target.effects[$0].typeID == fx.typeID && !used.contains(target.effects[$0].id) }) {
                j = found
            } else {
                var copy = fx; copy.id = UUID()
                for (key, value) in copy.params {
                    switch value {
                    case .number(var a): a.keyframes = []; copy.params[key] = .number(a)
                    case .point(var a): a.keyframes = []; copy.params[key] = .point(a)
                    case .color(var a): a.keyframes = []; copy.params[key] = .color(a)
                    default: break
                    }
                }
                target.effects.append(copy); j = target.effects.count - 1
            }
            used.insert(target.effects[j].id)
            for (key, value) in animated {
                switch (value, target.effects[j].params[key]) {
                case (.number(let a), .number(var d)?): put(&d, a); target.effects[j].params[key] = .number(d)
                case (.point(let a), .point(var d)?): put(&d, a); target.effects[j].params[key] = .point(d)
                case (.color(let a), .color(var d)?): put(&d, a); target.effects[j].params[key] = .color(d)
                case (.number(let a), nil): var d = Animated(a.staticValue); put(&d, a); target.effects[j].params[key] = .number(d)
                case (.point(let a), nil): var d = Animated(a.staticValue); put(&d, a); target.effects[j].params[key] = .point(d)
                case (.color(let a), nil): var d = Animated(a.staticValue); put(&d, a); target.effects[j].params[key] = .color(d)
                default: break
                }
            }
        }
    }
}

extension Animated {
    mutating func retime(at from: Double, to: Double) {
        guard let j = keyframes.firstIndex(where: { abs($0.time - from) < 1e-4 }) else { return }
        // Never overwrite another key of this property: an occupied destination leaves this key where it was.
        if keyframes.contains(where: { abs($0.time - to) < 1e-4 && abs($0.time - from) >= 1e-4 }) { return }
        keyframes[j].time = to
        keyframes.sort { $0.time < $1.time }
    }
}

extension Layer {
    var keyframeMarkers: [(id: UUID, time: Double)] { keyframeMarkers(effect: nil) }

    /// Keyframe times as timeline markers; with `effect`, only that effect's keys.
    func keyframeMarkers(effect: UUID?) -> [(id: UUID, time: Double)] {
        var copy = self, visit = AnimationTraversal(operation: .inspect)
        visit.onlyEffect = effect
        copy.traverseAnimations(&visit)
        return visit.markers.map { (id: $0.value, time: $0.key) }.sorted { $0.time < $1.time }
    }
    /// Moves keys at one time to another across every animatable property.
    mutating func retimeKeys(at from: Double, to: Double) {
        var visit = AnimationTraversal(operation: .retime(from, to))
        traverseAnimations(&visit)
    }
}
