import Foundation
import Combine

/// One animator property the Studio can add, edit, keyframe and remove (AE "Add Property" list).
enum TextPropKey: String, CaseIterable, Identifiable {
    case position, anchor, scale, rotation, rotationX, rotationY, positionZ, skew
    case opacity, fillOpacity, fill, strokeColor, strokeWidth, glow, hueShift
    case tracking, lineSpacing, baselineShift
    case blur, directionalBlur, directionalBlurAngle, outline, characterOffset, scramble

    var id: String { rawValue }

    enum Access {
        case scalar(WritableKeyPath<TextAnimatorProperties, Animated<Double>?>)
        case vector(WritableKeyPath<TextAnimatorProperties, Animated<Vec2>?>)
        case color(WritableKeyPath<TextAnimatorProperties, Animated<RGBA>?>)
    }

    var access: Access {
        switch self {
        case .position: return .vector(\.position)
        case .anchor: return .vector(\.anchor)
        case .scale: return .vector(\.scale)
        case .rotation: return .scalar(\.rotation)
        case .rotationX: return .scalar(\.rotationX)
        case .rotationY: return .scalar(\.rotationY)
        case .positionZ: return .scalar(\.positionZ)
        case .skew: return .scalar(\.skew)
        case .opacity: return .scalar(\.opacity)
        case .fillOpacity: return .scalar(\.fillOpacity)
        case .fill: return .color(\.fill)
        case .strokeColor: return .color(\.strokeColor)
        case .strokeWidth: return .scalar(\.strokeWidth)
        case .glow: return .scalar(\.glow)
        case .hueShift: return .scalar(\.hueShift)
        case .tracking: return .scalar(\.tracking)
        case .lineSpacing: return .scalar(\.lineSpacing)
        case .baselineShift: return .scalar(\.baselineShift)
        case .blur: return .scalar(\.blur)
        case .directionalBlur: return .scalar(\.directionalBlur)
        case .directionalBlurAngle: return .scalar(\.directionalBlurAngle)
        case .outline: return .scalar(\.outline)
        case .characterOffset: return .scalar(\.characterOffset)
        case .scramble: return .scalar(\.scramble)
        }
    }

    var title: String {
        switch self {
        case .position: return "Position"
        case .anchor: return "Anchor Point"
        case .scale: return "Scale"
        case .rotation: return "Rotation"
        case .rotationX: return "Rotation X (3D)"
        case .rotationY: return "Rotation Y (3D)"
        case .positionZ: return "Position Z (3D)"
        case .skew: return "Skew"
        case .opacity: return "Opacity"
        case .fillOpacity: return "Fill Opacity"
        case .fill: return "Fill Color"
        case .strokeColor: return "Stroke Color"
        case .strokeWidth: return "Stroke Width"
        case .glow: return "Glow"
        case .hueShift: return "Hue Shift"
        case .tracking: return "Tracking"
        case .lineSpacing: return "Line Spacing"
        case .baselineShift: return "Baseline Shift"
        case .blur: return "Blur"
        case .directionalBlur: return "Directional Blur"
        case .directionalBlurAngle: return "Blur Angle"
        case .outline: return "Outline"
        case .characterOffset: return "Character Offset"
        case .scramble: return "Scramble"
        }
    }

    /// Menu section.
    var section: String {
        switch self {
        case .position, .anchor, .scale, .rotation, .skew: return "Transform"
        case .rotationX, .rotationY, .positionZ: return "3D"
        case .opacity, .fillOpacity, .fill, .strokeColor, .strokeWidth, .glow, .hueShift: return "Color & Light"
        case .tracking, .lineSpacing, .baselineShift: return "Spacing"
        case .blur, .directionalBlur, .directionalBlurAngle, .outline, .characterOffset, .scramble: return "Blur & Characters"
        }
    }

    static let sections = ["Transform", "3D", "Color & Light", "Spacing", "Blur & Characters"]

    /// Scrubber range (typed values may go beyond).
    var range: ClosedRange<Double> {
        switch self {
        case .position, .anchor: return -1000...1000
        case .scale: return -400...400
        case .rotation: return -720...720
        case .rotationX, .rotationY: return -360...360
        case .positionZ: return -900...5000
        case .skew: return -70...70
        case .opacity, .fillOpacity, .scramble: return 0...100
        case .strokeWidth: return 0...80
        case .glow: return 0...400
        case .hueShift: return -360...360
        case .tracking: return -100...400
        case .lineSpacing: return -200...400
        case .baselineShift: return -300...300
        case .blur: return 0...100
        case .directionalBlur: return 0...300
        case .directionalBlurAngle: return -180...180
        case .outline: return 0...40
        case .characterOffset: return -40...40
        case .fill, .strokeColor: return 0...1   // colors use a color well, not a scrubber
        }
    }

