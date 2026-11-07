import Foundation
import SwiftUI

// MARK: - Property lanes (one timeline lane per animated property)

/// What a lane can show in the value / speed graph.
enum LaneValues {
    case none
    case scalar(get: (Layer) -> Animated<Double>?, set: (inout Layer, Animated<Double>) -> Void)
    case vector(get: (Layer) -> Animated<Vec2>?, set: (inout Layer, Animated<Vec2>) -> Void)
}

/// One animated property of a layer as a timeline lane. Text Studio animators, styles, masks, cameras and lights
/// are one lane each (their keys move together); transform, 3D, content and effect settings are one lane per value.
struct PropertyLane: Identifiable {
    let id: String
    let title: String
    let group: String
    /// Key times (rounded like the layer's keyframe markers).
    let times: [Double]
    /// Visits only this lane's animated values (the same traversal the timeline uses for the whole layer).
    let visit: (inout Layer, inout AnimationTraversal) -> Void
    let values: LaneValues
    var graphable: Bool { if case .none = values { return false }; return true }
}

extension Layer {
    /// Every animated property of this layer as a lane, in panel order. Lanes without keys are left out.
    func propertyLanes() -> [PropertyLane] {
        var lanes: [PropertyLane] = []
        let source = self
        func add(_ id: String, _ title: String, _ group: String, _ values: LaneValues = .none,
                 _ visit: @escaping (inout Layer, inout AnimationTraversal) -> Void) {
            var copy = source
            var inspect = AnimationTraversal(operation: .inspect)
            visit(&copy, &inspect)
            let times = Array(Set(inspect.times.map { ($0 * 10000).rounded() / 10000 })).sorted()
            guard !times.isEmpty else { return }
            lanes.append(PropertyLane(id: id, title: title, group: group, times: times, visit: visit, values: values))
        }
        func scalar(_ kp: WritableKeyPath<Layer, Animated<Double>>) -> LaneValues {
            .scalar(get: { $0[keyPath: kp] }, set: { $0[keyPath: kp] = $1 })
        }
        func vector(_ kp: WritableKeyPath<Layer, Animated<Vec2>>) -> LaneValues {
            .vector(get: { $0[keyPath: kp] }, set: { $0[keyPath: kp] = $1 })
        }
        func path<V: Interpolatable>(_ kp: WritableKeyPath<Layer, Animated<V>>) -> (inout Layer, inout AnimationTraversal) -> Void {
            { layer, visit in visit.apply(&layer[keyPath: kp]) }
        }

        add("tr.anchor", "Anchor", "Transform", vector(\.transform.anchor), path(\.transform.anchor))
        add("tr.position", "Position", "Transform", vector(\.transform.position), path(\.transform.position))
        add("tr.scale", "Scale", "Transform", vector(\.transform.scale), path(\.transform.scale))
        add("tr.rotation", "Rotation", "Transform", scalar(\.transform.rotation), path(\.transform.rotation))
        add("tr.opacity", "Opacity", "Transform", scalar(\.transform.opacity), path(\.transform.opacity))
        add("3d.positionZ", "Position Z", "3D", scalar(\.transform.positionZ), path(\.transform.positionZ))
        add("3d.rotationX", "Rotation X", "3D", scalar(\.transform.rotationX), path(\.transform.rotationX))
        add("3d.rotationY", "Rotation Y", "3D", scalar(\.transform.rotationY), path(\.transform.rotationY))
        add("3d.extrude", "Thickness", "3D", scalar(\.extrude), path(\.extrude))
        if shapeContents == nil {
        add("c.size", "Size", "Content", vector(\.size), path(\.size))
        add("c.fill", "Fill Color", "Content", .none, path(\.fill))
        add("c.corner", "Roundness", "Content", scalar(\.cornerRadius), path(\.cornerRadius))
        add("c.sides", "Points", "Content", scalar(\.sides), path(\.sides))
        add("c.inner", "Inner Radius", "Content", scalar(\.innerRatio), path(\.innerRatio))
        }
        add("c.volume", "Volume", "Audio", scalar(\.volume), path(\.volume))
        add("c.timeRemap", "Time Remap", "Time", .scalar(get: { $0.timeRemap }, set: { $0.timeRemap = $1 })) { l, v in v.apply(&l.timeRemap) }
        if shapeContents == nil { add("c.path", "Path", "Shape") { l, v in v.apply(&l.path) } }

        for item in shapeContents ?? [] where item.component != nil {
            let id = item.id
            add("shape.\(id)", item.name, "Shape Paths") { l, v in
                guard let i = l.shapeContents?.firstIndex(where: { $0.id == id }) else { return }
                l.shapeContents?[i].component?.traverse(&v)
            }
        }
        if shapeContents == nil { add("c.stroke", "Stroke & Trim", "Shape") { l, v in l.stroke.traverse(&v) } }
        for mask in masks {
            let mid = mask.id
            add("mask.\(mid)", mask.name.isEmpty ? "Mask" : mask.name, "Masks") { l, v in
                guard let j = l.masks.firstIndex(where: { $0.id == mid }) else { return }
                v.apply(&l.masks[j].path); v.apply(&l.masks[j].feather)
                v.apply(&l.masks[j].opacity); v.apply(&l.masks[j].expansion)
            }
        }
        if camera != nil {
            add("cam", "Camera Lens", "Camera") { l, v in
                guard l.camera != nil else { return }
                v.apply(&l.camera!.zoom); v.apply(&l.camera!.focusDistance)
                v.apply(&l.camera!.aperture); v.apply(&l.camera!.blurLevel)
            }
        }
        if light != nil {
            add("light", "Light", "Light") { l, v in
                guard l.light != nil else { return }
                v.apply(&l.light!.color); v.apply(&l.light!.intensity); v.apply(&l.light!.coneAngle)
                v.apply(&l.light!.coneFeather); v.apply(&l.light!.falloffRadius)
            }
        }
        if model3D != nil {
            add("model", "3D Model", "3D") { l, v in
                guard l.model3D != nil else { return }
                v.apply(&l.model3D!.yaw); v.apply(&l.model3D!.pitch); v.apply(&l.model3D!.roll)
                v.apply(&l.model3D!.color); v.apply(&l.model3D!.lightAngle); v.apply(&l.model3D!.lightIntensity)
            }
        }

        for fx in effects {
            let fid = fx.id
            let def = EffectRegistry.definition(fx.typeID)
            let fxName = def?.name ?? fx.typeID
            for key in fx.params.keys.sorted() {
                let paramName = def?.params.first(where: { $0.id == key })?.name ?? key
                let values: LaneValues
                switch fx.params[key] {
                case .number?:
                    values = .scalar(get: { l in
                        guard let j = l.effects.firstIndex(where: { $0.id == fid }), case .number(let a)? = l.effects[j].params[key] else { return nil }
                        return a
                    }, set: { l, a in
                        guard let j = l.effects.firstIndex(where: { $0.id == fid }) else { return }
                        l.effects[j].params[key] = .number(a)
                    })
                case .point?:
                    values = .vector(get: { l in
                        guard let j = l.effects.firstIndex(where: { $0.id == fid }), case .point(let a)? = l.effects[j].params[key] else { return nil }
                        return a
                    }, set: { l, a in
                        guard let j = l.effects.firstIndex(where: { $0.id == fid }) else { return }
                        l.effects[j].params[key] = .point(a)
                    })
                default: values = .none
                }
                add("fx.\(fid).\(key)", "\(fxName) · \(paramName)", fxName, values) { l, v in
                    guard let j = l.effects.firstIndex(where: { $0.id == fid }), let value = l.effects[j].params[key] else { return }
                    switch value {
                    case .number(var a): v.apply(&a); l.effects[j].params[key] = .number(a)
                    case .point(var a): v.apply(&a); l.effects[j].params[key] = .point(a)
                    case .color(var a): v.apply(&a); l.effects[j].params[key] = .color(a)
                    default: break
                    }
                }
            }
        }

        if let text {
            add("text.base", "Text", "Text") { l, v in
                guard l.text != nil else { return }
                v.apply(&l.text!.fill); v.apply(&l.text!.tracking); v.apply(&l.text!.lineSpacing)
                v.apply(&l.text!.pathOffset)
                if l.text!.counter != nil { v.apply(&l.text!.counter!.value) }
                v.apply(&l.text!.baselineShift)
            }
            if text.style != nil {
                add("text.style", "Text Style", "Text") { l, v in
                    guard l.text?.style != nil else { return }
                    l.text!.style!.traverse(&v)
                }
            }
            if text.text3D != nil {
                add("text.3d", "3D Text", "Text") { l, v in
                    guard var t3 = l.text?.text3D else { return }
                    v.apply(&t3.extrusion); v.apply(&t3.bevelSize)
                    v.apply(&t3.environmentIntensity); v.apply(&t3.environmentRotation)
                    for k in 0..<3 {
                        var m = k == 0 ? t3.front : (k == 1 ? t3.bevel : t3.side)
                        v.apply(&m.color); v.apply(&m.metalness); v.apply(&m.roughness); v.apply(&m.emission)
                        v.apply(&m.clearcoat); v.apply(&m.opacity); v.apply(&m.transmission)
                        if k == 0 { t3.front = m } else if k == 1 { t3.bevel = m } else { t3.side = m }
                    }
                    l.text!.text3D = t3
                }
            }
            for animator in text.animators {
                let aid = animator.id
                add("text.anim.\(aid)", animator.name.isEmpty ? "Animator" : animator.name, "Text Animators") { l, v in
                    guard let j = l.text?.animators.firstIndex(where: { $0.id == aid }), var a = l.text?.animators[j] else { return }
                    var sels = a.allSelectors
                    for k in sels.indices { sels[k].traverse(&v) }
                    a.allSelectors = sels
                    a.properties.traverse(&v)
                    if var fx = a.letterEffects {
                        for k in fx.indices { fx[k].traverseParams(&v) }
                        a.letterEffects = fx
                    }
                    l.text!.animators[j] = a
                }
            }
        }
        if shapeOps != nil {
            add("shapeOps", "Shape Operators", "Shape") { l, v in
                guard l.shapeOps != nil else { return }
                v.apply(&l.shapeOps!.offset)
                v.apply(&l.shapeOps!.pucker)
                if l.shapeOps!.repeater != nil {
                    v.apply(&l.shapeOps!.repeater!.copies); v.apply(&l.shapeOps!.repeater!.position)
                    v.apply(&l.shapeOps!.repeater!.scale); v.apply(&l.shapeOps!.repeater!.rotation)
                    v.apply(&l.shapeOps!.repeater!.startOpacity); v.apply(&l.shapeOps!.repeater!.endOpacity)
                }
                if l.shapeOps!.wiggle != nil {
                    v.apply(&l.shapeOps!.wiggle!.size); v.apply(&l.shapeOps!.wiggle!.detail); v.apply(&l.shapeOps!.wiggle!.speed)
                }
                if l.shapeOps!.zigzag != nil {
                    v.apply(&l.shapeOps!.zigzag!.size); v.apply(&l.shapeOps!.zigzag!.ridges)
                }
            }
        }
        return lanes
    }

