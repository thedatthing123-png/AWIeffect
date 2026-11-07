import Foundation
import UIKit

// MARK: - Text preset library (Part 3)
//
// Two kinds of presets:
// - Animation presets (`TextPreset`): a set of ordinary `TextAnimator`s (plus optional letter effects). Applying one
//   APPENDS its animators tagged with `group = preset.id`; the user's own animators are never touched.
//   `TextPresetLibrary.removePresetGroup(_:from:)` removes exactly that group again.
// - Look presets (`TextLookPreset`): a style stack (fills / strokes / shadows / glow), optional layer effects, an
//   optional real 3D material set (`Text3DOptions`) and a font suggestion. A look only replaces the parts that
//   looks own (tagged with a `look.` group); the user's own fills, strokes, shadows, glow and effects stay.

enum TextPresetKind: String, CaseIterable, Identifiable {
    case animation, look
    var id: String { rawValue }
    var title: String { self == .animation ? "Animation" : "Look" }
}

/// A finished look: style stack + layer effects + font (+ real 3D materials). Applying keeps the user's animators.
struct TextLookPreset: Identifiable {
    let id: String
    let name: String
    let category: String
    /// Suggested font (used only when installed).
    var font: String? = nil
    var style = TextStyleStack()
    /// Layer effects as (effect id, settings).
    var effects: [(String, [String: ParamValue])] = []
    /// Real 3D text materials (3D looks).
    var text3D: Text3DOptions? = nil
    /// Letter spacing suggestion, px.
    var tracking: Double? = nil

    func makeEffects() -> [EffectInstance] {
        effects.compactMap { id, values in
            guard var e = EffectRegistry.definition(id)?.makeInstance() else { return nil }
            for (k, v) in values { e.params[k] = v }
            var tags = e.text ?? [:]
            tags[TextPresetLibrary.effectGroupKey] = self.id
            e.text = tags
            return e
        }
    }
}

enum TextPresetLibrary {
    /// Animation categories, in browser order.
    static let categories = ["In", "Out", "Loop", "Emphasis", "Glitch", "Typewriter", "Kinetic", "Manga/AMV", "Lyric",
                             "Impact", "3D In", "3D Out", "3D Loop"]
    /// Look categories, in browser order.
    static let lookCategories = ["Manga/AMV", "Impact", "Sticker", "Neon", "Glitch", "Lyric", "Speed", "Cinematic", "Minimal", "3D"]

    /// Key in `EffectInstance.text` naming the look that added the effect.
    static let effectGroupKey = "presetGroup"
    /// Group prefix of everything a Look adds.
    static let lookGroupPrefix = "look."

    // MARK: Catalog

    /// Every animation preset: studio set, classic built-ins, the pack and the new library. Names are unique and
    /// every id that older projects / AI Link may reference still resolves.
    static let animations: [TextPreset] = {
        let sources: [TextPreset] = TextPresetStudio.all + TextPresets.all + TextPresetPack.all + TextPresetLibraryAnimations.all
        var seenIDs = Set<String>()
        var seenNames = Set<String>()
        var out: [TextPreset] = []
        out.reserveCapacity(sources.count)
        for p in sources where !seenIDs.contains(p.id) {
            seenIDs.insert(p.id)
            var name = renames[p.id] ?? p.name
            if seenNames.contains(name.lowercased()) {
                let base = name
                name = "\(base) Alt"
                var n = 2
                while seenNames.contains(name.lowercased()) { name = "\(base) \(n)"; n += 1 }
            }
            seenNames.insert(name.lowercased())
            out.append(TextPreset(id: p.id, name: name, category: libraryCategory(id: p.id, sourceCategory: p.category), make: p.make))
        }
        return out
    }()

    static let looks: [TextLookPreset] = {
        var seen = Set<String>()
        var names = Set<String>()
        var out: [TextLookPreset] = []
        for l in TextLookPresets.all where !seen.contains(l.id) {
            seen.insert(l.id)
            var name = l.name
            var n = 2
            while names.contains(name.lowercased()) { name = "\(l.name) \(n)"; n += 1 }
            names.insert(name.lowercased())
            out.append(TextLookPreset(id: l.id, name: name, category: l.category, font: l.font, style: l.style,
                                      effects: l.effects, text3D: l.text3D, tracking: l.tracking))
        }
        return out
    }()

    private static let animationIndex: [String: Int] = {
        var d: [String: Int] = [:]
        for (i, p) in animations.enumerated() where d[p.id] == nil { d[p.id] = i }
        return d
    }()

    static func animation(_ id: String) -> TextPreset? { animationIndex[id].map { animations[$0] } }
    static func look(_ id: String) -> TextLookPreset? { looks.first { $0.id == id } }
    static func presets(in category: String) -> [TextPreset] { animations.filter { $0.category == category } }
    static func looks(in category: String) -> [TextLookPreset] { looks.filter { $0.category == category } }