    var unit: String {
        switch self {
        case .rotation, .rotationX, .rotationY, .skew, .hueShift, .directionalBlurAngle: return "°"
        case .opacity, .fillOpacity, .scramble, .glow, .scale: return "%"
        case .characterOffset: return ""
        default: return "px"
        }
    }

    /// Values typed past the scrubber ends are allowed (transform-like numbers).
    var allowsBeyond: Bool {
        switch self {
        case .opacity, .fillOpacity, .scramble: return false
        default: return true
        }
    }

    func isPresent(_ p: TextAnimatorProperties) -> Bool {
        switch access {
        case .scalar(let k): return p[keyPath: k] != nil
        case .vector(let k): return p[keyPath: k] != nil
        case .color(let k): return p[keyPath: k] != nil
        }
    }

    /// Adds the property with a visible default (no-op when present).
    func add(to p: inout TextAnimatorProperties) {
        guard !isPresent(p) else { return }
        switch access {
        case .scalar(let k): p[keyPath: k] = Animated(defaultScalar)
        case .vector(let k): p[keyPath: k] = Animated(defaultVector)
        case .color(let k): p[keyPath: k] = Animated(defaultColor)
        }
    }

    func remove(from p: inout TextAnimatorProperties) {
        switch access {
        case .scalar(let k): p[keyPath: k] = nil
        case .vector(let k): p[keyPath: k] = nil
        case .color(let k): p[keyPath: k] = nil
        }
    }

    /// Sets every keyframe of this property to one interpolation.
    func setInterpolation(_ interp: Interpolation, in p: inout TextAnimatorProperties) {
        switch access {
        case .scalar(let k): p[keyPath: k]?.setInterpolation(interp)
        case .vector(let k): p[keyPath: k]?.setInterpolation(interp)
        case .color(let k): p[keyPath: k]?.setInterpolation(interp)
        }
    }

    func isAnimated(_ p: TextAnimatorProperties) -> Bool {
        switch access {
        case .scalar(let k): return p[keyPath: k]?.isAnimated ?? false
        case .vector(let k): return p[keyPath: k]?.isAnimated ?? false
        case .color(let k): return p[keyPath: k]?.isAnimated ?? false
        }
    }

    var defaultScalar: Double {
        switch self {
        case .rotation, .rotationX, .rotationY: return 90
        case .positionZ: return 400
        case .skew: return 20
        case .opacity, .fillOpacity: return 0
        case .strokeWidth: return 6
        case .glow, .scramble: return 100
        case .hueShift: return 90
        case .tracking: return 40
        case .lineSpacing, .baselineShift: return 20
        case .blur: return 12
        case .directionalBlur: return 30
        case .directionalBlurAngle: return 0
        case .outline: return 4
        case .characterOffset: return 10
        default: return 0
        }
    }

    var defaultVector: Vec2 {
        switch self {
        case .position: return Vec2(0, -60)
        case .scale: return Vec2(0, 0)
        default: return .zero
        }
    }

    var defaultColor: RGBA { self == .strokeColor ? RGBA(hex: 0xFF2D6F) : RGBA(hex: 0x9B5CFF) }

    /// Properties used by an animator, in list order.
    static func present(in p: TextAnimatorProperties) -> [TextPropKey] { allCases.filter { $0.isPresent(p) } }
}

/// The Studio's editing rules, kept free of SwiftUI so they can be unit tested.
enum TextStudioLogic {
    /// Animators made from a canvas letter selection (drag offset / swipe pad) start with this.
    static let selectionPrefix = "✎ "
    /// Preset group tags: "preset:<name>" for animation presets, "look:<name>" for title looks.
    static let presetGroupPrefix = "preset:"
    static let lookGroupPrefix = "look:"

    // MARK: Character ids <-> indices

    static func ids(_ t: TextData, range: Range<Int>) -> [UInt32] {
        let all = t.resolvedCharIDs
        let lo = max(0, min(range.lowerBound, all.count)), hi = max(lo, min(range.upperBound, all.count))
        return Array(all[lo..<hi])
    }

