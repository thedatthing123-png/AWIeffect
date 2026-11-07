// DEVELOPER NOTE — Text Studio engine API (Part 1). Everything new is Optional so old projects decode unchanged.
//
// Model
// - TextData.style: TextStyleStack? — fills [TextFillLayer] (solid / linear / radial, colors + angle + opacity Animated,
//   space .glyph/.text), strokes [TextStrokeLayer] (color/width/opacity Animated, position outside/center/inside, join;
//   strokes[0] sits directly under the fill, later ones stack behind), shadows [TextShadowLayer] (.drop/.inner, color,
//   opacity, angle, distance, blur Animated), glow TextGlowLayer? (color, radius, intensity). When `style.fills` is empty
//   the legacy `fill` / color spans draw the letters. TextStyleStack.margin(at:) = draw reach beyond the outlines.
// - Stable character ids: TextData.charIDs ([UInt32] parallel to Array(string)) + nextCharID. ALWAYS change the string
//   through `edit(replacing: Range<Int>, with: String)` or `setString(_:)` so untouched letters keep their ids.
//   `resolvedCharIDs`, `ensureCharIDs()`, `migrateToCharIDs()` (runs automatically when a project loads).
//   Color spans carry `ids`; TextSelector.targetIDs selects exact letters (the Letters section's "✦ " letter styles and
//   "◆ " split parts are migrated to ids on load and on every edit).
// - Per-character overrides: TextData.charStyles [UInt32: TextCharStyle] (fontName, sizePercent, fill, strokeColor,
//   strokeWidth, baselineShift). Use `setCharStyle(range) { $0.fill = … }` and `charStyle(at:)`.
// - Paragraph: boxWidth (wrap width px), autoFit (shrink to fit boxWidth instead of wrapping), vertical (columns
//   top→bottom, right→left; CJK upright, Latin rotated), baselineShift (Animated, px up).
// - TextAnimator: `selector` is the first selector, `selectors` are ADDITIONAL ones stacked below it; use
//   `allSelectors` (get/set) or `setSelector(k) { … }` for the whole list. Each selector has `mode: SelectorMode?`
//   (add/subtract/intersect/min/max/difference, nil = add) combining it with the result above. Kinds: range, wiggly,
//   wave, random (per-unit random in min...max, seed), beat (pulses on project markers; beatAttack / beatDecay s).
//   Animated replacements: easeHighAnim, easeLowAnim, minAmountAnim, maxAmountAnim, seedAnim (read with
//   easeHighValue(at:), easeLowValue(at:), minAmountValue(at:), maxAmountValue(at:), seedValue(at:)).
//   `letterEffects: [EffectInstance]?` — pixel effects applied only to the letters the selectors pick (amount = mix).
//   `group: String?` — tag for preset-made animators (remove a preset by group).
// - TextAnimatorProperties new: anchor (Vec2 px), fillOpacity (%), strokeWidth (px added), strokeColor, baselineShift
//   (px up), glow (amount %), hueShift (deg), directionalBlur (px) + directionalBlurAngle (deg), scramble (% of letters
//   shown as random characters; they settle as it falls to 0), lineSpacing (px added per line), motionBlur (reserved).
// Engine
// - TextEngine.shared.layout(_ t: TextData, time: Double) -> TextLayout (LaidGlyph has charID, baseRotation).
// - TextEngine.glyphStates(_ t: TextData, layout: TextLayout, time: Double, beats: [Double] = []) -> [Renderer.GlyphState]
// - TextEngine.animatedBounds(_ t: TextData, layout: TextLayout, time: Double, beats: [Double] = [], track: PathTrack? = nil) -> CGRect —
//   bounds of the animated letters incl. style / blur / letter-effect margins (no clipping).
// - Renderer.textBounds(layer, time:) = unanimated layout bounds (handles, UI);
//   Renderer.textRenderBounds(layer, time:, beats:) = animated bounds used for buffers and motion blur.
// - SelectorMath.combinedAmount(_ a: TextAnimator, units: (TextSelector) -> (index: Int, count: Int), charID: UInt32,
//   time: Double, beats: [Double]) -> Double
import Foundation

enum TextAlignment: String, Codable, CaseIterable { case left, center, right }

/// A colored span inside the text (per-letter / per-word color).
struct TextColorSpan: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Character range [start, end) in the string's Character indices.
    var start: Int
    var end: Int
    var color: RGBA
    /// Stable character ids this span colors (preferred over start/end once present).
    var ids: [UInt32]? = nil
}

