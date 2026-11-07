import Foundation

// MARK: - Style stack (fills, strokes, shadows, glow)

enum TextFillKind: String, Codable, CaseIterable, Identifiable {
    case solid, linear, radial
    var id: String { rawValue }
    var title: String {
        switch self {
        case .solid: return "Solid"
        case .linear: return "Linear Gradient"
        case .radial: return "Radial Gradient"
        }
    }
}

/// Where a gradient is measured: across each letter, or across the whole text block.
enum TextGradientSpace: String, Codable, CaseIterable, Identifiable {
    case glyph, text
    var id: String { rawValue }
    var title: String { self == .glyph ? "Per Letter" : "Whole Text" }
}

struct TextFillLayer: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String? = nil
    var isEnabled = true
    var kind: TextFillKind = .solid
    /// Gradient colors (solid uses the first). Up to 4 are rendered.
    var colors: [Animated<RGBA>] = [Animated(RGBA.white)]
    /// Stop positions 0...1 parallel to `colors` (nil = evenly spaced).
    var stops: [Double]? = nil
    /// Linear: direction in degrees (0 = left→right, 90 = top→bottom). Radial: unused.
    var angle = Animated(90.0)
    /// Percent 0...100.
    var opacity = Animated(100.0)
    var space: TextGradientSpace = .text
    /// Radial size as percent of the measured box (100 = reaches the corners).
    var radialScale: Animated<Double>? = nil
    /// Preset group that owns this layer (Look presets); nil = the user's own.
    var group: String? = nil

    init(kind: TextFillKind = .solid, colors: [RGBA] = [.white], angle: Double = 90, space: TextGradientSpace = .text) {
        self.kind = kind
        self.colors = colors.map { Animated($0) }
        self.angle = Animated(angle)
        self.space = space
    }
}

enum TextStrokePosition: String, Codable, CaseIterable, Identifiable {
    case outside, center, inside
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum TextStrokeJoin: String, Codable, CaseIterable, Identifiable {
    case round, miter, bevel
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// A stroke drawn under the fill. `strokes[0]` sits directly under the fill; later strokes stack further behind,
/// so increasing widths give the stroke-on-stroke AMV look.
struct TextStrokeLayer: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String? = nil
    var isEnabled = true
    var color = Animated(RGBA.black)
    /// px (layer-local).
    var width = Animated(6.0)
    var position: TextStrokePosition = .outside
    var join: TextStrokeJoin = .round
    var opacity = Animated(100.0)
    /// Preset group that owns this layer (Look presets); nil = the user's own.
    var group: String? = nil

    init(color: RGBA = .black, width: Double = 6, position: TextStrokePosition = .outside) {
        self.color = Animated(color)
        self.width = Animated(width)
        self.position = position
    }
}

enum TextShadowKind: String, Codable, CaseIterable, Identifiable {
    case drop, inner
    var id: String { rawValue }
    var title: String { self == .drop ? "Drop Shadow" : "Inner Shadow" }
}

struct TextShadowLayer: Codable, Equatable, Identifiable {
    var id = UUID()
    var isEnabled = true
    var kind: TextShadowKind = .drop
    var color = Animated(RGBA.black)
    var opacity = Animated(75.0)
    /// AE convention: degrees clockwise from up, 135 = shadow falls down-right.
    var angle = Animated(135.0)
    var distance = Animated(8.0)
    var blur = Animated(6.0)
    /// Preset group that owns this layer (Look presets); nil = the user's own.
    var group: String? = nil

    init(kind: TextShadowKind = .drop, color: RGBA = .black, distance: Double = 8, blur: Double = 6) {
        self.kind = kind
        self.color = Animated(color)
        self.distance = Animated(distance)
        self.blur = Animated(blur)
    }

    /// Offset in layer px (y down).
    func offset(at t: Double) -> Vec2 {
        let a = angle.value(at: t) * .pi / 180, d = distance.value(at: t)
        return Vec2(sin(a) * d, -cos(a) * d)
    }
}

struct TextGlowLayer: Codable, Equatable {
    var isEnabled = true
    var color = Animated(RGBA(hex: 0x5CC8FF))
    /// Blur radius px.
    var radius = Animated(18.0)
    /// Percent (100 = full strength; above adds more light).
    var intensity = Animated(100.0)
    /// Use each letter's own fill color (keeps hue like the light engine) instead of `color`.
    var useFillColor: Bool? = nil
    /// Preset group that owns this glow (Look presets); nil = the user's own.
    var group: String? = nil
}

struct TextStyleStack: Codable, Equatable {
    var fills: [TextFillLayer] = []
    var strokes: [TextStrokeLayer] = []
    var shadows: [TextShadowLayer] = []
    var glow: TextGlowLayer? = nil