    /// Smallest index range covering `ids` (nil when none of them are in the text).
    static func range(_ t: TextData, ids: [UInt32]) -> Range<Int>? {
        let set = Set(ids)
        let all = t.resolvedCharIDs
        let idx = all.indices.filter { set.contains(all[$0]) }
        guard let f = idx.first, let l = idx.last else { return nil }
        return f..<(l + 1)
    }

    /// The selected letters as text (for names and labels).
    static func letters(_ t: TextData, ids: [UInt32]) -> String {
        let set = Set(ids)
        let chars = Array(t.string), all = t.resolvedCharIDs
        var out = ""
        for (i, c) in chars.enumerated() where i < all.count && set.contains(all[i]) { out.append(c) }
        return out
    }

    /// Ids of the word containing character `index`.
    static func wordIDs(_ t: TextData, at index: Int) -> [UInt32] {
        let chars = Array(t.string)
        guard index >= 0, index < chars.count, !chars[index].isWhitespace else { return ids(t, range: index..<(index + 1)) }
        var a = index, b = index + 1
        while a > 0, !chars[a - 1].isWhitespace { a -= 1 }
        while b < chars.count, !chars[b].isWhitespace { b += 1 }
        return ids(t, range: a..<b)
    }

    // MARK: Animators from a letter selection

    static func selectionAnimatorIndex(_ t: TextData, ids: [UInt32]) -> Int? {
        let want = ids.sorted()
        guard !want.isEmpty else { return nil }
        return t.animators.firstIndex { a in
            a.group == nil && a.name.hasPrefix(selectionPrefix) && a.selectors == nil
                && (a.selector.targetIDs ?? []).sorted() == want
        }
    }

    /// The animator that offsets exactly these letters (made on first use).
    @discardableResult
    static func ensureSelectionAnimator(_ t: inout TextData, ids: [UInt32]) -> Int {
        t.migrateToCharIDs()
        if let i = selectionAnimatorIndex(t, ids: ids) { return i }
        var a = TextAnimator(name: selectionPrefix + letterName(t, ids: ids))
        a.selector.targetIDs = ids
        a.selector.amount = Animated(100)
        t.animators.append(a)
        return t.animators.count - 1
    }

    private static func letterName(_ t: TextData, ids: [UInt32]) -> String {
        let s = letters(t, ids: ids).trimmingCharacters(in: .whitespacesAndNewlines)
        let short = s.count > 18 ? String(s.prefix(18)) + "…" : s
        return short.isEmpty ? "Letters" : "“\(short)”"
    }

    /// Current offset of the selection (0 when it has none) at `time`.
    static func selectionOffset(_ t: TextData, ids: [UInt32], at time: Double) -> Vec2 {
        guard let i = selectionAnimatorIndex(t, ids: ids) else { return .zero }
        return t.animators[i].properties.position?.value(at: time) ?? .zero
    }

    /// Sets the selected letters' offset (writes the selection animator's Position; keyframes when it is animated).
    static func setSelectionOffset(_ t: inout TextData, ids: [UInt32], to value: Vec2, at time: Double) {
        guard !ids.isEmpty else { return }
        let i = ensureSelectionAnimator(&t, ids: ids)
        if t.animators[i].properties.position == nil { t.animators[i].properties.position = Animated(value) }
        else { t.animators[i].properties.position?.set(value, at: time) }
    }

    static func offsetSelection(_ t: inout TextData, ids: [UInt32], by delta: Vec2, at time: Double) {
        setSelectionOffset(&t, ids: ids, to: selectionOffset(t, ids: ids, at: time) + delta, at: time)
    }

    static func selectionAnchor(_ t: TextData, ids: [UInt32], at time: Double) -> Vec2 {
        guard let i = selectionAnimatorIndex(t, ids: ids) else { return .zero }
        return t.animators[i].properties.anchor?.value(at: time) ?? .zero
    }

    static func setSelectionAnchor(_ t: inout TextData, ids: [UInt32], to value: Vec2, at time: Double) {
        guard !ids.isEmpty else { return }
        let i = ensureSelectionAnimator(&t, ids: ids)
        if t.animators[i].properties.anchor == nil { t.animators[i].properties.anchor = Animated(value) }
        else { t.animators[i].properties.anchor?.set(value, at: time) }
    }