struct TextData: Codable, Equatable {
    var string: String
    var fontName: String = "Helvetica-Bold"
    var fontSize: Double = 120
    var fill = Animated(RGBA.white)
    var tracking = Animated(0.0)
    var lineSpacing = Animated(1.15)
    var alignment: TextAlignment = .center
    var colorSpans: [TextColorSpan] = []
    var animators: [TextAnimator] = []
    /// AE text on path: letters follow the text layer's first mask; offset slides them along it (% of length).
    var onPath: Bool? = nil
    var pathOffset: Animated<Double>? = nil
    /// Counter / timer mode: the shown text comes from an animated number (keyframe it, shape it with the graph).
    var counter: TextCounter? = nil
    /// Outline the whole text instead of filling it (stroke width px, 0 = solid).
    var outline: Double? = nil
    /// Where spacing grows from: 0 = left, 1 = center, 2 = right (nil = same as the alignment).
    var spacingAnchor: Int? = nil
    /// Style stack (multiple fills, strokes, shadows, glow). nil = legacy single fill.
    var style: TextStyleStack? = nil
    /// Stable ids parallel to the string's Characters (see DEVELOPER NOTE).
    var charIDs: [UInt32]? = nil
    var nextCharID: UInt32? = nil
    /// Per-character overrides keyed by character id.
    var charStyles: [UInt32: TextCharStyle]? = nil
    /// Paragraph box width in px (wrap). nil = no box.
    var boxWidth: Double? = nil
    /// Shrink the text to fit `boxWidth` instead of wrapping.
    var autoFit: Bool? = nil
    /// Vertical text: columns top→bottom, right→left.
    var vertical: Bool? = nil
    /// Whole-text baseline shift, px (+ = up).
    var baselineShift: Animated<Double>? = nil
    /// Real extruded 3D look (Part 4 materials); set by 3D Look presets. nil = flat text.
    var text3D: Text3DOptions? = nil
    /// Preset group (Look id) that set `text3D`; nil = set by the user.
    var text3DGroup: String? = nil

    enum CodingKeys: String, CodingKey {
        case string, fontName, fontSize, fill, tracking, lineSpacing, alignment, colorSpans, animators, onPath, pathOffset
        case counter, outline, spacingAnchor, style, charIDs, nextCharID, charStyles, boxWidth, autoFit, vertical, baselineShift, text3D, text3DGroup
    }

    /// The text as drawn at `time` (the counter's value when counting).
    func resolved(at time: Double) -> TextData {
        guard let c = counter else { return self }
        var x = self
        x.string = c.string(at: time)
        return x
    }

    func baseColor(forCharacter i: Int, time: Double) -> RGBA {
        baseColorOverride(forCharacter: i, ids: resolvedCharIDs) ?? fill.value(at: time)
    }

    /// The per-character color (char style fill, then color span), nil = the text fill.
    func baseColorOverride(forCharacter i: Int, ids: [UInt32]) -> RGBA? {
        let id: UInt32? = i >= 0 && i < ids.count ? ids[i] : nil
        if let id, let f = charStyles?[id]?.fill { return f }
        if let span = colorSpans.last(where: { sp in
            if let sIDs = sp.ids, let id { return sIDs.contains(id) }
            return i >= sp.start && i < sp.end
        }) { return span.color }
        return nil
    }
}

extension TextData {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        string = try c.decode(String.self, forKey: .string)
        fontName = try c.decodeIfPresent(String.self, forKey: .fontName) ?? "Helvetica-Bold"
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize) ?? 120
        fill = try c.decodeIfPresent(Animated<RGBA>.self, forKey: .fill) ?? Animated(RGBA.white)
        tracking = try c.decodeIfPresent(Animated<Double>.self, forKey: .tracking) ?? Animated(0.0)
        lineSpacing = try c.decodeIfPresent(Animated<Double>.self, forKey: .lineSpacing) ?? Animated(1.15)
        alignment = try c.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? .center
        colorSpans = try c.decodeIfPresent([TextColorSpan].self, forKey: .colorSpans) ?? []
        animators = try c.decodeIfPresent([TextAnimator].self, forKey: .animators) ?? []
        onPath = try c.decodeIfPresent(Bool.self, forKey: .onPath)
        pathOffset = try c.decodeIfPresent(Animated<Double>.self, forKey: .pathOffset)
        counter = try c.decodeIfPresent(TextCounter.self, forKey: .counter)
        outline = try c.decodeIfPresent(Double.self, forKey: .outline)
        spacingAnchor = try c.decodeIfPresent(Int.self, forKey: .spacingAnchor)
        style = try c.decodeIfPresent(TextStyleStack.self, forKey: .style)
        charIDs = try c.decodeIfPresent([UInt32].self, forKey: .charIDs)
        nextCharID = try c.decodeIfPresent(UInt32.self, forKey: .nextCharID)
        charStyles = try c.decodeIfPresent([UInt32: TextCharStyle].self, forKey: .charStyles)
        boxWidth = try c.decodeIfPresent(Double.self, forKey: .boxWidth)
        autoFit = try c.decodeIfPresent(Bool.self, forKey: .autoFit)
        vertical = try c.decodeIfPresent(Bool.self, forKey: .vertical)
        baselineShift = try c.decodeIfPresent(Animated<Double>.self, forKey: .baselineShift)
        text3D = try c.decodeIfPresent(Text3DOptions.self, forKey: .text3D)
        text3DGroup = try c.decodeIfPresent(String.self, forKey: .text3DGroup)
        // Older saves: give letters ids and move index / percent targets onto them. Counter text changes every
        // frame, so it keeps index targeting.
        if counter == nil { migrateToCharIDs() }
    }
}

// MARK: - Animators (AE Text Animator model)