    var isEmpty: Bool { fills.isEmpty && strokes.isEmpty && shadows.isEmpty && glow == nil }

    /// How far (layer px) the stack draws beyond the glyph outlines at `t` (for buffer bounds).
    func margin(at t: Double) -> Double {
        var m = 0.0
        for s in strokes where s.isEnabled {
            let w = max(0, s.width.value(at: t))
            m = max(m, s.position == .inside ? 0 : (s.position == .center ? w / 2 : w))
        }
        for s in shadows where s.isEnabled && s.kind == .drop {
            m = max(m, abs(s.distance.value(at: t)) + max(0, s.blur.value(at: t)) * 2.5)
        }
        if let g = glow, g.isEnabled { m = max(m, max(0, g.radius.value(at: t)) * 2.5) }
        return m.isFinite ? min(m, 2000) : 0
    }
}

// MARK: - Per-character styling

/// Overrides for one character (keyed by its stable id in `TextData.charStyles`).
struct TextCharStyle: Codable, Equatable {
    var fontName: String? = nil
    /// Percent of the text size (100 = unchanged).
    var sizePercent: Double? = nil
    var fill: RGBA? = nil
    var strokeColor: RGBA? = nil
    var strokeWidth: Double? = nil
    /// px, + = up.
    var baselineShift: Double? = nil

    var isEmpty: Bool { fontName == nil && sizePercent == nil && fill == nil && strokeColor == nil && strokeWidth == nil && baselineShift == nil }
}

/// How a selector combines with the result of the selectors above it (AE selector Mode).
enum SelectorMode: String, Codable, CaseIterable, Identifiable {
    case add, subtract, intersect, min, max, difference
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    func combine(_ a: Double, _ b: Double) -> Double {
        switch self {
        case .add: return Swift.min(1, Swift.max(-1, a + b))
        case .subtract: return Swift.min(1, Swift.max(-1, a - b))
        case .intersect: return a * b
        case .min: return Swift.min(a, b)
        case .max: return Swift.max(a, b)
        case .difference: return abs(a - b)
        }
    }
}

// MARK: - Stable character ids

extension TextData {
    static let styleAnimatorPrefix = "✦ "
    static let partAnimatorPrefix = "◆ "

    /// Ids parallel to the string's Characters (generated 1...n when missing or stale).
    var resolvedCharIDs: [UInt32] {
        let n = string.count
        if let ids = charIDs, ids.count == n { return ids }
        return (0..<n).map { UInt32($0 + 1) }
    }

    /// Makes sure `charIDs` matches the string (call before editing).
    mutating func ensureCharIDs() {
        let n = string.count
        if let ids = charIDs, ids.count == n {
            if nextCharID == nil { nextCharID = (ids.max() ?? 0) + 1 }
            return
        }
        var ids = charIDs ?? []
        if ids.count > n { ids = Array(ids.prefix(n)) }
        var next = max(nextCharID ?? 1, (ids.max() ?? 0) + 1)
        while ids.count < n { ids.append(next); next += 1 }
        charIDs = ids
        nextCharID = next
    }

    /// Replaces the characters in `range` (Character indices) with `replacement`.
    /// Untouched characters keep their ids, so spans / letter styles / split animators stay on the same letters.
    mutating func edit(replacing range: Range<Int>, with replacement: String) {
        migrateToCharIDs()
        var chars = Array(string)
        let lo = max(0, min(range.lowerBound, chars.count)), hi = max(lo, min(range.upperBound, chars.count))
        var ids = charIDs ?? []
        let removed = Set(ids[lo..<hi])
        var next = nextCharID ?? ((ids.max() ?? 0) + 1)
        let newChars = Array(replacement)
        var newIDs: [UInt32] = []
        for _ in newChars { newIDs.append(next); next &+= 1 }
        chars.replaceSubrange(lo..<hi, with: newChars)
        ids.replaceSubrange(lo..<hi, with: newIDs)
        string = String(chars)
        charIDs = ids
        nextCharID = next
        for k in colorSpans.indices { colorSpans[k].refreshIndices(ids) }
        guard !removed.isEmpty else { return }
        colorSpans = colorSpans.compactMap { span -> TextColorSpan? in
            var s = span
            s.ids = (s.ids ?? []).filter { !removed.contains($0) }
            if s.ids?.isEmpty ?? true { return nil }
            s.refreshIndices(ids)
            return s
        }
        if var cs = charStyles {
            for id in removed { cs[id] = nil }
            charStyles = cs.isEmpty ? nil : cs
        }
        for i in animators.indices {
            for k in animators[i].allSelectors.indices {
                if let t = animators[i].allSelectors[k].targetIDs {
                    animators[i].setSelector(k) { $0.targetIDs = t.filter { !removed.contains($0) } }
                }
            }
        }
    }

