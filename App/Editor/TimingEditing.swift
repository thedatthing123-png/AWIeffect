import Foundation

extension Layer {
    var supportsSourceTiming: Bool {
        if isMedia { return true }
        if case .precomp = content { return true }
        return false
    }

    /// Signed source seconds per composition second, including reversed/remapped segments.
    func playbackRate(at time: Double, step: Double = 1.0 / 600) -> Double {
        let h = max(1e-6, step)
        let a = max(inPoint, time - h), b = min(outPoint, time + h)
        guard b > a else { return 0 }
        return (sourceTime(at: timeFX?.localTime(b) ?? b) - sourceTime(at: timeFX?.localTime(a) ?? a)) / (b - a)
    }
}

extension EditorState {
    /// Uniform speed changes stretch the complete animation inventory around the clip start.
    func setLayerSpeed(_ magnitude: Double) {
        let snapshot = live.project ?? project
        guard magnitude.isFinite, magnitude >= 0.05, magnitude <= 16,
              let i = selectedIndex, snapshot.layers.indices.contains(i), snapshot.layers[i].timeRemap == nil else { return }
        let layer = snapshot.layers[i]
        let factor = (abs(layer.speed) > 1e-8 ? abs(layer.speed) : 1) / magnitude
        let members = layer.isGroup ? Self.descendantIDs(of: layer.id, in: snapshot) : []
        mutate("Change Speed") { p in
            for index in p.layers.indices where index == i || members.contains(p.layers[index].id) {
                var visit = AnimationTraversal(operation: .scaleTime(layer.inPoint, factor))
                p.layers[index].traverseAnimations(&visit)
                p.layers[index].outPoint = layer.inPoint + (p.layers[index].outPoint - layer.inPoint) * factor
                if index != i {
                    p.layers[index].inPoint = layer.inPoint + (p.layers[index].inPoint - layer.inPoint) * factor
                    p.layers[index].speed /= factor
                }
            }
            p.layers[i].speed = layer.speed < 0 ? -magnitude : magnitude
        }
        AudioPreview.shared.invalidate()
    }

    func reversePlayback() {
        guard let i = selectedIndex, project.layers[i].supportsSourceTiming else { return }
        mutate("Reverse Playback") { p in
            let layer = p.layers[i]
            if layer.timeRemap != nil { p.layers[i].timeRemap?.reverseKeys(around: layer.inPoint + layer.outPoint) }
            else {
                p.layers[i].sourceStart = layer.sourceTime(at: layer.outPoint)
                p.layers[i].speed = -layer.speed
            }
        }
        AudioPreview.shared.invalidate()
    }

    /// Disabling an arbitrary remap restores its start frame and average playback rate.
    func disableTimeRemap() {
        guard let i = selectedIndex, let remap = project.layers[i].timeRemap else { return }
        mutate("Disable Time Remap") { p in
            let layer = p.layers[i], duration = max(p.frameDuration, layer.outPoint - layer.inPoint)
            p.layers[i].sourceStart = remap.value(at: layer.inPoint)
            p.layers[i].speed = (remap.value(at: layer.outPoint) - remap.value(at: layer.inPoint)) / duration
            p.layers[i].timeRemap = nil
        }
        AudioPreview.shared.invalidate()
    }

    func setRemapValue(_ value: Double) {
        guard value.isFinite, selectedLayer?.timeRemap != nil else { return }
        let time = currentTime
        coalescedEdit("Source Time") {
            $0.timeRemap?.insertSampledKey(at: time)
            $0.timeRemap?.set(max(0, value), at: time)
        }
        AudioPreview.shared.invalidate()
    }

    func toggleRemapKey() {
        guard let i = selectedIndex, project.layers[i].timeRemap != nil else { return }
        let time = currentTime
        mutate("Time Remap Keyframe") { p in
            if p.layers[i].timeRemap?.hasKeyframe(at: time) == true { p.layers[i].timeRemap?.toggleKeyframe(at: time) }
            else { p.layers[i].timeRemap?.insertSampledKey(at: time) }
        }
        AudioPreview.shared.invalidate()
    }
}