    /// Moves the selected keys of each lane to `map(time)` (snapped to frames). Returns nil, and changes nothing,
    /// when a key would land on an unselected key of the same property: moving keys never deletes a key.
    func remappingKeys(_ selection: [String: [Double]], lanes: [PropertyLane], fps: Double, _ map: (Double) -> Double) -> Layer? {
        var layer = self
        let far = 100_000.0
        for lane in lanes {
            guard let times = selection[lane.id], !times.isEmpty else { continue }
            // Lift the selected keys far away first, so keys can pass each other (reverse, stretch) without colliding.
            var lift = AnimationTraversal(operation: .moveTimes(times, far))
            lane.visit(&layer, &lift)
            for t in times {
                let target = max(0, (map(t) * fps).rounded() / fps)
                guard target.isFinite else { return nil }
                var drop = AnimationTraversal(operation: .moveTimes([t + far], target - (t + far)))
                lane.visit(&layer, &drop)
                if drop.collided { return nil }
            }
        }
        return layer
    }
}

// MARK: - Key selection

/// Keys picked on one layer's lanes (by lane id and key time).
struct KeySelection: Equatable {
    var layerID: UUID
    var keys: [String: [Double]] = [:]

    var count: Int { keys.values.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { count == 0 }
    var allTimes: [Double] { keys.values.flatMap { $0 } }

    func contains(_ lane: String, _ time: Double) -> Bool {
        keys[lane]?.contains { abs($0 - time) < keyframeTimeEpsilon } ?? false
    }

    mutating func toggle(_ lane: String, _ time: Double) {
        var list = keys[lane] ?? []
        if let i = list.firstIndex(where: { abs($0 - time) < keyframeTimeEpsilon }) { list.remove(at: i) } else { list.append(time) }
        keys[lane] = list.isEmpty ? nil : list.sorted()
    }

    /// Keys of `lanes[laneRange]` between two times (a marquee).
    static func marquee(layerID: UUID, lanes: [PropertyLane], laneRange: ClosedRange<Int>, from t0: Double, to t1: Double) -> KeySelection {
        var s = KeySelection(layerID: layerID)
        let lo = min(t0, t1), hi = max(t0, t1)
        for (i, lane) in lanes.enumerated() where laneRange.contains(i) {
            let hit = lane.times.filter { $0 >= lo - keyframeTimeEpsilon && $0 <= hi + keyframeTimeEpsilon }
            if !hit.isEmpty { s.keys[lane.id] = hit }
        }
        return s
    }

    /// The same selection after its times went through `map` (snapped like the keys themselves).
    func remapped(fps: Double, _ map: (Double) -> Double) -> KeySelection {
        var s = self
        s.keys = keys.mapValues { $0.map { max(0, (map($0) * fps).rounded() / fps) }.sorted() }
        return s
    }
}

extension EditorState {
    /// Applies a time mapping to the selected keys, starting from the layer as it was when the gesture began.
    /// Returns the updated selection, or nil when the move was rejected (an occupied destination).
    @discardableResult
    func remapKeySelection(of original: Layer, _ selection: KeySelection, _ map: (Double) -> Double) -> KeySelection? {
        guard !original.isLocked, !selection.isEmpty,
              let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return nil }
        guard let moved = original.remappingKeys(selection.keys, lanes: original.propertyLanes(), fps: project.fps, map) else { return nil }
        mutateLayer(at: i) { $0 = moved }
        return selection.remapped(fps: project.fps, map)
    }