/// Units a selector counts in (AE "Based On").
enum TextUnit: String, Codable, CaseIterable, Identifiable {
    case characters, charactersExcludingSpaces, words, lines
    var id: String { rawValue }
    var title: String {
        switch self {
        case .characters: return "Characters"
        case .charactersExcludingSpaces: return "Characters Excl. Spaces"
        case .words: return "Words"
        case .lines: return "Lines"
        }
    }
}

/// AE Range Selector shapes.
enum SelectorShape: String, Codable, CaseIterable, Identifiable {
    case square, rampUp, rampDown, triangle, round, smooth
    var id: String { rawValue }
    var title: String {
        switch self {
        case .square: return "Square"
        case .rampUp: return "Ramp Up"
        case .rampDown: return "Ramp Down"
        case .triangle: return "Triangle"
        case .round: return "Round"
        case .smooth: return "Smooth"
        }
    }
}

enum SelectorKind: String, Codable, CaseIterable {
    /// AE Range Selector.
    case range
    /// AE Wiggly Selector: per-unit random amount that drifts over time.
    case wiggly
    /// Sine wave travelling across units (common "wave" text, AE does it with an Expression Selector).
    case wave
    /// Per-unit random amount between min and max (seeded, steady over time).
    case random
    /// Amount pulses on the project's beat markers (attack / decay).
    case beat
}

struct TextSelector: Codable, Equatable {
    var kind: SelectorKind = .range
    var basedOn: TextUnit = .characters
    // Range
    var start = Animated(0.0)          // percent
    var end = Animated(100.0)          // percent
    var offset = Animated(0.0)         // percent
    var shape: SelectorShape = .square
    var easeHigh = 0.0                 // percent, -100...100
    var easeLow = 0.0
    var randomize = false
    var seed = 0
    var amount = Animated(100.0)       // percent
    // Wiggly / wave
    var frequency = Animated(2.0)      // wiggles or waves per second
    var spread = Animated(3.0)         // wave: units per cycle; wiggly: correlation (unused = 0)
    var minAmount = -100.0
    var maxAmount = 100.0
    /// How this selector combines with the selectors above it (nil = add).
    var mode: SelectorMode? = nil
    /// Exact letters by stable character id (overrides start/end/offset/basedOn when set).
    var targetIDs: [UInt32]? = nil
    /// Animated replacements for the fixed values above (nil = use the fixed value).
    var easeHighAnim: Animated<Double>? = nil
    var easeLowAnim: Animated<Double>? = nil
    var minAmountAnim: Animated<Double>? = nil
    var maxAmountAnim: Animated<Double>? = nil
    var seedAnim: Animated<Double>? = nil
    /// Beat selector: seconds to rise before a beat / to fall after it.
    var beatAttack: Animated<Double>? = nil
    var beatDecay: Animated<Double>? = nil

    func easeHighValue(at t: Double) -> Double { easeHighAnim?.value(at: t) ?? easeHigh }
    func easeLowValue(at t: Double) -> Double { easeLowAnim?.value(at: t) ?? easeLow }
    func minAmountValue(at t: Double) -> Double { minAmountAnim?.value(at: t) ?? minAmount }
    func maxAmountValue(at t: Double) -> Double { maxAmountAnim?.value(at: t) ?? maxAmount }
    func seedValue(at t: Double) -> Int {
        guard let v = seedAnim?.value(at: t), v.isFinite else { return seed }
        return Int(max(-1e9, min(1e9, v)).rounded(.down))
    }
}

/// Properties an animator offsets. nil = not used (like AE's "Add Property" list).
struct TextAnimatorProperties: Codable, Equatable {
    var position: Animated<Vec2>? = nil
    var scale: Animated<Vec2>? = nil      // percent, absolute target (100 = no change)
    var rotation: Animated<Double>? = nil // degrees
    var opacity: Animated<Double>? = nil  // percent target (100 = no change)
    var fill: Animated<RGBA>? = nil
    var tracking: Animated<Double>? = nil // px added between units
    var skew: Animated<Double>? = nil     // degrees
    /// Per-letter blur, px (AE text animator Blur).
    var blur: Animated<Double>? = nil
    /// AE Character Offset: shifts each letter through the alphabet / digits (scramble, decode).
    var characterOffset: Animated<Double>? = nil
    /// Per-character 3D: flip around X / Y (degrees) and push in depth (px, + = away).
    var rotationX: Animated<Double>? = nil
    var rotationY: Animated<Double>? = nil
    var positionZ: Animated<Double>? = nil
    /// Outline only: letters become hollow outlines this thick (px). 0 = solid.
    var outline: Animated<Double>? = nil
    /// Pivot offset (px) for scale / rotation / 3D of each letter.
    var anchor: Animated<Vec2>? = nil
    /// Fill-only opacity target, percent (strokes / shadows stay).
    var fillOpacity: Animated<Double>? = nil
    /// px added to every stroke layer's width.
    var strokeWidth: Animated<Double>? = nil
    var strokeColor: Animated<RGBA>? = nil
    /// px, + = up.
    var baselineShift: Animated<Double>? = nil
    /// Per-letter glow amount, percent.
    var glow: Animated<Double>? = nil
    /// Degrees.
    var hueShift: Animated<Double>? = nil
    /// Directional blur length px and its angle (degrees, 0 = horizontal).
    var directionalBlur: Animated<Double>? = nil
    var directionalBlurAngle: Animated<Double>? = nil
    /// Percent of letters replaced by random characters (they settle as this goes to 0).
    var scramble: Animated<Double>? = nil
    /// px added between lines.
    var lineSpacing: Animated<Double>? = nil
    /// Reserved: per-letter motion blur.
    var motionBlur: Bool? = nil
}

