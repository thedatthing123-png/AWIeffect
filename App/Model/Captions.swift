import Foundation

// MARK: - Captions & lyrics (Text Studio Part 5)
//
// A caption track is a list of timed words grouped into lines. Applying it builds ordinary text layers
// (one per line) whose per-word karaoke highlight is made only of today's TextAnimator range selectors,
// so captions stay fully editable in Text Studio and render with the existing text engine.

/// One recognised (or typed) word, in composition seconds.
struct CaptionWord: Codable, Equatable, Identifiable {
    var id = UUID()
    var text: String
    var start: Double
    var end: Double

    init(id: UUID = UUID(), text: String, start: Double, end: Double) {
        self.id = id
        self.text = text
        self.start = start
        self.end = max(end, start)
    }
}

/// How the word being sung / spoken stands out.
enum CaptionHighlight: String, Codable, CaseIterable, Identifiable {
    case none, fill, scale, glow, box, karaokeWipe
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .fill: return "Fill"
        case .scale: return "Scale"
        case .glow: return "Glow"
        case .box: return "Box"
        case .karaokeWipe: return "Karaoke Wipe"
        }
    }
    /// Modes that need a second text layer under the line (glow halo / box blob).
    var usesUnderlay: Bool { self == .glow || self == .box }
}

/// Rules that split words into caption lines.
struct CaptionGrouping: Codable, Equatable {
    /// Longest line in characters (spaces included).
    var maxCharacters: Int = 32
    /// Longest time a line stays up, seconds.
    var maxDuration: Double = 3.5
    /// A silence at least this long starts a new line, seconds.
    var pauseGap: Double = 0.6
    /// Extra time a line stays after its last word (never past the next line), seconds.
    var linger: Double = 0.3
}

struct CaptionLine: Codable, Equatable, Identifiable {
    var id = UUID()
    var words: [CaptionWord]

    var text: String { words.map { CaptionTrack.clean($0.text) }.filter { !$0.isEmpty }.joined(separator: " ") }
    var start: Double { words.first?.start ?? 0 }
    var end: Double { words.map(\.end).max() ?? start }
}

/// Caption look presets (the user can restyle the layers in Text Studio afterwards; Apply keeps that styling).
enum CaptionStyle: String, CaseIterable, Identifiable {
    case clean, bold, manga, lyric
    var id: String { rawValue }
    var title: String {
        switch self {
        case .clean: return "Clean"
        case .bold: return "Bold"
        case .manga: return "Manga"
        case .lyric: return "Lyric"
        }
    }
    var fontName: String {
        switch self {
        case .clean: return "Helvetica-Bold"
        case .bold: return "AvenirNext-Heavy"
        case .manga: return "ChalkboardSE-Bold"
        case .lyric: return "Futura-MediumItalic"
        }
    }
    /// Font size as a fraction of the comp's shorter side.
    var sizeFactor: Double {
        switch self {
        case .clean: return 0.065
        case .bold: return 0.075
        case .manga: return 0.08
        case .lyric: return 0.07
        }
    }
    var outline: Double? { nil }
}

struct CaptionTrack: Codable, Equatable, Identifiable {
    var id = UUID()
    /// The video / audio layer the words were heard in.
    var sourceLayerID: UUID? = nil
    /// Recognition language (BCP-47 identifier).
    var localeID: String = Locale.current.identifier
    var lines: [CaptionLine] = []
    var grouping = CaptionGrouping()
    /// `CaptionStyle` raw value (or a preset Look id from the Text Studio library).
    var styleID: String = CaptionStyle.clean.rawValue
    var highlight: CaptionHighlight = .fill
    var highlightColor = RGBA(hex: 0xFFD23F)
    var textColor = RGBA.white
    /// Vertical position of the lines, fraction of the comp height.
    var positionY: Double = 0.82
    /// Text layers this track created last time (replaced on the next Apply).
    var layerIDs: [UUID] = []

    var words: [CaptionWord] { lines.flatMap(\.words) }