    /// Clearer names for older presets whose names collided or were misleading. Ids never change.
    static let renames: [String: String] = [
        "elasticPop": "Elastic Stretch Pop",
        "decode": "Decode Sweep",
        "jelly": "Jelly Wave",
        "pack.loop.jelly": "Jelly Jitter",
        "pack.loop.waveY": "Wave Bob",
        "pack.burst.neonFlicker": "Neon Flicker Burst",
        "pack.loop.neonBuzz": "Neon Buzz Fast",
        "studio.neonBuzz": "Neon Buzz Slow",
        "studio.glitchLoop": "Glitch Jitter Loop",
        "pack.kin.punch": "Punch Words Stagger",
        "pack.in.fadeUp": "Fade Up Soft",
        "pack.in.scramble": "Scramble In",
        "pack.type.decode": "Decode Wide",
        "pack.out.fade": "Fade Away",
        "pack.3d.turnY": "Turn In Words",
        "pack.3d.flipX": "Flip In X",
        "pack.3d.depthIn": "Depth Push Words",
        "pack.kin.slam": "Slam Zoom",
        "pack.neon.sweep": "Neon Light Sweep",
        "pack.burst.glitchRGB": "RGB Glitch Burst",
        "studio.focusPullWords": "Focus Pull Words",
        "studio.flyUpOut": "Fly Up Out Words",
        "dropIn": "Drop In Words",
        "blurSlideWords": "Blur Slide Words",
        "studio.decode": "Decode",
        "pack.loop.breathe": "Pulse Breathe",
        "pack.burst.glitchSlice": "Slice Glitch",
        "pack.type.words": "Type Words",
    ]

    /// Category of a preset in the library (older presets are refiled by what they do).
    static func libraryCategory(id: String, sourceCategory: String) -> String {
        if let c = categoryOverrides[id] { return c }
        switch sourceCategory {
        case "Neon": return "Emphasis"
        case "3D": return "3D In"
        default: return categories.contains(sourceCategory) ? sourceCategory : "In"
        }
    }

    private static let categoryOverrides: [String: String] = [
        "typewriter": "Typewriter", "typeOut": "Typewriter", "decode": "Typewriter", "scramble": "Glitch",
        "glitchDecode": "Glitch", "glitch": "Glitch", "flicker": "Glitch",
        "wave": "Loop", "jelly": "Loop", "swingLetters": "Loop", "shakeLetters": "Loop", "rainbow": "Loop",
        "karaoke": "Lyric", "fadeOut": "Out", "fallOut": "Out", "shrinkOut": "Out",
        "impactSlam": "Impact", "zoomBig": "Impact", "scalePop": "In", "wordPop": "Kinetic", "colorSweep": "Emphasis",
        "studio.slamShake": "Impact", "studio.scaleSlam": "Impact",
        "pack.kin.slam": "Impact", "pack.kin.zoomSmash": "Impact", "pack.kin.sfx": "Manga/AMV",
        "pack.loop.spinY": "3D Loop", "pack.loop.depthWave": "3D Loop",
        "pack.burst.neonFlicker": "Glitch",
    ]

    // MARK: Apply / remove

    /// Default preset length: 1 s, or what is left of the layer after `start` when that is shorter.
    static func defaultDuration(for layer: Layer, start: Double) -> Double {
        let left = layer.outPoint - start
        guard left.isFinite, left > 0 else { return 1 }
        return max(0.05, min(1, left))
    }

    /// The beat nearest to `t` (within `window` s), else `t`.
    static func snap(_ t: Double, to beats: [Double], window: Double = 0.5) -> Double {
        guard let b = beats.min(by: { abs($0 - t) < abs($1 - t) }), abs(b - t) <= window else { return t }
        return b
    }

    /// Adds `preset` to a text layer as its own animator group (re-applying the same preset replaces that group only).
    /// `duration` nil = `defaultDuration`. With `beats` the start and end snap to the nearest beats.
    @discardableResult
    static func applyPreset(_ preset: TextPreset, to layer: inout Layer, start: Double, duration: Double? = nil,
                            snapToBeats beats: [Double]? = nil) -> Bool {
        guard layer.text != nil else { return false }
        var s = start.isFinite ? start : layer.inPoint
        var d = max(0.05, duration ?? defaultDuration(for: layer, start: s))
        if let beats, !beats.isEmpty {
            let sorted = beats.sorted()
            let s2 = snap(s, to: sorted)
            let e2 = snap(s + d, to: sorted.filter { $0 > s2 + 0.05 })
            s = s2
            d = max(0.05, e2 - s2)
        }
        let group = preset.id
        var made = preset.make(s, d)
        for k in made.indices {
            made[k].id = UUID()
            made[k].group = group
        }
        layer.text!.animators.removeAll { $0.group == group }
        layer.text!.animators += made
        return true
    }