struct TextAnimator: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var isEnabled = true
    var selector = TextSelector()
    var properties = TextAnimatorProperties()
    /// Additional selectors stacked under `selector` (each combines by its `mode`).
    var selectors: [TextSelector]? = nil
    /// Pixel effects applied only to the letters this animator selects (selection amount = mix).
    var letterEffects: [EffectInstance]? = nil
    /// Preset group tag (presets add animators with a group so they can be removed together).
    var group: String? = nil

    /// Every selector, first = `selector`.
    var allSelectors: [TextSelector] {
        get { [selector] + (selectors ?? []) }
        set {
            if let f = newValue.first { selector = f }
            let rest = Array(newValue.dropFirst())
            selectors = rest.isEmpty ? nil : rest
        }
    }

    mutating func setSelector(_ k: Int, _ change: (inout TextSelector) -> Void) {
        var all = allSelectors
        guard k >= 0, k < all.count else { return }
        change(&all[k])
        allSelectors = all
    }
}

// MARK: - Selector math

enum SelectorMath {
    /// Selection amount (−1...1, usually 0...1) for unit `index` of `count` at `time`.
    static func amount(_ s: TextSelector, index: Int, count: Int, time: Double, beats: [Double] = []) -> Double {
        guard count > 0 else { return 0 }
        let amt = s.amount.value(at: time) / 100
        switch s.kind {
        case .range:
            let order = s.randomize ? randomOrder(count: count, seed: s.seedValue(at: time))[min(max(0, index), count - 1)] : index
            return rangeCoverage(s, unit: order, count: count, time: time) * amt
        case .wiggly:
            let f = s.frequency.value(at: time)
            let n = Wiggle.value(t: time, freq: max(0.01, f), octaves: 1, seed: Double(index) * 7.13 + Double(s.seedValue(at: time)))
            let lo = s.minAmountValue(at: time) / 100, hi = s.maxAmountValue(at: time) / 100
            return (lo + (n * 0.5 + 0.5) * (hi - lo)) * amt
        case .random:
            let lo = s.minAmountValue(at: time) / 100, hi = s.maxAmountValue(at: time) / 100
            return (lo + hash01(index, s.seedValue(at: time)) * (hi - lo)) * amt
        case .beat:
            return beatEnvelope(time, beats: beats, attack: s.beatAttack?.value(at: time) ?? 0.03,
                                decay: s.beatDecay?.value(at: time) ?? 0.25) * amt
        case .wave:
            let f = s.frequency.value(at: time)
            let spread = max(0.1, s.spread.value(at: time))
            return sin(2 * .pi * (time * f - Double(index) / spread)) * amt
        }
    }

    /// AE range selector coverage for one unit, with shape and ease.
    static func rangeCoverage(_ s: TextSelector, unit: Int, count: Int, time: Double) -> Double {
        let off = s.offset.value(at: time)
        var a = s.start.value(at: time) + off
        var b = s.end.value(at: time) + off
        if a > b { swap(&a, &b) }
        let u0 = Double(unit) / Double(count) * 100, u1 = Double(unit + 1) / Double(count) * 100
        let uc = (u0 + u1) / 2
        switch s.shape {
        case .square:
            // Fraction of the unit's span inside [a, b].
            let overlap = max(0, min(b, u1) - max(a, u0))
            return overlap / max(u1 - u0, 1e-9)
        case .rampUp, .rampDown, .triangle, .round, .smooth:
            let span = max(b - a, 1e-9)
            let t = (uc - a) / span
            var v: Double
            switch s.shape {
            case .rampUp: v = t <= 0 ? 0 : (t >= 1 ? 1 : t)
            case .rampDown: v = t <= 0 ? 1 : (t >= 1 ? 0 : 1 - t)
            case .triangle: v = (t <= 0 || t >= 1) ? 0 : 1 - abs(2 * t - 1)
            case .round: v = (t <= 0 || t >= 1) ? 0 : (1 - pow(2 * t - 1, 2)).squareRoot()
            default: v = (t <= 0 || t >= 1) ? 0 : 0.5 - 0.5 * cos(2 * .pi * t)
            }
            return ease(v, high: s.easeHighValue(at: time) / 100, low: s.easeLowValue(at: time) / 100)
        }
    }

    /// Ease High flattens the top of the curve, Ease Low the bottom (AE semantics: positive = slower).
    static func ease(_ v: Double, high: Double, low: Double) -> Double {
        guard high != 0 || low != 0 else { return v }
        let p1 = EaseHandle(x: max(0, low) / 3, y: 0)
        let p2 = EaseHandle(x: 1 - max(0, high) / 3, y: 1)
        return BezierTiming.progress(x: v, p1: low >= 0 ? p1 : EaseHandle(x: 1.0 / 3, y: 1.0 / 3 - low / 3),
                                     p2: high >= 0 ? p2 : EaseHandle(x: 2.0 / 3, y: 2.0 / 3 + high / 3))
    }

