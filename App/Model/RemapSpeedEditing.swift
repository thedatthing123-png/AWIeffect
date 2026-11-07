import Foundation

/// A speed handle changes the source curve's slope on both sides of the same key, not a second speed track.
enum RemapSpeedEditing {
    static func settingRate(_ raw: Double, at k: Int, in source: Animated<Double>) -> Animated<Double> {
        guard raw.isFinite, source.keyframes.indices.contains(k) else { return source }
        var a = source
        let rate = min(64, max(-64, raw))
        if k + 1 < a.keyframes.count {
            let dt = a.keyframes[k + 1].time - a.keyframes[k].time
            if dt > 1e-8 {
                if abs(a.keyframes[k + 1].value - a.keyframes[k].value) < 1e-9, abs(rate) > 1e-9 {
                    a.keyframes[k + 1].value = max(0, a.keyframes[k].value + rate * dt)
                }
                let dv = a.keyframes[k + 1].value - a.keyframes[k].value
                a.keyframes[k].interpolation = .bezier; a.keyframes[k].curve = nil; a.keyframes[k].reversedSegment = nil
                if abs(dv) > 1e-9 { a.keyframes[k].easeOut = EaseHandle(x: 1.0 / 3, y: rate * dt / (3 * dv)) }
            }
        }
        if k > 0 {
            let dt = a.keyframes[k].time - a.keyframes[k - 1].time
            if dt > 1e-8 {
                if abs(a.keyframes[k].value - a.keyframes[k - 1].value) < 1e-9, abs(rate) > 1e-9 {
                    a.keyframes[k - 1].value = max(0, a.keyframes[k].value - rate * dt)
                }
                let dv = a.keyframes[k].value - a.keyframes[k - 1].value
                a.keyframes[k - 1].interpolation = .bezier; a.keyframes[k - 1].curve = nil; a.keyframes[k - 1].reversedSegment = nil
                if abs(dv) > 1e-9 { a.keyframes[k].easeIn = EaseHandle(x: 2.0 / 3, y: 1 - rate * dt / (3 * dv)) }
            }
        }
        return a
    }
}

@MainActor extension EditorState {
    @discardableResult func addSourceTimeKey() -> UUID? {
        guard let l = selectedLayer, l.supportsSourceTiming else { return nil }
        let time = project.snapToFrame(min(l.outPoint, max(l.inPoint, currentTime)))
        beginEdit("Add Remap Key")
        if l.timeRemap == nil { enableTimeRemap() }
        mutate("Add Remap Key") { p in if let i = selectedIndex { p.layers[i].timeRemap?.insertSampledKey(at: time) } }
        endEdit(); AudioPreview.shared.invalidate()
        return selectedLayer?.timeRemap?.keyframes.first { abs($0.time - time) < keyframeTimeEpsilon }?.id
    }
    func setSourceKeyRate(_ rate: Double) {
        let snapshot = live.project ?? project
        guard rate.isFinite, let id = selectedLayerID, let l = snapshot.layers.first(where: { $0.id == id }), l.supportsSourceTiming else { return }
        beginEdit("Remap Speed")
        if l.timeRemap == nil { enableTimeRemap() }
        let time = project.snapToFrame(min(l.outPoint, max(l.inPoint, currentTime)))
        coalescedEdit("Remap Speed") { l in
            guard var a = l.timeRemap else { return }
            a.insertSampledKey(at: time)
            guard let i = a.keyframes.firstIndex(where: { abs($0.time - time) < keyframeTimeEpsilon }) else { return }
            l.timeRemap = RemapSpeedEditing.settingRate(rate, at: i, in: a)
        }
        AudioPreview.shared.invalidate()
    }
}
