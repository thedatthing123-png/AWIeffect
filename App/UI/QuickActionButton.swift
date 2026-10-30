import SwiftUI

extension EditorState {
    /// Adds a keyframe on position, scale, rotation and opacity at the playhead (AE "key all transform").
    func keyAllTransform() {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Keyframe Transform") { p in
            var tr = p.layers[i].transform
            if !tr.position.hasKeyframe(at: t) { tr.position.toggleKeyframe(at: t) }
            if !tr.scale.hasKeyframe(at: t) { tr.scale.toggleKeyframe(at: t) }
            if !tr.rotation.hasKeyframe(at: t) { tr.rotation.toggleKeyframe(at: t) }
            if !tr.opacity.hasKeyframe(at: t) { tr.opacity.toggleKeyframe(at: t) }
            p.layers[i].transform = tr
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