    /// Sets the whole string, keeping ids of the unchanged prefix and suffix (typing / pasting).
    mutating func setString(_ s: String) {
        let old = Array(string), new = Array(s)
        var p = 0
        while p < old.count, p < new.count, old[p] == new[p] { p += 1 }
        var q = 0
        while q < old.count - p, q < new.count - p, old[old.count - 1 - q] == new[new.count - 1 - q] { q += 1 }
        edit(replacing: p..<(old.count - q), with: String(new[p..<(new.count - q)]))
    }

    /// Converts index-based spans and the Letters section's ✦ / ◆ percent animators to character ids (idempotent).
    mutating func migrateToCharIDs() {
        ensureCharIDs()
        let ids = charIDs ?? []
        let n = ids.count
        for k in colorSpans.indices where colorSpans[k].ids == nil {
            let lo = max(0, min(colorSpans[k].start, n)), hi = max(lo, min(colorSpans[k].end, n))
            colorSpans[k].ids = Array(ids[lo..<hi])
        }
        guard n > 0 else { return }
        for i in animators.indices where animators[i].name.hasPrefix(Self.styleAnimatorPrefix) || animators[i].name.hasPrefix(Self.partAnimatorPrefix) {
            let s = animators[i].selector
            guard s.targetIDs == nil, s.kind == .range, s.shape == .square, s.basedOn == .characters,
                  s.start.keyframes.isEmpty, s.end.keyframes.isEmpty, s.offset.keyframes.isEmpty else { continue }
            let a = s.start.staticValue + s.offset.staticValue, b = s.end.staticValue + s.offset.staticValue
            let lo = max(0, min(n, Int((min(a, b) / 100 * Double(n)).rounded())))
            let hi = max(lo, min(n, Int((max(a, b) / 100 * Double(n)).rounded())))
            animators[i].selector.targetIDs = Array(ids[lo..<hi])
        }
    }

    /// The style override for the character at index `i` (nil = none).
    func charStyle(at i: Int) -> TextCharStyle? {
        guard let cs = charStyles, !cs.isEmpty else { return nil }
        let ids = resolvedCharIDs
        guard i >= 0, i < ids.count else { return nil }
        return cs[ids[i]]
    }

    /// Sets (or clears with nil) overrides for characters in `range`.
    mutating func setCharStyle(_ range: Range<Int>, _ change: (inout TextCharStyle) -> Void) {
        migrateToCharIDs()
        let ids = charIDs ?? []
        var cs = charStyles ?? [:]
        for i in range where i >= 0 && i < ids.count {
            var s = cs[ids[i]] ?? TextCharStyle()
            change(&s)
            cs[ids[i]] = s.isEmpty ? nil : s
        }
        charStyles = cs.isEmpty ? nil : cs
    }
}

extension TextColorSpan {
    /// Keeps start/end (used by older UI) in sync with the id list.
    mutating func refreshIndices(_ all: [UInt32]) {
        guard let ids, !ids.isEmpty else { return }
        let set = Set(ids)
        let idx = all.indices.filter { set.contains(all[$0]) }
        if let f = idx.first, let l = idx.last { start = f; end = l + 1 }
    }
}

// MARK: - Color helpers

extension RGBA {
    /// Rotates hue by `degrees` (keeps luma roughly, YIQ rotation).
    func hueShifted(_ degrees: Double) -> RGBA {
        guard degrees != 0, degrees.isFinite else { return self }
        let a = degrees * .pi / 180, c = cos(a), s = sin(a)
        let y = 0.299 * r + 0.587 * g + 0.114 * b
        let i = 0.596 * r - 0.274 * g - 0.322 * b
        let q = 0.211 * r - 0.523 * g + 0.312 * b
        let i2 = i * c - q * s, q2 = i * s + q * c
        func cl(_ v: Double) -> Double { min(1, max(0, v)) }
        return RGBA(cl(y + 0.956 * i2 + 0.621 * q2), cl(y - 0.272 * i2 - 0.647 * q2), cl(y - 1.106 * i2 + 1.703 * q2), self.a)
    }
}