    static func clean(_ s: String) -> String {
        s.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    // MARK: Grouping

    /// Splits time-ordered words into lines by characters, duration and pauses.
    static func group(_ input: [CaptionWord], rules: CaptionGrouping) -> [CaptionLine] {
        let words = input.filter { !clean($0.text).isEmpty }.sorted { $0.start < $1.start }
        var lines: [CaptionLine] = []
        var cur: [CaptionWord] = []
        var chars = 0
        for w in words {
            let len = clean(w.text).count
            if let first = cur.first, let last = cur.last {
                let tooLong = chars + 1 + len > max(1, rules.maxCharacters)
                let tooSlow = w.end - first.start > max(0.1, rules.maxDuration)
                let pause = w.start - last.end >= max(0, rules.pauseGap)
                if tooLong || tooSlow || pause {
                    lines.append(CaptionLine(words: cur))
                    cur = []
                    chars = 0
                }
            }
            cur.append(w)
            chars += (cur.count > 1 ? 1 : 0) + len
        }
        if !cur.isEmpty { lines.append(CaptionLine(words: cur)) }
        return lines
    }

    mutating func setWords(_ words: [CaptionWord]) { lines = Self.group(words, rules: grouping) }
    mutating func regroup() { lines = Self.group(words, rules: grouping) }

    /// Splits a line so `wordIndex` starts a new line.
    mutating func split(lineID: UUID, at wordIndex: Int) {
        guard let i = lines.firstIndex(where: { $0.id == lineID }) else { return }
        let ws = lines[i].words
        guard wordIndex > 0, wordIndex < ws.count else { return }
        lines[i].words = Array(ws[..<wordIndex])
        lines.insert(CaptionLine(words: Array(ws[wordIndex...])), at: i + 1)
    }

    /// Joins a line with the one after it.
    mutating func mergeWithNext(lineID: UUID) {
        guard let i = lines.firstIndex(where: { $0.id == lineID }), i + 1 < lines.count else { return }
        lines[i].words += lines[i + 1].words
        lines.remove(at: i + 1)
    }

    /// Keeps a word's times valid after an edit (end ≥ start + 1 frame-ish).
    mutating func setTimes(wordID: UUID, start: Double? = nil, end: Double? = nil) {
        for li in lines.indices {
            guard let wi = lines[li].words.firstIndex(where: { $0.id == wordID }) else { continue }
            var w = lines[li].words[wi]
            if let s = start { w.start = max(0, s) }
            if let e = end { w.end = e }
            w.end = max(w.end, w.start + 0.02)
            lines[li].words[wi] = w
            return
        }
    }

    // MARK: Timing

    /// In / out of each line's layer: first word start → last word end + linger, cut at the next line's start.
    func lineTimes() -> [(inPoint: Double, outPoint: Double)] {
        let ls = lines.filter { !$0.words.isEmpty }
        return ls.enumerated().map { (i, l) -> (inPoint: Double, outPoint: Double) in
            var out = l.end + max(0, grouping.linger)
            if i + 1 < ls.count { out = min(out, max(l.end, ls[i + 1].start)) }
            return (l.start, max(out, l.start + 0.05))
        }
    }

    // MARK: Word → engine units

    /// For each caption word in `line`: the engine word-unit range and character range it covers in `line.text`
    /// (same counting as TextEngine: whitespace separates words).
    static func unitRanges(_ line: CaptionLine) -> (words: [Range<Int>], chars: [Range<Int>], wordCount: Int, charCount: Int) {
        var wr: [Range<Int>] = [], cr: [Range<Int>] = []
        var wordUnit = 0, charPos = 0
        var first = true
        for w in line.words {
            let t = clean(w.text)
            guard !t.isEmpty else { continue }
            if !first { charPos += 1 }   // the joining space
            first = false
            let pieces = t.split(separator: " ").count
            wr.append(wordUnit..<(wordUnit + pieces))
            let n = Array(t).count
            cr.append(charPos..<(charPos + n))
            wordUnit += pieces
            charPos += n
        }
        return (wr, cr, max(1, wordUnit), max(1, charPos))
    }

    // MARK: Animators

    private static func hold(_ pairs: [(Double, Double)], interp: [Interpolation]) -> Animated<Double> {
        var a = Animated(0.0)
        var lastT = -Double.infinity
        for (i, p) in pairs.enumerated() {
            let t = max(p.0, lastT + 0.002)
            a.insertKeyframe(Keyframe(time: t, value: p.1, interpolation: interp[min(i, interp.count - 1)]))
            lastT = t
        }
        return a
    }

    /// Amount that is 100 while the word is active and 0 outside it, with a tiny fade at both ends.
    static func wordAmount(start: Double, end: Double, ramp: Double = 0.04) -> Animated<Double> {
        let e = max(end, start + 0.02)
        let r = max(0.004, min(ramp, (e - start) / 4))
        return hold([(start - r, 0), (start, 100), (e, 100), (e + r, 0)], interp: [.linear, .hold, .linear, .hold])
    }

    /// The per-word highlight animators for one line (main layer). Underlay layers use `underlayAnimators`.
    func highlightAnimators(for line: CaptionLine, fontSize: Double) -> [TextAnimator] {
        let u = Self.unitRanges(line)
        let ws = line.words.filter { !Self.clean($0.text).isEmpty }
        switch highlight {
        case .none: return []
        case .karaokeWipe:
            var a = TextAnimator(name: "Caption Wipe")
            a.selector.basedOn = .characters
            a.selector.shape = .square
            a.selector.start = Animated(0)
            var pairs: [(Double, Double)] = [(line.start - 1, 0)]
            var interp: [Interpolation] = [.hold]
            let n = Double(u.charCount)
            for (i, w) in ws.enumerated() {
                pairs.append((w.start, Double(u.chars[i].lowerBound) / n * 100)); interp.append(.linear)
                pairs.append((max(w.end, w.start + 0.02), Double(u.chars[i].upperBound) / n * 100)); interp.append(.hold)
            }
            a.selector.end = Self.hold(pairs, interp: interp)
            a.properties.fill = Animated(highlightColor)
            return [a]
        case .fill, .scale, .glow, .box:
            return ws.enumerated().map { (i, w) -> TextAnimator in
                var a = TextAnimator(name: "Word \(i + 1)")
                a.selector.basedOn = .words
                a.selector.shape = .square
                a.selector.start = Animated(Double(u.words[i].lowerBound) / Double(u.wordCount) * 100)
                a.selector.end = Animated(Double(u.words[i].upperBound) / Double(u.wordCount) * 100)
                a.selector.amount = Self.wordAmount(start: w.start, end: w.end)
                switch highlight {
                case .fill, .glow: a.properties.fill = Animated(highlightColor)
                case .scale:
                    a.properties.fill = Animated(highlightColor)
                    a.properties.scale = Animated(Vec2(118, 118))
                    a.properties.position = Animated(Vec2(0, -fontSize * 0.06))
                default: break // box: the word sits on the colored blob, keeps the text color
                }
                return a
            }
        }
    }

    /// Animators for the hidden-by-default underlay (glow halo / box blob): only the active word shows.
    func underlayAnimators(for line: CaptionLine, fontSize: Double) -> [TextAnimator] {
        guard highlight.usesUnderlay else { return [] }
        let u = Self.unitRanges(line)
        let ws = line.words.filter { !Self.clean($0.text).isEmpty }
        return ws.enumerated().map { (i, w) -> TextAnimator in
            var a = TextAnimator(name: "Word \(i + 1) \(highlight == .glow ? "Glow" : "Box")")
            a.selector.basedOn = .words
            a.selector.shape = .square
            a.selector.start = Animated(Double(u.words[i].lowerBound) / Double(u.wordCount) * 100)
            a.selector.end = Animated(Double(u.words[i].upperBound) / Double(u.wordCount) * 100)
            a.selector.amount = Self.wordAmount(start: w.start, end: w.end)
            a.properties.fill = Animated(highlightColor)
            if highlight == .glow {
                a.properties.blur = Animated(max(6, fontSize * 0.16))
            } else {
                a.properties.outline = Animated(max(4, fontSize * 0.24))
            }
            return a
        }
    }

    // MARK: Layers

    /// Builds the caption layers (top first): for each line its text layer, then its underlay when the mode needs one.
    /// `previous` are the layers this track made last time: their look (font, fill, effects, transform) is kept.
    func makeLayers(in project: Project, previous: [Layer] = []) -> [Layer] {
        let style = CaptionStyle(rawValue: styleID) ?? .clean
        let fontSize = Double(min(project.width, project.height)) * style.sizeFactor
        let template = previous.first(where: { $0.text != nil && !$0.name.hasSuffix(" Underlay") })
        let ls = lines.filter { !$0.words.isEmpty }
        let times = lineTimes()
        var p = project
        var result: [Layer] = []
        for (i, line) in ls.enumerated() {
            var l = p.makeLayer(name: "Caption \(i + 1)", content: .text, size: Vec2(10, 10))
            l.inPoint = times[i].inPoint
            l.outPoint = times[i].outPoint
            l.transform.position = Animated(Vec2(Double(project.width) / 2, Double(project.height) * positionY))
            var t = TextData(string: line.text, fontName: style.fontName, fontSize: fontSize)
            t.fill = Animated(textColor)
            t.outline = style.outline
            if let tmp = template, let tt = tmp.text {
                t.fontName = tt.fontName
                t.fontSize = tt.fontSize
                t.tracking = tt.tracking
                t.alignment = tt.alignment
                t.outline = tt.outline
                l.effects = tmp.effects.map { var e = $0; e.id = UUID(); return e }
                l.transform.position = tmp.transform.position.isAnimated ? Animated(tmp.transform.position.value(at: tmp.inPoint)) : tmp.transform.position
                l.transform.scale = tmp.transform.scale.isAnimated ? Animated(tmp.transform.scale.value(at: tmp.inPoint)) : tmp.transform.scale
                l.blendMode = tmp.blendMode
                l.stroke = tmp.stroke
            }
            t.animators = highlightAnimators(for: line, fontSize: t.fontSize)
            l.text = t
            result.append(l)
            if highlight.usesUnderlay {
                var under = l
                under.id = UUID()
                under.name = "Caption \(i + 1) Underlay"
                under.effects = []
                var ut = t
                ut.fill = Animated(RGBA(highlightColor.r, highlightColor.g, highlightColor.b, 0))
                ut.colorSpans = []
                ut.animators = underlayAnimators(for: line, fontSize: t.fontSize)
                under.text = ut
                result.append(under)
            }
            p.layers.append(l)
        }
        return result
    }

    /// Converts words heard at source-media seconds into comp seconds for `layer` (trim + speed).
    static func compWords(_ words: [CaptionWord], for layer: Layer) -> [CaptionWord] {
        let speed = max(0.01, abs(layer.speed))
        return words.compactMap { w in
            let s = layer.inPoint + (w.start - layer.sourceStart) / speed
            let e = layer.inPoint + (w.end - layer.sourceStart) / speed
            guard e > layer.inPoint, s < layer.outPoint else { return nil }
            return CaptionWord(id: w.id, text: w.text, start: max(layer.inPoint, s), end: min(layer.outPoint, e))
        }
    }
}

extension Project {
    /// Replaces the layers `track` made before with freshly built ones (call inside one `mutate` = one undo step).
    /// The new layers go where the old ones were, else just above the source layer, else on top.
    mutating func applyCaptions(_ track: CaptionTrack) {
        var track = track
        let old = layers.filter { track.layerIDs.contains($0.id) }
        var insertAt = layers.firstIndex { track.layerIDs.contains($0.id) }
            ?? track.sourceLayerID.flatMap { sid in layers.firstIndex { $0.id == sid } } ?? 0
        let removedAbove = layers.prefix(insertAt).filter { track.layerIDs.contains($0.id) }.count
        layers.removeAll { track.layerIDs.contains($0.id) }
        insertAt = min(max(0, insertAt - removedAbove), layers.count)
        let made = track.makeLayers(in: self, previous: old)
        layers.insert(contentsOf: made, at: insertAt)
        track.layerIDs = made.map(\.id)
        var all = captionTracks ?? []
        if let i = all.firstIndex(where: { $0.id == track.id }) { all[i] = track } else { all.append(track) }
        captionTracks = all
        fitAutoLength()
    }

    func captionTrack(forSource id: UUID) -> CaptionTrack? {
        captionTracks?.last(where: { $0.sourceLayerID == id })
    }
}