    /// Stable 0...1 hash of a unit and seed.
    static func hash01(_ i: Int, _ seed: Int) -> Double {
        var x = UInt64(bitPattern: Int64((i &* 73856093) ^ (seed &* 19349663))) &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        x = x ^ (x >> 31)
        return Double(x >> 11) / 9007199254740992.0
    }

    /// 0...1 pulse: rises over `attack` s up to each beat, decays exponentially over `decay` s after it.
    static func beatEnvelope(_ t: Double, beats: [Double], attack: Double, decay: Double) -> Double {
        let a = max(0.001, attack), d = max(0.001, decay)
        var best = 0.0
        for b in beats {
            let dt = t - b
            if dt < -a || dt > d * 4 { continue }
            let v = dt < 0 ? 1 + dt / a : exp(-dt / d * 3)
            best = max(best, v)
        }
        return best
    }

    /// The combined selection of every selector on an animator for one letter.
    /// `units` returns the (index, count) of the letter in the selector's Based On units.
    static func combinedAmount(_ a: TextAnimator, units: (TextSelector) -> (index: Int, count: Int), charID: UInt32,
                               time: Double, beats: [Double] = []) -> Double {
        var v = 0.0
        for (k, s) in a.allSelectors.enumerated() {
            let x: Double
            if let ids = s.targetIDs {
                x = ids.contains(charID) ? s.amount.value(at: time) / 100 : 0
            } else {
                let u = units(s)
                x = amount(s, index: u.index, count: u.count, time: time, beats: beats)
            }
            v = k == 0 ? x : (s.mode ?? .add).combine(v, x)
        }
        return v.isFinite ? v : 0
    }

    static func randomOrder(count: Int, seed: Int) -> [Int] {
        var idx = Array(0..<count)
        var state = UInt64(truncatingIfNeeded: seed &* 2654435761 &+ 1)
        for i in stride(from: count - 1, to: 0, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((state >> 33) % UInt64(i + 1))
            idx.swapAt(i, j)
        }
        return idx
    }
}

// MARK: - Presets (premade text animations — each one built from real animators)

struct TextPreset: Identifiable {
    let id: String
    let name: String
    var category: String = "In"
    let make: (_ start: Double, _ duration: Double) -> [TextAnimator]

    /// Category shown in the library (TextPresetLibrary.categories). Older built-ins are refiled by what they do.
    var shownCategory: String { TextPresetLibrary.libraryCategory(id: id, sourceCategory: category) }

    /// Everything in the library (animation presets): unique names, every older id still resolves.
    static var library: [TextPreset] { TextPresetLibrary.animations }
}

/// Counter / timer text (Alight Motion-style): a number that counts, or a clock that ticks.
struct TextCounter: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable { case number, timer }
    var mode: Mode = .number
    /// The number shown (seconds in timer mode). Keyframe it; the graph shapes its speed.
    var value = Animated(0.0)
    var decimals = 0
    var prefix = ""
    var suffix = ""
    /// 1,000 style thousands separator.
    var separator = true
    /// Timer layout: 0 = 00:00, 1 = 00:00:00, 2 = 00:00.00
    var timerStyle = 0

    func string(at t: Double) -> String {
        let v = value.value(at: t)
        guard v.isFinite else { return prefix + "0" + suffix }
        switch mode {
        case .number:
            let f = NumberFormatter()
            f.locale = Locale(identifier: "en_US")
            f.numberStyle = .decimal
            f.usesGroupingSeparator = separator
            f.minimumFractionDigits = max(0, decimals)
            f.maximumFractionDigits = max(0, decimals)
            let clamped = min(max(v, -1e15), 1e15)
            return prefix + (f.string(from: NSNumber(value: clamped)) ?? "0") + suffix
        case .timer:
            let neg = v < 0
            let s = min(abs(v), 359_999)
            let h = Int(s) / 3600, m = (Int(s) % 3600) / 60, sec = Int(s) % 60
            let cs = Int((s - floor(s)) * 100)
            let body: String
            switch timerStyle {
            case 1: body = String(format: "%02d:%02d:%02d", h, m, sec)
            case 2: body = String(format: "%02d:%02d.%02d", h * 60 + m, sec, cs)
            default: body = String(format: "%02d:%02d", h * 60 + m, sec)
            }
            return prefix + (neg ? "-" : "") + body + suffix
        }
    }
}