    static func selectionRotation(_ t: TextData, ids: [UInt32], at time: Double) -> Double {
        guard let i = selectionAnimatorIndex(t, ids: ids) else { return 0 }
        return t.animators[i].properties.rotation?.value(at: time) ?? 0
    }

    /// Direct posing edits the same animator the graph and property rows already use.
    static func setSelectionRotation(_ t: inout TextData, ids: [UInt32], to value: Double, at time: Double) {
        guard !ids.isEmpty, value.isFinite else { return }
        let i = ensureSelectionAnimator(&t, ids: ids)
        if t.animators[i].properties.rotation == nil { t.animators[i].properties.rotation = Animated(value) }
        else { t.animators[i].properties.rotation?.set(value, at: time) }
    }

    /// A new animator that targets exactly these letters (Animate tab "Animate Selected Letters").
    @discardableResult
    static func animateSelection(_ t: inout TextData, ids: [UInt32], add key: TextPropKey? = nil) -> UUID? {
        guard !ids.isEmpty else { return nil }
        t.migrateToCharIDs()
        var a = TextAnimator(name: "Letters " + letterName(t, ids: ids))
        a.selector.targetIDs = ids
        if let key { key.add(to: &a.properties) }
        t.animators.append(a)
        return a.id
    }

    // MARK: Animator list

    static func index(_ t: TextData, _ id: UUID) -> Int? { t.animators.firstIndex { $0.id == id } }

    static func addProperty(_ t: inout TextData, animator id: UUID, _ key: TextPropKey) {
        guard let i = index(t, id) else { return }
        key.add(to: &t.animators[i].properties)
    }

    static func removeProperty(_ t: inout TextData, animator id: UUID, _ key: TextPropKey) {
        guard let i = index(t, id) else { return }
        key.remove(from: &t.animators[i].properties)
    }

    /// Moves an animator up (-1) or down (+1); order is the order they apply in.
    static func moveAnimator(_ t: inout TextData, _ id: UUID, by delta: Int) {
        guard let i = index(t, id) else { return }
        let j = max(0, min(t.animators.count - 1, i + delta))
        guard j != i else { return }
        let a = t.animators.remove(at: i)
        t.animators.insert(a, at: j)
    }

    @discardableResult
    static func duplicateAnimator(_ t: inout TextData, _ id: UUID) -> UUID? {
        guard let i = index(t, id) else { return nil }
        var c = t.animators[i]
        c.id = UUID()
        c.name += " copy"
        c.letterEffects = c.letterEffects?.map { e in var n = e; n.id = UUID(); return n }
        t.animators.insert(c, at: i + 1)
        return c.id
    }

    static func deleteAnimator(_ t: inout TextData, _ id: UUID) { t.animators.removeAll { $0.id == id } }

    static func renameAnimator(_ t: inout TextData, _ id: UUID, to name: String) {
        guard let i = index(t, id) else { return }
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        t.animators[i].name = n.isEmpty ? "Animator" : n
    }

    // MARK: Selectors

    static func addSelector(_ t: inout TextData, animator id: UUID, kind: SelectorKind) {
        guard let i = index(t, id) else { return }
        var s = TextSelector()
        s.kind = kind
        s.mode = .intersect
        if kind == .random || kind == .wiggly { s.minAmount = 0 }
        var all = t.animators[i].allSelectors
        all.append(s)
        t.animators[i].allSelectors = all
    }

    /// Removes a selector (an animator always keeps one).
    static func removeSelector(_ t: inout TextData, animator id: UUID, at k: Int) {
        guard let i = index(t, id) else { return }
        var all = t.animators[i].allSelectors
        guard all.count > 1, k >= 0, k < all.count else { return }
        all.remove(at: k)
        if k == 0 { all[0].mode = nil }
        t.animators[i].allSelectors = all
    }

    /// Per-character unit index for a selector's Based On (spaces count to the unit before them).
    static func unitIndices(_ chars: [Character], basedOn: TextUnit) -> (indices: [Int], count: Int) {
        var out: [Int] = []
        out.reserveCapacity(chars.count)
        switch basedOn {
        case .characters:
            return (Array(0..<chars.count), max(chars.count, 0))
        case .charactersExcludingSpaces:
            var n = 0
            for c in chars { out.append(max(0, c.isWhitespace ? n - 1 : n)); if !c.isWhitespace { n += 1 } }
            return (out, n)
        case .words:
            var n = 0, inWord = false
            for c in chars {
                if c.isWhitespace { inWord = false; out.append(max(0, n - 1)) }
                else { if !inWord { n += 1; inWord = true }; out.append(n - 1) }
            }
            return (out, n)
        case .lines:
            var n = 0
            for c in chars { out.append(n); if c.isNewline { n += 1 } }
            return (out, n + 1)
        }
    }