    /// Applies a look: font (when installed), style-stack parts, layer effects and 3D materials. Parts added by an
    /// earlier look are replaced; the user's own parts stay.
    static func applyLook(_ look: TextLookPreset, to layer: inout Layer) {
        guard layer.text != nil else { return }
        removeLookParts(from: &layer)
        var t = layer.text!
        if let f = look.font, UIFont(name: f, size: 12) != nil { t.fontName = f }
        if let tr = look.tracking { t.tracking = Animated(tr) }
        var st = t.style ?? TextStyleStack()
        let g = look.id
        st.fills += look.style.fills.map { var x = $0; x.id = UUID(); x.group = g; return x }
        st.strokes += look.style.strokes.map { var x = $0; x.id = UUID(); x.group = g; return x }
        st.shadows += look.style.shadows.map { var x = $0; x.id = UUID(); x.group = g; return x }
        if var glow = look.style.glow, st.glow == nil {
            glow.group = g
            st.glow = glow
        }
        t.style = st.isEmpty ? nil : st
        if let o = look.text3D { t.text3D = o; t.text3DGroup = g }
        layer.text = t
        layer.effects += look.makeEffects()
    }

    /// Removes everything an earlier look added (stack parts, effects, 3D).
    static func removeLookParts(from layer: inout Layer) {
        removeGroups(where: { $0.hasPrefix(lookGroupPrefix) }, from: &layer)
    }

    /// Removes a preset group: its animators, or the look parts it added. Everything else stays.
    static func removePresetGroup(_ group: String, from layer: inout Layer) {
        removeGroups(where: { $0 == group }, from: &layer)
    }

    private static func removeGroups(where match: (String) -> Bool, from layer: inout Layer) {
        layer.effects.removeAll { e in e.text?[effectGroupKey].map(match) ?? false }
        guard var t = layer.text else { return }
        t.animators.removeAll { a in a.group.map(match) ?? false }
        if var st = t.style {
            st.fills.removeAll { $0.group.map(match) ?? false }
            st.strokes.removeAll { $0.group.map(match) ?? false }
            st.shadows.removeAll { $0.group.map(match) ?? false }
            if let g = st.glow?.group, match(g) { st.glow = nil }
            t.style = st.isEmpty ? nil : st
        }
        if let g = t.text3DGroup, match(g) { t.text3D = nil; t.text3DGroup = nil }
        layer.text = t
    }

    /// Preset groups on a layer (animation presets and looks), in order of first appearance.
    static func groups(in layer: Layer) -> [String] {
        var out: [String] = []
        func add(_ g: String?) { if let g, !out.contains(g) { out.append(g) } }
        layer.text?.animators.forEach { add($0.group) }
        layer.text?.style?.fills.forEach { add($0.group) }
        layer.text?.style?.strokes.forEach { add($0.group) }
        layer.text?.style?.shadows.forEach { add($0.group) }
        add(layer.text?.style?.glow?.group)
        add(layer.text?.text3DGroup)
        layer.effects.forEach { add($0.text?[effectGroupKey]) }
        return out
    }

    static func hasGroup(_ group: String, in layer: Layer) -> Bool { groups(in: layer).contains(group) }
}

// MARK: - Editor actions (one undo step each)

extension EditorState {
    /// Beat times the presets snap to (markers + detected beats).
    var textPresetBeats: [Double] { (project.markers + (project.detectedBeatTimes ?? [])).sorted() }

    /// Adds an animation preset to the selected text layer at the playhead (user animators stay).
    func applyLibraryPreset(_ preset: TextPreset, duration: Double? = nil, snapToBeats: Bool = false) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        let start = max(project.layers[i].inPoint, currentTime)
        let beats = snapToBeats ? textPresetBeats : nil
        mutate("Text Preset \(preset.name)") { p in
            TextPresetLibrary.applyPreset(preset, to: &p.layers[i], start: start, duration: duration, snapToBeats: beats)
        }
    }

    /// Applies a look to the selected text layer (animators stay).
    func applyTextLook(_ look: TextLookPreset) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        mutate("Text Look \(look.name)") { p in TextPresetLibrary.applyLook(look, to: &p.layers[i]) }
    }

    /// Removes one preset group (animation or look) from the selected text layer.
    func removeTextPresetGroup(_ group: String) {
        guard let i = selectedIndex, project.layers[i].text != nil else { return }
        mutate("Remove Text Preset") { p in TextPresetLibrary.removePresetGroup(group, from: &p.layers[i]) }
    }
}