enum TextPresets {
    private static func kf<V: Interpolatable>(_ pairs: [(Double, V)], interp: Interpolation = .bezier) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs { a.insertKeyframe(Keyframe(time: t, value: v, interpolation: interp)) }
        return a
    }

    /// A range-selector reveal: a soft window [start, start+soft] sweeps across the text.
    /// Units before the window are finished (amount 0), units after it are still fully offset (amount 1),
    /// units inside it are in transition. With `.triangle` the window itself is selected (overshoot accents).
    private static func sweep(_ s: Double, _ d: Double, shape: SelectorShape = .rampUp, basedOn: TextUnit = .characters,
                              soft: Double = 30, easeHigh: Double = 0) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = basedOn
        sel.shape = shape
        sel.easeHigh = easeHigh
        sel.start = kf([(s, -soft), (s + d, 100.0)])
        sel.end = kf([(s, 0.0), (s + d, 100.0 + soft)])
        return sel
    }

    static let all: [TextPreset] = extra + [
        TextPreset(id: "typewriter", name: "Typewriter") { s, d in
            var a = TextAnimator(name: "Typewriter")
            a.selector = TextSelector(basedOn: .characters, start: kf([(s, 0.0), (s + d, 100.0)], interp: .linear), shape: .square)
            a.properties.opacity = Animated(0)
            // Selected = already typed, so invert: animate the start of the hidden range.
            a.selector.start = kf([(s, 0.0), (s + d, 100.0)], interp: .linear)
            a.selector.end = Animated(100)
            return [a]
        },
        TextPreset(id: "fadeUp", name: "Fade Up") { s, d in
            var a = TextAnimator(name: "Fade Up")
            a.selector = sweep(s, d, shape: .rampUp, soft: 40)
            a.properties.opacity = Animated(0)
            a.properties.position = Animated(Vec2(0, 60))
            return [a]
        },
        TextPreset(id: "bounceIn", name: "Bounce In") { s, d in
            var a = TextAnimator(name: "Bounce In")
            a.selector = sweep(s, d, shape: .rampUp, soft: 30)
            a.properties.scale = Animated(Vec2(0, 0))
            a.properties.opacity = Animated(0)
            a.properties.position = Animated(Vec2(0, -80))
            var b = TextAnimator(name: "Overshoot")
            b.selector = sweep(s + d * 0.15, d, shape: .triangle, soft: 30)
            b.properties.scale = Animated(Vec2(125, 125))
            return [a, b]
        },
        TextPreset(id: "scalePop", name: "Scale Pop") { s, d in
            var a = TextAnimator(name: "Scale Pop")
            a.selector.amount = kf([(s, 100.0), (s + d * 0.6, -18.0), (s + d, 0.0)])
            a.properties.scale = Animated(Vec2(0, 0))
            return [a]
        },
        TextPreset(id: "slideStagger", name: "Slide Stagger") { s, d in
            var a = TextAnimator(name: "Slide")
            a.selector = sweep(s, d, shape: .rampUp, basedOn: .words, soft: 50, easeHigh: 60)
            a.properties.position = Animated(Vec2(-220, 0))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "wave", name: "Wave") { _, _ in
            var a = TextAnimator(name: "Wave")
            a.selector.kind = .wave
            a.selector.frequency = Animated(1.2)
            a.selector.spread = Animated(6)
            a.properties.position = Animated(Vec2(0, -28))
            return [a]
        },
        TextPreset(id: "glitch", name: "Glitch") { s, d in
            var a = TextAnimator(name: "Glitch Jitter")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(14)
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            a.properties.position = Animated(Vec2(24, 6))
            a.properties.skew = Animated(14)
            var b = TextAnimator(name: "Glitch Color")
            b.selector.kind = .wiggly
            b.selector.frequency = Animated(10)
            b.selector.seed = 7
            b.selector.minAmount = 0
            b.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            b.properties.fill = Animated(RGBA(hex: 0x5CFFF0))
            return [a, b]
        },
        TextPreset(id: "flicker", name: "Flicker In") { s, d in
            var a = TextAnimator(name: "Flicker")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(18)
            a.selector.minAmount = 0
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)], interp: .linear)
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "trackingIn", name: "Tracking In") { s, d in
            var a = TextAnimator(name: "Tracking In")
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)])
            a.properties.tracking = Animated(80)
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "spinIn", name: "Spin In") { s, d in
            var a = TextAnimator(name: "Spin In")
            a.selector = sweep(s, d, shape: .rampUp, soft: 40)
            a.properties.rotation = Animated(-180)
            a.properties.scale = Animated(Vec2(0, 0))
            return [a]
        },
        TextPreset(id: "dropIn", name: "Drop In (Words)") { s, d in
            var a = TextAnimator(name: "Drop In")
            a.selector = sweep(s, d, shape: .rampUp, basedOn: .words, soft: 30)
            a.properties.position = Animated(Vec2(0, -300))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "colorSweep", name: "Color Sweep") { s, d in
            var a = TextAnimator(name: "Color Sweep")
            var sel = TextSelector()
            sel.shape = .smooth
            sel.start = Animated(0)
            sel.end = Animated(35)
            sel.offset = kf([(s, -35.0), (s + d, 100.0)], interp: .linear)
            a.selector = sel
            a.properties.fill = Animated(RGBA(hex: 0xB98CFF))
            a.properties.scale = Animated(Vec2(118, 118))
            return [a]
        },
        // MARK: More ins
        TextPreset(id: "elasticPop", name: "Elastic Pop") { s, d in
            var a = TextAnimator(name: "Elastic")
            a.selector = sweep(s, d, shape: .rampUp, soft: 25)
            a.properties.scale = Animated(Vec2(0, 0))
            var b = TextAnimator(name: "Overshoot")
            b.selector = sweep(s + d * 0.1, d, shape: .triangle, soft: 25)
            b.properties.scale = Animated(Vec2(150, 60))
            return [a, b]
        },
        TextPreset(id: "zoomBig", name: "Zoom From Big") { s, d in
            var a = TextAnimator(name: "Zoom")
            a.selector = sweep(s, d, shape: .rampUp, soft: 50)
            a.properties.scale = Animated(Vec2(420, 420))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "rotateDrop", name: "Rotate Drop") { s, d in
            var a = TextAnimator(name: "Rotate Drop")
            a.selector = sweep(s, d, shape: .rampUp, soft: 35)
            a.properties.rotation = Animated(90)
            a.properties.position = Animated(Vec2(0, -120))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "skewSlide", name: "Skew Slide") { s, d in
            var a = TextAnimator(name: "Skew Slide")
            a.selector = sweep(s, d, shape: .rampUp, soft: 40)
            a.properties.skew = Animated(45)
            a.properties.position = Animated(Vec2(-140, 0))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "randomPop", name: "Random Pop") { s, d in
            var a = TextAnimator(name: "Random Pop")
            a.selector = sweep(s, d, shape: .rampUp, soft: 20)
            a.selector.randomize = true
            a.selector.seed = 3
            a.properties.scale = Animated(Vec2(0, 0))
            return [a]
        },
        TextPreset(id: "scatterIn", name: "Scatter In") { s, d in
            var a = TextAnimator(name: "Scatter")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(0.01)
            a.selector.amount = kf([(s, 100.0), (s + d, 0.0)])
            a.properties.position = Animated(Vec2(260, 200))
            a.properties.rotation = Animated(180)
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "wordPop", name: "Word Pop") { s, d in
            var a = TextAnimator(name: "Word Pop")
            a.selector = sweep(s, d, shape: .rampUp, basedOn: .words, soft: 20)
            a.properties.scale = Animated(Vec2(0, 0))
            var b = TextAnimator(name: "Word Overshoot")
            b.selector = sweep(s + d * 0.1, d, shape: .triangle, basedOn: .words, soft: 25)
            b.properties.scale = Animated(Vec2(135, 135))
            b.properties.fill = Animated(RGBA(hex: 0xFFD25C))
            return [a, b]
        },
        TextPreset(id: "smoothFade", name: "Smooth Fade") { s, d in
            var a = TextAnimator(name: "Smooth Fade")
            a.selector = sweep(s, d, shape: .smooth, soft: 80)
            a.properties.opacity = Animated(0)
            return [a]
        },
        // MARK: Outs
        TextPreset(id: "fadeOut", name: "Fade Out") { s, d in
            var a = TextAnimator(name: "Fade Out")
            a.selector = sweep(s, d, shape: .rampDown, soft: 40)
            a.properties.opacity = Animated(0)
            a.properties.position = Animated(Vec2(0, -60))
            return [a]
        },
        TextPreset(id: "fallOut", name: "Fall Out") { s, d in
            var a = TextAnimator(name: "Fall Out")
            a.selector = sweep(s, d, shape: .rampDown, soft: 30)
            a.properties.position = Animated(Vec2(0, 320))
            a.properties.rotation = Animated(60)
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "shrinkOut", name: "Shrink Out") { s, d in
            var a = TextAnimator(name: "Shrink Out")
            a.selector = sweep(s, d, shape: .rampDown, soft: 30)
            a.properties.scale = Animated(Vec2(0, 0))
            return [a]
        },
        TextPreset(id: "typeOut", name: "Typewriter Out") { s, d in
            var a = TextAnimator(name: "Type Out")
            a.selector.start = Animated(0)
            a.selector.end = kf([(s, 0.0), (s + d, 100.0)], interp: .linear)
            a.selector.shape = .square
            a.properties.opacity = Animated(0)
            return [a]
        },
        // MARK: Loops
        TextPreset(id: "jelly", name: "Jelly") { _, _ in
            var a = TextAnimator(name: "Jelly")
            a.selector.kind = .wave
            a.selector.frequency = Animated(1.6)
            a.selector.spread = Animated(4)
            a.properties.scale = Animated(Vec2(130, 75))
            return [a]
        },
        TextPreset(id: "swingLetters", name: "Swing") { _, _ in
            var a = TextAnimator(name: "Swing")
            a.selector.kind = .wave
            a.selector.frequency = Animated(0.9)
            a.selector.spread = Animated(8)
            a.properties.rotation = Animated(22)
            return [a]
        },
        TextPreset(id: "shakeLetters", name: "Shake") { _, _ in
            var a = TextAnimator(name: "Shake")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(16)
            a.properties.position = Animated(Vec2(10, 10))
            a.properties.rotation = Animated(8)
            return [a]
        },
        TextPreset(id: "rainbow", name: "Rainbow Wave") { _, _ in
            var a = TextAnimator(name: "Rainbow A")
            a.selector.kind = .wave
            a.selector.frequency = Animated(0.8)
            a.selector.spread = Animated(5)
            a.selector.minAmount = 0
            a.properties.fill = Animated(RGBA(hex: 0xFF5CA8))
            var b = TextAnimator(name: "Rainbow B")
            b.selector.kind = .wave
            b.selector.frequency = Animated(0.8)
            b.selector.spread = Animated(5)
            b.selector.offset = Animated(50)
            b.selector.minAmount = 0
            b.properties.fill = Animated(RGBA(hex: 0x5CC8FF))
            return [a, b]
        },
        TextPreset(id: "karaoke", name: "Karaoke Highlight") { s, d in
            var a = TextAnimator(name: "Karaoke")
            a.selector = sweep(s, d, shape: .rampDown, basedOn: .characters, soft: 5)
            a.properties.fill = Animated(RGBA(hex: 0xFFD25C))
            return [a]
        },
    ]
}