    /// Moves every selected key by `delta` seconds (never before 0).
    @discardableResult
    func moveKeySelection(of original: Layer, _ selection: KeySelection, by delta: Double) -> KeySelection? {
        guard let earliest = selection.allTimes.min(), delta.isFinite else { return nil }
        let shift = max(-earliest, delta)
        return remapKeySelection(of: original, selection) { $0 + shift }
    }

    /// Keyframe stretch: scales the selection's timing around its first key (factor 1 = unchanged).
    @discardableResult
    func stretchKeySelection(of original: Layer, _ selection: KeySelection, factor: Double) -> KeySelection? {
        guard let anchor = selection.allTimes.min(), factor.isFinite, factor > 0 else { return nil }
        return remapKeySelection(of: original, selection) { anchor + ($0 - anchor) * factor }
    }

    /// Time-reverses the selected keys inside their own span. A lane whose keys are all selected also mirrors its
    /// easing (like AE's Time-Reverse Keyframes); a partly selected lane swaps the key times.
    @discardableResult
    func reverseKeySelection(of original: Layer, _ selection: KeySelection) -> KeySelection? {
        let all = selection.allTimes
        guard let lo = all.min(), let hi = all.max(), hi - lo > 1e-6, !original.isLocked,
              let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return nil }
        var layer = original
        let lanes = original.propertyLanes()
        var partial: [String: [Double]] = [:]
        for lane in lanes {
            guard let picked = selection.keys[lane.id], !picked.isEmpty else { continue }
            let whole = lane.times.allSatisfy { t in picked.contains { abs($0 - t) < keyframeTimeEpsilon } }
            if whole {
                var visit = AnimationTraversal(operation: .reverse(lo + hi))
                lane.visit(&layer, &visit)
            } else {
                partial[lane.id] = picked
            }
        }
        if !partial.isEmpty {
            guard let swapped = layer.remappingKeys(partial, lanes: lanes, fps: project.fps, { lo + hi - $0 }) else { return nil }
            layer = swapped
        }
        mutate("Reverse Keyframes") { p in
            guard p.layers.indices.contains(i) else { return }
            p.layers[i] = layer
        }
        return selection.remapped(fps: project.fps) { lo + hi - $0 }
    }
}