    // MARK: Presets (never delete the user's own animators)

    static func presetGroup(_ name: String) -> String { presetGroupPrefix + name }

    /// Adds a preset's animators as one tagged group. Re-applying the same preset replaces only that group.
    @discardableResult
    static func applyPresetGroup(_ t: inout TextData, group: String, animators: [TextAnimator]) -> String {
        t.migrateToCharIDs()
        t.animators.removeAll { $0.group == group }
        t.animators += animators.map { a in var n = a; n.group = group; return n }
        return group
    }

    /// Preset groups on the text, in the order they were added.
    static func presetGroups(_ t: TextData) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for a in t.animators { if let g = a.group, !seen.contains(g) { seen.insert(g); out.append(g) } }
        return out
    }

    static func removePresetGroup(_ t: inout TextData, group: String) { t.animators.removeAll { $0.group == group } }

    static func groupTitle(_ g: String) -> String {
        if g.hasPrefix(presetGroupPrefix) { return String(g.dropFirst(presetGroupPrefix.count)) }
        if g.hasPrefix(lookGroupPrefix) { return String(g.dropFirst(lookGroupPrefix.count)) }
        return g
    }

    // MARK: Caret <-> UTF-16 (the typing field speaks UTF-16, the model speaks Characters)

    static func utf16Offset(ofCharacter index: Int, in s: String) -> Int {
        var off = 0
        for (i, c) in s.enumerated() { if i >= index { break }; off += c.utf16.count }
        return off
    }

    static func characterIndex(ofUTF16 offset: Int, in s: String) -> Int {
        var off = 0, i = 0
        for c in s {
            if off >= offset { return i }
            off += c.utf16.count
            i += 1
        }
        return i
    }
}

/// What the canvas and the Studio share while editing one text layer: letter selection (by stable ids, so it never
/// drifts), the typing caret and whether the Studio fills the screen.
@MainActor final class TextStudioSession: ObservableObject {
    static let shared = TextStudioSession()

    @Published var layerID: UUID?
    @Published var selectedIDs: [UInt32] = []
    /// Caret / selection in Character indices of the typing field (nil = not typing).
    @Published var caret: Range<Int>?
    @Published var expanded = false
    /// Canvas drag on a selected letter moves its offset (true) or its anchor (false).
    @Published var dragMovesAnchor = false

    // Pinch to size
    private var pinchBase: (fontSize: Double, sizes: [UInt32: Double])?

    /// Clears the selection when another layer becomes the one being edited.
    func follow(_ id: UUID?) {
        guard id != layerID else { return }
        layerID = id
        selectedIDs = []
        caret = nil
    }

    var hasSelection: Bool { !selectedIDs.isEmpty }

    /// Two-finger pinch on the canvas while the Studio is open: sizes the selected letters (or the whole text).
    func pinch(_ state: EditorState, scale: Double) {
        guard let t = state.selectedLayer?.text else { return }
        follow(state.selectedLayerID)
        if pinchBase == nil {
            var sizes: [UInt32: Double] = [:]
            for id in selectedIDs { sizes[id] = t.charStyles?[id]?.sizePercent ?? 100 }
            pinchBase = (t.fontSize, sizes)
            state.beginPanelGesture("Text Size")
        }
        guard let base = pinchBase, scale.isFinite, scale > 0 else { return }
        let ids = selectedIDs
        state.editTextContinuous { td in
            if ids.isEmpty {
                td.fontSize = min(2000, max(4, base.fontSize * scale))
            } else {
                td.migrateToCharIDs()
                var cs = td.charStyles ?? [:]
                for id in ids {
                    var s = cs[id] ?? TextCharStyle()
                    let v = min(800, max(5, (base.sizes[id] ?? 100) * scale))
                    s.sizePercent = abs(v - 100) < 0.5 ? nil : v
                    cs[id] = s.isEmpty ? nil : s
                }
                td.charStyles = cs.isEmpty ? nil : cs
            }
        }
    }

    var isPinching: Bool { pinchBase != nil }

    func endPinch(_ state: EditorState) {
        guard pinchBase != nil else { return }
        pinchBase = nil
        state.endPanelGesture()
    }
}