// MARK: - Blur / decode presets (use the per-letter Blur and Character Offset properties)

extension TextPresets {
    private static func k<V: Interpolatable>(_ pairs: [(Double, V)], interp: Interpolation = .bezier) -> Animated<V> {
        var a = Animated(pairs[0].1)
        for (t, v) in pairs { a.insertKeyframe(Keyframe(time: t, value: v, interpolation: interp)) }
        return a
    }

    /// Window [start, start+soft] sweeping across the text (units behind it are done).
    private static func wipe(_ s: Double, _ d: Double, _ basedOn: TextUnit = .characters, soft: Double = 35) -> TextSelector {
        var sel = TextSelector()
        sel.basedOn = basedOn
        sel.shape = .rampUp
        sel.start = k([(s, -soft), (s + d, 100.0)])
        sel.end = k([(s, 0.0), (s + d, 100.0 + soft)])
        return sel
    }

    static let extra: [TextPreset] = [
        TextPreset(id: "blurIn", name: "Blur In") { s, d in
            var a = TextAnimator(name: "Blur In")
            a.selector = wipe(s, d, soft: 45)
            a.properties.blur = Animated(18)
            a.properties.opacity = Animated(0)
            a.properties.scale = Animated(Vec2(130, 130))
            return [a]
        },
        TextPreset(id: "focusPull", name: "Focus Pull") { s, d in
            var a = TextAnimator(name: "Focus")
            a.selector.amount = k([(s, 100.0), (s + d, 0.0)])
            a.properties.blur = Animated(24)
            a.properties.tracking = Animated(30)
            return [a]
        },
        TextPreset(id: "decode", name: "Decode") { s, d in
            var a = TextAnimator(name: "Decode")
            a.selector = wipe(s, d, soft: 25)
            a.properties.characterOffset = Animated(14)
            var f = TextAnimator(name: "Decode Color")
            f.selector = wipe(s, d, soft: 25)
            f.properties.fill = Animated(RGBA(hex: 0x5CFFB0))
            return [a, f]
        },
        TextPreset(id: "scramble", name: "Scramble") { s, d in
            var a = TextAnimator(name: "Scramble")
            a.selector.kind = .wiggly
            a.selector.frequency = Animated(12)
            a.selector.minAmount = 0
            a.selector.amount = k([(s, 100.0), (s + d, 0.0)], interp: .linear)
            a.properties.characterOffset = Animated(20)
            return [a]
        },
        TextPreset(id: "blurSlideWords", name: "Blur Slide (Words)") { s, d in
            var a = TextAnimator(name: "Blur Slide")
            a.selector = wipe(s, d, .words, soft: 50)
            a.properties.blur = Animated(14)
            a.properties.position = Animated(Vec2(120, 0))
            a.properties.opacity = Animated(0)
            return [a]
        },
        TextPreset(id: "dreamy", name: "Dreamy Float") { s, d in
            var a = TextAnimator(name: "Float")
            a.selector = wipe(s, d, soft: 60)
            a.properties.blur = Animated(10)
            a.properties.position = Animated(Vec2(0, 40))
            a.properties.opacity = Animated(0)
            var w = TextAnimator(name: "Drift")
            w.selector.kind = .wave
            w.selector.frequency = Animated(0.6)
            w.selector.spread = Animated(8)
            w.properties.position = Animated(Vec2(0, -8))
            return [a, w]
        },
        TextPreset(id: "glitchDecode", name: "Glitch Decode") { s, d in
            var a = TextAnimator(name: "Decode")
            a.selector = wipe(s, d, soft: 20)
            a.properties.characterOffset = Animated(9)
            a.properties.opacity = Animated(40)
            var j = TextAnimator(name: "Jitter")
            j.selector.kind = .wiggly
            j.selector.frequency = Animated(16)
            j.selector.amount = k([(s, 100.0), (s + d, 0.0)], interp: .linear)
            j.properties.position = Animated(Vec2(14, 4))
            j.properties.blur = Animated(4)
            return [a, j]
        },
        TextPreset(id: "impactSlam", name: "Impact Slam") { s, d in
            var a = TextAnimator(name: "Slam")
            a.selector = wipe(s, d * 0.6, soft: 20)
            a.properties.scale = Animated(Vec2(320, 320))
            a.properties.blur = Animated(12)
            a.properties.opacity = Animated(0)
            return [a]
        },
    ]
}