// MARK: - Clip edits (ripple delete, close gap, slip, multi-clip move)

extension EditorState {
    /// Rows (timeline layers) that start at or after `time`, with everything inside their groups.
    nonisolated static func rowsStarting(at time: Double, in p: Project, excluding: Set<UUID> = []) -> Set<UUID> {
        var ids = Set<UUID>()
        for row in p.timelineLayers where row.inPoint >= time - 1e-6 && !excluding.contains(row.id) {
            ids.insert(row.id)
            if row.isGroup { ids.formUnion(descendantIDs(of: row.id, in: p)) }
        }
        return ids
    }

    /// Shifts the given layers (and their keys) by `dt`, never before 0.
    nonisolated static func shift(_ ids: Set<UUID>, by dt: Double, in p: inout Project) {
        let earliest = p.layers.filter { ids.contains($0.id) }.map(\.inPoint).min() ?? 0
        let d = max(-earliest, dt)
        guard abs(d) > 1e-9 else { return }
        let duration = p.duration
        for k in p.layers.indices where ids.contains(p.layers[k].id) { p.layers[k].shiftTiming(by: d, duration: duration) }
    }

    /// Deletes the selected clip and pulls everything that started after it back by its length (one undo step).
    func rippleDeleteSelected() {
        guard let l = selectedLayer, !l.isLocked else { return }
        let length = l.outPoint - l.inPoint, end = l.outPoint
        beginEdit("Ripple Delete")
        deleteSelected()
        mutate("Ripple Delete") { p in
            Self.shift(Self.rowsStarting(at: end, in: p), by: -length, in: &p)
        }
        endEdit()
    }

    /// The empty stretch of the timeline under the playhead (no row covers it), if any.
    func gapAtPlayhead() -> ClosedRange<Double>? { Self.gap(at: currentTime, in: project) }

    nonisolated static func gap(at t: Double, in p: Project) -> ClosedRange<Double>? {
        let rows = p.timelineLayers
        guard !rows.contains(where: { $0.inPoint <= t + 1e-6 && $0.outPoint > t + 1e-6 }) else { return nil }
        guard let next = rows.map(\.inPoint).filter({ $0 > t + 1e-6 }).min() else { return nil }
        let prev = rows.map(\.outPoint).filter { $0 <= t + 1e-6 }.max() ?? 0
        return next - prev > 1e-6 ? prev...next : nil
    }

    /// Closes the gap under the playhead: everything after it moves back to meet the clip before it.
    func closeGapAtPlayhead() {
        guard let gap = gapAtPlayhead() else { return }
        mutate("Close Gap") { p in
            Self.shift(Self.rowsStarting(at: gap.upperBound, in: p), by: -(gap.upperBound - gap.lowerBound), in: &p)
        }
        seek(gap.lowerBound)
    }

    /// Slip: the clip keeps its place and length on the timeline while the source frames under it move.
    /// `dt` is in comp seconds; the source never runs past its first or last frame.
    func slipClip(_ original: Layer, by dt: Double) {
        guard original.isMedia, original.timeRemap == nil, !original.isLocked,
              let i = project.layers.firstIndex(where: { $0.id == original.id }) else { return }
        let slipped = Self.slipped(original, by: dt, sourceLength: mediaSourceLength(original))
        mutateLayer(at: i) { $0.sourceStart = slipped }
    }

    nonisolated static func slipped(_ l: Layer, by dt: Double, sourceLength: Double?) -> Double {
        var s = l.sourceStart + dt * l.speed
        if let len = sourceLength {
            let used = (l.outPoint - l.inPoint) * l.speed
            s = min(s, max(0, len - used))
        }
        return max(0, s)
    }

    /// Moves several clips together from their state when the drag began (the earliest stops at 0).
    func moveClips(_ originals: [Layer], by dt: Double) {
        guard let earliest = originals.map(\.inPoint).min() else { return }
        let d = max(-earliest, dt)
        for o in originals where !o.isLocked { moveClip(o, by: d) }
    }

    func toggleLock(_ id: UUID) {
        guard let i = project.layers.firstIndex(where: { $0.id == id }) else { return }
        mutate("Lock Layer") { $0.layers[i].isLocked.toggle() }
    }

    func toggleSolo(_ id: UUID) {
        guard let i = project.layers.firstIndex(where: { $0.id == id }) else { return }
        mutate("Solo Layer") { $0.layers[i].isSolo.toggle() }
    }
}

// MARK: - Ruler and history

enum TimelineRuler {
    /// Tick step in seconds that keeps labels about `minSpacing` points apart. In frame mode the step is whole frames.
    static func step(zoom: CGFloat, fps: Double, frames: Bool, minSpacing: CGFloat = 60) -> Double {
        if frames {
            let fd = 1 / max(fps, 1)
            let counts: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800]
            let n = counts.first { CGFloat($0 * fd) * zoom >= minSpacing } ?? 1800
            return n * fd
        }
        let steps: [Double] = [0.1, 0.25, 0.5, 1, 2, 5, 10, 30, 60]
        return steps.first { CGFloat($0) * zoom >= minSpacing } ?? 60
    }

    static func label(_ t: Double, step: Double, fps: Double, frames: Bool) -> String {
        if frames { return "\(Int((t * fps).rounded()))" }
        return step < 1 ? String(format: "%.2fs", t) : "\(Int(t.rounded()))s"
    }
}

extension EditorState {
    /// When history entry `index` (an action) happened: the moment the project last changed after it.
    func historyDate(at index: Int) -> Date {
        index + 1 < undoStack.count ? undoStack[index + 1].project.modifiedAt : project.modifiedAt
    }
}
