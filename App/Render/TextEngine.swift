import Foundation
import CoreText
import CoreGraphics
import Metal
import simd
import UIKit

/// One laid-out glyph in layer-local pixels (y down, block centered on the origin).
struct LaidGlyph {
    var glyph: CGGlyph
    var font: CTFont
    /// Glyph bounding box center (local px).
    var center: Vec2
    /// Half size of the glyph bounding box (local px), before padding.
    var halfSize: Vec2
    /// Baseline origin (local px).
    var origin: Vec2
    var charIndex: Int
    var charExSpaceIndex: Int
    var wordIndex: Int
    var lineIndex: Int
    var isSpace: Bool
    /// Stable id of the character (TextData.charIDs).
    var charID: UInt32 = 0
    /// Built-in rotation in radians (Latin letters in vertical text).
    var baseRotation: Double = 0
    /// The run font draws this glyph in color (emoji).
    var isColor: Bool = false
}

struct TextLayout {
    var glyphs: [LaidGlyph]
    var bounds: CGRect
    var charCount: Int
    var charExSpaceCount: Int
    var wordCount: Int
    var lineCount: Int
    var lineWidths: [Double]
}

/// Small least-recently-used cache (not thread safe; TextEngine guards it with its lock).
final class TextLRU<Value> {
    private var items: [String: (value: Value, stamp: UInt64, cost: Int)] = [:]
    private var clock: UInt64 = 0
    private(set) var totalCost = 0
    let maxCount: Int
    let maxCost: Int

    init(maxCount: Int, maxCost: Int = Int.max) {
        self.maxCount = max(1, maxCount)
        self.maxCost = max(1, maxCost)
    }

    var count: Int { items.count }

    func get(_ key: String) -> Value? {
        guard var e = items[key] else { return nil }
        clock &+= 1
        e.stamp = clock
        items[key] = e
        return e.value
    }

    func set(_ key: String, _ value: Value, cost: Int = 1) {
        if let old = items[key] { totalCost -= old.cost }
        clock &+= 1
        items[key] = (value, clock, cost)
        totalCost += cost
        if items.count > maxCount || totalCost > maxCost { evict() }
    }

    func removeAll() { items.removeAll(); totalCost = 0 }

    /// Drops the oldest entries until the cache is back to 3/4 of its limits.
    private func evict() {
        let countTarget = maxCount / 4 * 3, costTarget = maxCost / 4 * 3
        let oldest = items.sorted { $0.value.stamp < $1.value.stamp }
        var i = 0
        while i < oldest.count, items.count > countTarget || totalCost > costTarget {
            if let e = items.removeValue(forKey: oldest[i].key) { totalCost -= e.cost }
            i += 1
        }
    }
}

/// What a glyph raster contains.
enum GlyphMaskOp: Hashable {
    /// The filled letter.
    case fill
    /// Hollow letter: outline stroke of this width (legacy outline).
    case outline(Double)
    /// Stroke layer: width, position (0 outside, 1 center, 2 inside), join (0 round, 1 miter, 2 bevel).
    case stroke(Double, Int, Int)
    /// Letter plus a stroke reach (shadow / glow source).
    case shape(Double)
    /// Inner shadow at this offset (glyph px, y down).
    case inner(Double, Double)
}

struct GlyphRaster {
    let tex: MTLTexture
    /// Raster padding in device px.
    let pad: Double
    /// Device px per glyph px.
    let scale: Double
    /// RGBA (color emoji) instead of an r8 mask.
    let isColor: Bool
}

/// Must match GlyphParamsTxt1 in Shaders.metal.
struct GlyphParamsTxt1 {
    var invRow0 = SIMD4<Float>(repeating: 0)
    var invRow1 = SIMD4<Float>(repeating: 0)
    var invRow2 = SIMD4<Float>(repeating: 0)
    var geom = SIMD4<Float>(repeating: 0)
    var gradA = SIMD4<Float>(repeating: 0)
    var gradB = SIMD4<Float>(repeating: 0)
    var stops = SIMD4<Float>(0, 1, 1, 1)
    var c0 = SIMD4<Float>(1, 1, 1, 1)
    var c1 = SIMD4<Float>(1, 1, 1, 1)
    var c2 = SIMD4<Float>(1, 1, 1, 1)
    var c3 = SIMD4<Float>(1, 1, 1, 1)
    var tint = SIMD4<Float>(repeating: 0)
    var extra = SIMD4<Float>(0, 1, 0, 0)
    var modes = SIMD4<UInt32>(repeating: 0)
    var region = SIMD4<UInt32>(repeating: 0)
}

/// One glyph pass ready to encode.
struct GlyphDrawTxt1 {
    var params: GlyphParamsTxt1
    let tex: MTLTexture
}

/// Lays out text with Core Text and renders glyphs as masks (fills, strokes, shadows, glow) through one encoder.
final class TextEngine {
    static let shared = TextEngine()

    private let layoutCache = TextLRU<TextLayout>(maxCount: 160)
    private let glyphCache = TextLRU<GlyphRaster>(maxCount: 4000, maxCost: 64 * 1024 * 1024)
    private let lock = NSLock()

    static func availableFonts() -> [String] {
        UIFont.familyNames.sorted().flatMap { UIFont.fontNames(forFamilyName: $0).sorted() }
    }

    // MARK: Layout

    func layout(_ t: TextData, time: Double) -> TextLayout {
        let tracking = t.tracking.value(at: time)
        let spacing = t.lineSpacing.value(at: time)
        var key = "\(t.string)|\(t.fontName)|\(t.fontSize)|\(tracking)|\(spacing)|\(t.alignment.rawValue)|\(t.spacingAnchor ?? -1)"
        key += "|\(t.boxWidth ?? -1)|\(t.autoFit == true)|\(t.vertical == true)"
        let ids = t.resolvedCharIDs
        if let cs = t.charStyles, !cs.isEmpty {
            // Only the layout-relevant overrides, in character order (dictionary order is not stable).
            for (i, id) in ids.enumerated() {
                guard let s = cs[id], s.fontName != nil || s.sizePercent != nil || s.baselineShift != nil else { continue }
                key += "|\(i):\(s.fontName ?? ""):\(s.sizePercent ?? 100):\(s.baselineShift ?? 0)"
            }
        }
        lock.lock()
        var cached = layoutCache.get(key)
        lock.unlock()
        if cached == nil {
            let l = Self.computeLayout(t, tracking: tracking, spacing: spacing)
            lock.lock()
            layoutCache.set(key, l)
            lock.unlock()
            cached = l
        }
        // Ids are stamped after the cache so an edit that keeps the string still gets the current ids.
        var l = cached!
        for i in l.glyphs.indices {
            let ci = l.glyphs[i].charIndex
            l.glyphs[i].charID = ci >= 0 && ci < ids.count ? ids[ci] : 0
        }
        return l
    }

    private static func computeLayout(_ t: TextData, tracking: Double, spacing: Double) -> TextLayout {
        if t.autoFit == true, let box = t.boxWidth, box > 1 {
            var fit = 1.0
            var l = buildLayout(t, tracking: tracking, spacing: spacing, sizeScale: 1, wrap: false)
            for _ in 0..<4 {
                let w = l.lineWidths.max() ?? 0
                guard w.isFinite, w > box * 1.002 else { break }
                fit = max(0.01, fit * box / w)
                l = buildLayout(t, tracking: tracking, spacing: spacing, sizeScale: fit, wrap: false)
            }
            return l
        }
        return buildLayout(t, tracking: tracking, spacing: spacing, sizeScale: 1, wrap: t.boxWidth != nil)
    }

    static func isUprightInVertical(_ c: Character) -> Bool {
        guard let s = c.unicodeScalars.first else { return true }
        if s.properties.isEmojiPresentation { return true }
        return s.value >= 0x2E80
    }

    private static func buildLayout(_ t: TextData, tracking: Double, spacing: Double, sizeScale: Double, wrap: Bool) -> TextLayout {
        let size = max(1, t.fontSize) * sizeScale
        let font = CTFontCreateWithName(t.fontName as CFString, CGFloat(size), nil)
        let chars = Array(t.string)
        let ids = t.resolvedCharIDs
        let styles = t.charStyles ?? [:]
        func styleAt(_ ci: Int) -> TextCharStyle? { ci >= 0 && ci < ids.count ? styles[ids[ci]] : nil }
        func fontFor(_ s: TextCharStyle?) -> CTFont? {
            guard let s, s.fontName != nil || s.sizePercent != nil else { return nil }
            let pct = max(1, min(1000, s.sizePercent ?? 100)) / 100
            return CTFontCreateWithName((s.fontName ?? t.fontName) as CFString, CGFloat(size * pct), nil)
        }
        // UTF16 offset -> Character index.
        var utf16ToChar: [Int] = []
        for (ci, ch) in chars.enumerated() { for _ in 0..<String(ch).utf16.count { utf16ToChar.append(ci) } }
        // Per-character unit indices.
        var exIdx = [Int](repeating: 0, count: chars.count), wordIdx = [Int](repeating: 0, count: chars.count)
        var ex = 0, word = -1, inWord = false
        for (i, ch) in chars.enumerated() {
            let space = ch.isWhitespace
            exIdx[i] = space ? max(0, ex - 1) : ex
            if !space { ex += 1 }
            if !space && !inWord { word += 1 }
            inWord = !space
            wordIdx[i] = max(0, word)
        }
        let ascent = Double(CTFontGetAscent(font)), descent = Double(CTFontGetDescent(font))
        let lineHeight = (ascent + descent) * spacing

        if t.vertical == true {
            return verticalLayout(t, chars: chars, styleAt: styleAt, fontFor: fontFor, font: font, size: size,
                                  tracking: tracking, spacing: spacing, sizeScale: sizeScale, exIdx: exIdx, wordIdx: wordIdx,
                                  exCount: ex, wordCount: word + 1)
        }

        let paragraphs = t.string.components(separatedBy: "\n")
        let hasBox = t.boxWidth != nil
        let box = max(1, t.boxWidth ?? 1)
        var glyphs: [LaidGlyph] = []
        var lineWidths: [Double] = []
        var lineX0: [Double] = []
        var utf16Base = 0
        var lineIndex = 0
        let al: Double
        switch t.alignment {
        case .left: al = 0
        case .center: al = 0.5
        case .right: al = 1
        }
        for para in paragraphs {
            let attr = NSMutableAttributedString(string: para, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTKernAttributeName as String): NSNumber(value: tracking),
            ])
            // Per-character font / size overrides.
            if !styles.isEmpty {
                var u = 0
                for ch in para {
                    let n = String(ch).utf16.count
                    let base = utf16Base + u
                    let ci = base < utf16ToChar.count ? utf16ToChar[base] : -1
                    if let f = fontFor(styleAt(ci)) {
                        attr.addAttribute(NSAttributedString.Key(kCTFontAttributeName as String), value: f, range: NSRange(location: u, length: n))
                    }
                    u += n
                }
            }
            var lines: [CTLine] = []
            if wrap, hasBox, attr.length > 0 {
                let ts = CTTypesetterCreateWithAttributedString(attr)
                var start = 0
                while start < attr.length {
                    var n = CTTypesetterSuggestLineBreak(ts, start, box)
                    if n <= 0 { n = 1 }
                    lines.append(CTTypesetterCreateLine(ts, CFRange(location: start, length: n)))
                    start += n
                }
            } else {
                lines.append(CTLineCreateWithAttributedString(attr))
            }
            for line in lines {
                var width = Double(CTLineGetTypographicBounds(line, nil, nil, nil))
                if wrap && hasBox { width -= Double(CTLineGetTrailingWhitespaceWidth(line)) }
                width = max(0, width)
                lineWidths.append(width)
                var x0: Double
                if hasBox {
                    x0 = -box / 2 + (box - width) * al
                } else {
                    x0 = -width * al
                    // Spacing anchor: extra space from tracking grows away from the chosen side.
                    if let anchor = t.spacingAnchor, tracking != 0 {
                        let plain = CTLineCreateWithAttributedString(NSAttributedString(string: para, attributes: [
                            NSAttributedString.Key(kCTFontAttributeName as String): font]))
                        let w0 = Double(CTLineGetTypographicBounds(plain, nil, nil, nil))
                        x0 = -w0 * al - (width - w0) * Double(anchor) / 2
                    }
                }
                lineX0.append(x0)
                let baseline = Double(lineIndex) * lineHeight
                for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
                    let n = CTRunGetGlyphCount(run)
                    guard n > 0 else { continue }
                    var gl = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n), idx = [CFIndex](repeating: 0, count: n)
                    CTRunGetGlyphs(run, CFRange(location: 0, length: n), &gl)
                    CTRunGetPositions(run, CFRange(location: 0, length: n), &pos)
                    CTRunGetStringIndices(run, CFRange(location: 0, length: n), &idx)
                    let attrs = CTRunGetAttributes(run) as NSDictionary
                    let runFont = (attrs[kCTFontAttributeName] as! CTFont?) ?? font
                    let color = CTFontGetSymbolicTraits(runFont).contains(.traitColorGlyphs)
                    var rects = [CGRect](repeating: .zero, count: n)
                    CTFontGetBoundingRectsForGlyphs(runFont, .horizontal, gl, &rects, n)
                    for k in 0..<n {
                        let u = utf16Base + idx[k]
                        let ci = u < utf16ToChar.count ? utf16ToChar[u] : max(0, chars.count - 1)
                        let r = rects[k]
                        let shift = (styleAt(ci)?.baselineShift ?? 0) * sizeScale
                        let ox = x0 + Double(pos[k].x), oy = baseline - shift
                        let cx = ox + Double(r.midX), cy = oy - Double(r.midY)
                        let space = ci < chars.count ? chars[ci].isWhitespace : true
                        glyphs.append(LaidGlyph(glyph: gl[k], font: runFont, center: Vec2(cx, cy),
                                                halfSize: Vec2(Double(r.width) / 2, Double(r.height) / 2),
                                                origin: Vec2(ox, oy), charIndex: ci,
                                                charExSpaceIndex: ci < exIdx.count ? exIdx[ci] : 0,
                                                wordIndex: ci < wordIdx.count ? wordIdx[ci] : 0, lineIndex: lineIndex, isSpace: space,
                                                isColor: color))
                    }
                }
                lineIndex += 1
            }
            utf16Base += para.utf16.count + 1
        }
        let lineCount = max(1, lineIndex)
        // Center the block vertically around the origin (AE-like default anchor for our text layers).
        let totalH = Double(max(0, lineCount - 1)) * lineHeight
        let top = -ascent, bottom = totalH + descent
        // Visual center: halfway between the first line's cap height and the last baseline, so the letters sit
        // on the pivot (the ascent/descent box put them noticeably above it).
        let capHeight = Double(CTFontGetCapHeight(font))
        let shiftY = -(-capHeight + totalH) / 2
        for i in glyphs.indices {
            glyphs[i].center.y += shiftY
            glyphs[i].origin.y += shiftY
        }
        let maxW = lineWidths.max() ?? 0
        let bounds: CGRect
        if hasBox {
            let lo = min(-box / 2, zip(lineX0, lineWidths).map { $0.0 }.min() ?? 0)
            let hi = max(box / 2, zip(lineX0, lineWidths).map { $0.0 + $0.1 }.max() ?? 0)
            bounds = CGRect(x: lo, y: top + shiftY, width: max(1, hi - lo), height: max(1, bottom - top))
        } else {
            let bx: Double = t.alignment == .left ? 0 : (t.alignment == .center ? -maxW / 2 : -maxW)
            bounds = CGRect(x: bx, y: top + shiftY, width: max(1, maxW), height: max(1, bottom - top))
        }
        return TextLayout(glyphs: glyphs, bounds: bounds, charCount: chars.count, charExSpaceCount: max(1, ex),
                          wordCount: max(1, word + 1), lineCount: lineCount, lineWidths: lineWidths)
    }

    /// Vertical text: columns top→bottom, the first column on the right. CJK / emoji stand upright, Latin turns 90°.
    private static func verticalLayout(_ t: TextData, chars: [Character], styleAt: (Int) -> TextCharStyle?,
                                       fontFor: (TextCharStyle?) -> CTFont?, font: CTFont, size: Double,
                                       tracking: Double, spacing: Double, sizeScale: Double,
                                       exIdx: [Int], wordIdx: [Int], exCount: Int, wordCount: Int) -> TextLayout {
        let ascent = Double(CTFontGetAscent(font)), descent = Double(CTFontGetDescent(font))
        let colW = (ascent + descent) * spacing
        var glyphs: [LaidGlyph] = []
        var colHeights: [Double] = []
        var col = 0
        var y = 0.0
        for (ci, ch) in chars.enumerated() {
            if ch == "\n" || ch == "\r\n" { colHeights.append(y); col += 1; y = 0; continue }
            let cs = styleAt(ci)
            let f = fontFor(cs) ?? font
            let fSize = Double(CTFontGetSize(f))
            let fa = Double(CTFontGetAscent(f)), fd = Double(CTFontGetDescent(f))
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: String(ch), attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): f]))
            let adv = Double(CTLineGetTypographicBounds(line, nil, nil, nil))
            let upright = isUprightInVertical(ch)
            let space = ch.isWhitespace
            let step = (upright ? fSize : adv) + tracking
            let colX = -Double(col) * colW
            let shift = (cs?.baselineShift ?? 0) * sizeScale
            for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
                let n = CTRunGetGlyphCount(run)
                guard n > 0 else { continue }
                var gl = [CGGlyph](repeating: 0, count: n), pos = [CGPoint](repeating: .zero, count: n)
                CTRunGetGlyphs(run, CFRange(location: 0, length: n), &gl)
                CTRunGetPositions(run, CFRange(location: 0, length: n), &pos)
                let attrs = CTRunGetAttributes(run) as NSDictionary
                let runFont = (attrs[kCTFontAttributeName] as! CTFont?) ?? f
                let color = CTFontGetSymbolicTraits(runFont).contains(.traitColorGlyphs)
                var rects = [CGRect](repeating: .zero, count: n)
                CTFontGetBoundingRectsForGlyphs(runFont, .horizontal, gl, &rects, n)
                for k in 0..<n {
                    let r = rects[k]
                    var lg = LaidGlyph(glyph: gl[k], font: runFont, center: .zero,
                                       halfSize: Vec2(Double(r.width) / 2, Double(r.height) / 2), origin: .zero,
                                       charIndex: ci, charExSpaceIndex: ci < exIdx.count ? exIdx[ci] : 0,
                                       wordIndex: ci < wordIdx.count ? wordIdx[ci] : 0, lineIndex: col, isSpace: space,
                                       isColor: color)
                    if upright {
                        // Em box centered in the cell.
                        let baseY = y + step / 2 + (fa - fd) / 2
                        lg.origin = Vec2(colX - adv / 2 + Double(pos[k].x) + shift, baseY)
                        lg.center = Vec2(lg.origin.x + Double(r.midX), baseY - Double(r.midY))
                    } else {
                        // Turned 90° clockwise: the baseline runs down the column, letter tops face right.
                        let baseX = colX - (fa - fd) / 2 + shift
                        lg.origin = Vec2(baseX, y + Double(pos[k].x))
                        lg.center = Vec2(baseX + Double(r.midY), y + Double(pos[k].x) + Double(r.midX))
                        lg.baseRotation = .pi / 2
                    }
                    glyphs.append(lg)
                }
            }
            y += step
        }
        colHeights.append(y)
        let cols = max(1, colHeights.count)
        let maxH = colHeights.max() ?? 0
        let al: Double = t.alignment == .left ? 0 : (t.alignment == .center ? 0.5 : 1)
        let shiftX = Double(cols - 1) * colW / 2
        for i in glyphs.indices {
            let h = glyphs[i].lineIndex < colHeights.count ? colHeights[glyphs[i].lineIndex] : maxH
            let dy = -maxH / 2 + (maxH - h) * al
            glyphs[i].center = glyphs[i].center + Vec2(shiftX, dy)
            glyphs[i].origin = glyphs[i].origin + Vec2(shiftX, dy)
        }
        let bounds = CGRect(x: -shiftX - colW / 2, y: -maxH / 2, width: max(1, Double(cols) * colW), height: max(1, maxH))
        return TextLayout(glyphs: glyphs, bounds: bounds, charCount: chars.count, charExSpaceCount: max(1, exCount),
                          wordCount: max(1, wordCount), lineCount: cols, lineWidths: colHeights)
    }

    // MARK: Animation

    /// Combined selection (all selectors) of animator `a` for glyph `g`.
    static func selection(_ a: TextAnimator, glyph g: LaidGlyph, layout: TextLayout, time: Double, beats: [Double]) -> Double {
        SelectorMath.combinedAmount(a, units: { s in
            switch s.basedOn {
            case .characters: return (g.charIndex, layout.charCount)
            case .charactersExcludingSpaces: return (g.charExSpaceIndex, layout.charExSpaceCount)
            case .words: return (g.wordIndex, layout.wordCount)
            case .lines: return (g.lineIndex, layout.lineCount)
            }
        }, charID: g.charID, time: time, beats: beats)
    }

    /// Per-glyph animated state after applying all animators.
    static func glyphStates(_ text: TextData, layout: TextLayout, time: Double, beats: [Double] = []) -> [Renderer.GlyphState] {
        let ids = text.resolvedCharIDs
        let fill = text.fill.value(at: time)
        let lift = text.baselineShift?.value(at: time) ?? 0
        var states = layout.glyphs.map { g -> Renderer.GlyphState in
            var s = Renderer.GlyphState()
            if let o = text.baseColorOverride(forCharacter: g.charIndex, ids: ids) { s.color = o; s.tintMix = 1 } else { s.color = fill }
            s.outline = text.outline ?? 0
            if lift.isFinite { s.offset.y -= lift }
            return s
        }
        let lineMid = Double(max(0, layout.lineCount - 1)) / 2
        for a in text.animators where a.isEnabled {
            let p = a.properties
            let pos = p.position?.value(at: time), sc = p.scale?.value(at: time), rot = p.rotation?.value(at: time)
            let op = p.opacity?.value(at: time), col = p.fill?.value(at: time), tr = p.tracking?.value(at: time)
            let sk = p.skew?.value(at: time)
            let bl = p.blur?.value(at: time), co = p.characterOffset?.value(at: time)
            let rx = p.rotationX?.value(at: time), ry = p.rotationY?.value(at: time), pz = p.positionZ?.value(at: time)
            let ol = p.outline?.value(at: time)
            let anc = p.anchor?.value(at: time), fop = p.fillOpacity?.value(at: time)
            let sw = p.strokeWidth?.value(at: time), scol = p.strokeColor?.value(at: time)
            let bs = p.baselineShift?.value(at: time), glw = p.glow?.value(at: time), hue = p.hueShift?.value(at: time)
            let db = p.directionalBlur?.value(at: time), dba = p.directionalBlurAngle?.value(at: time)
            let scr = p.scramble?.value(at: time), ls = p.lineSpacing?.value(at: time)
            for (gi, g) in layout.glyphs.enumerated() {
                let amt = selection(a, glyph: g, layout: layout, time: time, beats: beats)
                if amt == 0 || !amt.isFinite { continue }
                let c01 = min(1, max(0, amt))
                if let pos { states[gi].offset = states[gi].offset + pos * amt }
                if let sc { states[gi].scale = Vec2(states[gi].scale.x * (1 + (sc.x / 100 - 1) * amt), states[gi].scale.y * (1 + (sc.y / 100 - 1) * amt)) }
                if let rot { states[gi].rotation += rot * amt }
                if let sk { states[gi].skew += sk * amt }
                if let op { states[gi].opacity *= max(0, 1 + (op / 100 - 1) * amt) }
                if let col {
                    states[gi].color = RGBA.lerp(states[gi].color, col, c01)
                    states[gi].tintMix += (1 - states[gi].tintMix) * c01
                }
                if let tr { states[gi].tracking += tr * amt }
                if let bl { states[gi].blur += max(0, bl * amt) }
                if let co { states[gi].charOffset += co * amt }
                if let rx { states[gi].rotX += rx * amt }
                if let ry { states[gi].rotY += ry * amt }
                if let pz { states[gi].z += pz * amt }
                // Outline blends toward the animator's width (0 = back to solid).
                if let ol { states[gi].outline += (ol - states[gi].outline) * c01 }
                if let anc { states[gi].anchor = states[gi].anchor + anc * amt }
                if let fop { states[gi].fillOpacity *= max(0, 1 + (fop / 100 - 1) * amt) }
                if let sw { states[gi].strokeWidth += sw * amt }
                if let scol {
                    states[gi].strokeColor = states[gi].strokeColor.map { RGBA.lerp($0, scol, c01) } ?? scol
                    states[gi].strokeMix = 1 - (1 - states[gi].strokeMix) * (1 - c01)
                }
                if let bs { states[gi].offset.y -= bs * amt }
                if let glw { states[gi].glow += max(0, glw / 100 * amt) }
                if let hue { states[gi].hueShift += hue * amt }
                if let db {
                    states[gi].dirBlur += max(0, db * amt)
                    if let dba { states[gi].dirBlurAngle = dba }
                }
                if let scr { states[gi].scramble = min(1, states[gi].scramble + max(0, scr / 100 * amt)) }
                if let ls { states[gi].offset.y += (Double(g.lineIndex) - lineMid) * ls * amt }
            }
        }
        // Tracking accumulates along each line, then the line is re-centered for the alignment.
        var lineTotals: [Int: Double] = [:]
        var running: [Int: Double] = [:]
        let vertical = text.vertical == true
        for (gi, g) in layout.glyphs.enumerated() {
            let r = running[g.lineIndex, default: 0]
            if vertical { states[gi].offset.y += r } else { states[gi].offset.x += r }
            running[g.lineIndex] = r + states[gi].tracking
            lineTotals[g.lineIndex] = r + states[gi].tracking
        }
        if text.alignment != .left {
            for (gi, g) in layout.glyphs.enumerated() {
                let total = lineTotals[g.lineIndex, default: 0]
                let back = text.alignment == .center ? total / 2 : total
                if vertical { states[gi].offset.y -= back } else { states[gi].offset.x -= back }
            }
        }
        return states
    }

    /// Focal length (px) of the per-letter perspective.
    static let letterFocal = 1000.0

    /// Homography from a glyph quad's local px (centered on the glyph box) to layer-local px, with real per-letter 3D:
    /// letters flip in X / Y around their pivot, move in depth, and are projected through a 1000 px focal length
    /// centered on the layer origin (so a turned letter becomes a trapezoid; its back shows mirrored).
    /// nil when the letter passes behind the eye.
    static func placement(_ g: LaidGlyph, _ st: Renderer.GlyphState, layout: TextLayout, track: PathTrack?,
                          halfSize hs: Vec2? = nil) -> simd_double3x3? {
        var rot = st.rotation * .pi / 180 + g.baseRotation
        let skew = tan(max(-89, min(89, st.skew)) * .pi / 180)
        var c = g.center + st.offset
        // Characters scale/rotate around their baseline center like AE's default anchor.
        var pivot = (g.baseRotation != 0 ? g.center : Vec2(g.center.x, g.origin.y)) + st.offset + st.anchor
        if let track {
            let along = track.offset + (g.center.x - Double(layout.bounds.minX)) + st.offset.x
            let (pt, ang) = track.point(at: along)
            let nrm = Vec2(-sin(ang), cos(ang))
            let lift = g.origin.y - Double(layout.bounds.maxY)
            let base = pt + nrm * (lift + st.offset.y)
            pivot = base
            c = base + nrm * (g.center.y - g.origin.y)
            rot += ang
        }
        let rx = st.rotX * .pi / 180, ry = st.rotY * .pi / 180
        let KS = simd_double3x3(columns: (SIMD3(st.scale.x, 0, 0), SIMD3(-skew * st.scale.y, st.scale.y, 0), SIMD3(0, 0, 1)))
        let Rx = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, cos(rx), sin(rx)), SIMD3(0, -sin(rx), cos(rx))))
        let Ry = simd_double3x3(columns: (SIMD3(cos(ry), 0, -sin(ry)), SIMD3(0, 1, 0), SIMD3(sin(ry), 0, cos(ry))))
        let Rz = simd_double3x3(columns: (SIMD3(cos(rot), sin(rot), 0), SIMD3(-sin(rot), cos(rot), 0), SIMD3(0, 0, 1)))
        let A = Rz * Ry * Rx * KS
        let a0 = A.columns.0, a1 = A.columns.1
        let d = c - pivot
        let b = a0 * d.x + a1 * d.y + SIMD3(pivot.x, pivot.y, st.z)
        let f = letterFocal
        let H = simd_double3x3(columns: (SIMD3(a0.x, a0.y, a0.z / f), SIMD3(a1.x, a1.y, a1.z / f), SIMD3(b.x, b.y, 1 + b.z / f)))
        guard (0..<3).allSatisfy({ i in (0..<3).allSatisfy { H[i][$0].isFinite } }) else { return nil }
        let q = hs ?? g.halfSize
        for cx in [-q.x, q.x] { for cy in [-q.y, q.y] {
            if (H * SIMD3(cx, cy, 1)).z < 0.05 { return nil }
        } }
        return H
    }

    /// Layer-local px a glyph's raster reaches beyond its outline (style stack, blur, glow, letter effects).
    static func glyphMargin(_ text: TextData, _ st: Renderer.GlyphState, time: Double, effectMargin: Double) -> Double {
        var m = 2 + (text.style?.margin(at: time) ?? 0) + max(0, st.blur) * 2.5 + max(0, st.outline) + max(0, st.dirBlur) / 2
        m += max(0, st.strokeWidth)
        if st.glow > 0 { m = max(m, (text.style?.glow?.radius.value(at: time) ?? 12) * 2.5 + 2) }
        if st.charOffset != 0 || st.scramble > 0 { m += text.fontSize * 0.35 }
        m += effectMargin
        return m.isFinite ? min(m, 4000) : 0
    }

    /// Bounds of the animated letters (layer-local px) including every margin, unioned with the layout bounds.
    /// The render buffer and motion-blur checks use this so animated letters never clip.
    static func animatedBounds(_ text: TextData, layout: TextLayout, time: Double, beats: [Double] = [],
                               track: PathTrack? = nil) -> CGRect {
        let states = glyphStates(text, layout: layout, time: time, beats: beats)
        var fxMargin = 0.0
        for a in text.animators where a.isEnabled {
            for e in a.letterEffects ?? [] where e.isEnabled {
                fxMargin += EffectRegistry.definition(e.typeID).map { $0.margin(e, time) } ?? 0
            }
        }
        var minX = Double(layout.bounds.minX), maxX = Double(layout.bounds.maxX)
        var minY = Double(layout.bounds.minY), maxY = Double(layout.bounds.maxY)
        for (gi, g) in layout.glyphs.enumerated() where !g.isSpace {
            let st = states[gi]
            if st.opacity <= 0.0005 { continue }
            let m = glyphMargin(text, st, time: time, effectMargin: fxMargin)
            let hs = Vec2(g.halfSize.x + m, g.halfSize.y + m)
            guard let H = placement(g, st, layout: layout, track: track) else { continue }
            var reach = 0.0
            if let shadows = text.style?.shadows {
                for s in shadows where s.isEnabled && s.kind == .drop {
                    let o = s.offset(at: time)
                    reach = max(reach, abs(o.x), abs(o.y))
                }
            }
            for cx in [-hs.x, hs.x] { for cy in [-hs.y, hs.y] {
                let p = H * SIMD3(cx, cy, 1)
                let z = max(p.z, 0.05)
                let x = p.x / z, y = p.y / z
                guard x.isFinite, y.isFinite else { continue }
                minX = min(minX, x - reach); maxX = max(maxX, x + reach)
                minY = min(minY, y - reach); maxY = max(maxY, y + reach)
            } }
        }
        let lim = 1e6
        minX = max(-lim, minX); minY = max(-lim, minY); maxX = min(lim, maxX); maxY = min(lim, maxY)
        return CGRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
    }

    // MARK: Rasters

    /// Rasterized alpha mask for a glyph at `scale` device px per local px (bucketed for caching).
    func glyphTexture(_ g: LaidGlyph, scale: Double, blur rawBlur: Double = 0, outline rawOutline: Double = 0, device: MTLDevice) -> (tex: MTLTexture, pad: Double, scale: Double)? {
        guard rawOutline.isFinite else { return nil }
        let outline = min(80, (max(0, rawOutline) * 2).rounded() / 2)
        guard let r = raster(g, scale: scale, op: outline > 0 ? .outline(outline) : .fill, blur: rawBlur, allowColor: false, device: device) else { return nil }
        return (r.tex, r.pad, r.scale)
    }

    private static func q(_ v: Double, _ step: Double, _ hi: Double) -> Double { min(hi, (max(0, v) / step).rounded() * step) }

    /// Rasterizes one mask kind of a glyph. Cached in a bounded LRU.
    func raster(_ g: LaidGlyph, scale: Double, op rawOp: GlyphMaskOp, blur rawBlur: Double = 0, dirBlur rawDir: Double = 0,
                dirAngle rawAngle: Double = 0, allowColor: Bool = true, device: MTLDevice) -> GlyphRaster? {
        // Never convert non-finite animation values or oversized raster dimensions to Int.
        guard scale.isFinite, rawBlur.isFinite, rawDir.isFinite, rawAngle.isFinite,
              g.halfSize.x.isFinite, g.halfSize.y.isFinite else { return nil }
        let op: GlyphMaskOp
        let extent: Double
        switch rawOp {
        case .fill: op = .fill; extent = 0
        case .outline(let w): let v = Self.q(w, 0.5, 80); op = .outline(v); extent = v
        case .stroke(let w, let p, let j):
            let v = Self.q(w, 0.5, 400); op = .stroke(v, p, j); extent = p == 2 ? 0 : (p == 1 ? v / 2 : v)
        case .shape(let w): let v = Self.q(w, 0.5, 400); op = .shape(v); extent = v
        case .inner(let dx, let dy):
            guard dx.isFinite, dy.isFinite else { return nil }
            op = .inner((max(-400, min(400, dx)) * 2).rounded() / 2, (max(-400, min(400, dy)) * 2).rounded() / 2); extent = 0
        }
        // Bucket scales to powers of 2^(1/4) so zooming doesn't re-rasterize every frame.
        let b = pow(2, (log2(max(scale, 0.05)) * 4).rounded(.up) / 4)
        // Blur (local px) in half-pixel steps, so animated blur reuses rasters.
        let blur = Self.q(rawBlur, 0.5, 200)
        let dir = Self.q(rawDir, 1, 400)
        let angle = dir > 0 ? (rawAngle / 5).rounded() * 5 : 0
        let colorRaster = allowColor && g.isColor && op == .fill && blur * b <= 0.25 && dir == 0
        let fontName = CTFontCopyPostScriptName(g.font) as String
        let size = Double(CTFontGetSize(g.font))
        let key = "\(ObjectIdentifier(device))|\(fontName)|\(size)|\(g.glyph)|\(b)|\(blur)|\(op)|\(dir)|\(angle)|\(colorRaster)"
        lock.lock()
        if let c = glyphCache.get(key) { lock.unlock(); return c }
        lock.unlock()

        let blurPx = blur * b
        let pad = 2.0 + blurPx * 2.5 + extent * b + dir * b / 2
        let width = ceil(g.halfSize.x * 2 * b + pad * 2)
        let height = ceil(g.halfSize.y * 2 * b + pad * 2)
        guard width.isFinite, height.isFinite, width > 0, height > 0,
              width < 4096, height < 4096 else { return nil }
        let w = Int(width), h = Int(height)
        // The context owns its storage. An implicit &Array pointer only lives for the initializer call;
        // retaining that pointer for later CoreText drawing can corrupt memory, especially with shadows.
        let ctxOpt: CGContext?
        if colorRaster {
            ctxOpt = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: (w * 4 + 63) & ~63,
                               space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        } else {
            ctxOpt = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: (w + 63) & ~63,
                               space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        }
        guard let ctx = ctxOpt else { return nil }
        ctx.setAllowsFontSmoothing(false)
        ctx.setShouldAntialias(true)
        var rect = CGRect.zero
        var glyph = g.glyph
        CTFontGetBoundingRectsForGlyphs(g.font, .horizontal, &glyph, &rect, 1)
        let path = CTFontCreatePathForGlyph(g.font, glyph, nil)
        let ox = -rect.minX + CGFloat(pad / b), oy = -rect.minY + CGFloat(pad / b)
        func setLevel(_ v: CGFloat) {
            if colorRaster { ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1) }
            else { ctx.setFillColor(gray: v, alpha: 1); ctx.setStrokeColor(gray: v, alpha: 1) }
        }
        let cgJoin: CGLineJoin
        if case .stroke(_, _, let j) = op { cgJoin = j == 1 ? .miter : (j == 2 ? .bevel : .round) } else { cgJoin = .round }

        if case .inner(let dx, let dy) = op {
            // Inner shadow: everything outside the letter casts a (blurred) shadow inward, clipped to the letter.
            guard let path else { return nil }
            ctx.scaleBy(x: CGFloat(b), y: CGFloat(b))
            ctx.translateBy(x: ox, y: oy)
            ctx.addPath(path)
            ctx.clip()
            let shift = CGFloat(w * 4)
            ctx.setShadow(offset: CGSize(width: -shift + CGFloat(dx * b), height: -CGFloat(dy * b)), blur: CGFloat(blurPx * 2),
                          color: CGColor(gray: 1, alpha: 1))
            let m = CGFloat(abs(dx) + abs(dy) + blur * 3 + 4)
            let big = CGRect(x: -ox - m, y: -oy - m, width: CGFloat(w) / CGFloat(b) + m * 2, height: CGFloat(h) / CGFloat(b) + m * 2)
            ctx.translateBy(x: shift / CGFloat(b), y: 0)
            setLevel(1)
            ctx.addRect(big)
            ctx.addPath(path)
            ctx.fillPath(using: .evenOdd)
        } else {
            if blurPx > 0.25 {
                // Real gaussian: draw the glyph off-canvas and keep only its blurred shadow on the canvas.
                ctx.setShadow(offset: CGSize(width: -CGFloat(w * 2), height: 0), blur: CGFloat(blurPx * 2), color: CGColor(gray: 1, alpha: 1))
                ctx.translateBy(x: CGFloat(w * 2), y: 0)
            }
            ctx.scaleBy(x: CGFloat(b), y: CGFloat(b))
            ctx.translateBy(x: ox, y: oy)
            // Directional blur: average of copies along the angle (additive at 1/n each).
            var copies: [CGPoint] = [.zero]
            if dir > 0.5 {
                let n = max(3, min(24, Int(dir * b / 1.5) + 1))
                let a = angle * .pi / 180
                copies = (0..<n).map { k in
                    let t = (Double(k) / Double(n - 1) - 0.5) * dir
                    return CGPoint(x: CGFloat(cos(a) * t), y: CGFloat(-sin(a) * t))
                }
                ctx.setBlendMode(.plusLighter)
            }
            let level = CGFloat(1) / CGFloat(copies.count)
            for o in copies {
                ctx.saveGState()
                ctx.translateBy(x: o.x, y: o.y)
                setLevel(level)
                switch op {
                case .fill:
                    var p0 = CGPoint.zero
                    CTFontDrawGlyphs(g.font, &glyph, &p0, 1, ctx)
                case .outline(let wd):
                    if let path {
                        ctx.addPath(path); ctx.setLineWidth(CGFloat(wd)); ctx.setLineJoin(.round); ctx.strokePath()
                    }
                case .stroke(let wd, let position, _):
                    if let path, wd > 0 {
                        ctx.setLineJoin(cgJoin)
                        if position == 2 {
                            ctx.addPath(path); ctx.clip()
                            ctx.addPath(path); ctx.setLineWidth(CGFloat(wd * 2)); ctx.strokePath()
                        } else {
                            // Outside strokes are 2w centered strokes under the fill (no seam at the edge).
                            ctx.addPath(path); ctx.setLineWidth(CGFloat(position == 1 ? wd : wd * 2)); ctx.strokePath()
                        }
                    }
                case .shape(let e):
                    var p0 = CGPoint.zero
                    CTFontDrawGlyphs(g.font, &glyph, &p0, 1, ctx)
                    if e > 0, let path {
                        ctx.addPath(path); ctx.setLineWidth(CGFloat(e * 2)); ctx.setLineJoin(.round); ctx.strokePath()
                    }
                case .inner: break
                }
                ctx.restoreGState()
            }
        }
        // A bitmap context's first memory row is already the TOP of the image (user space is y-up, but
        // memory is stored top-down), so the bytes are in texture order as-is.
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorRaster ? .rgba8Unorm : .r8Unorm, width: w, height: h, mipmapped: false)
        d.usage = [.shaderRead]
        guard let tex = device.makeTexture(descriptor: d) else { return nil }
        guard let data = ctx.data else { return nil }
        withExtendedLifetime(ctx) {
            tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: data, bytesPerRow: ctx.bytesPerRow)
        }
        let entry = GlyphRaster(tex: tex, pad: pad, scale: b, isColor: colorRaster)
        lock.lock()
        if let existing = glyphCache.get(key) { lock.unlock(); return existing }
        glyphCache.set(key, entry, cost: max(1, tex.allocatedSize))
        lock.unlock()
        return entry
    }
}

extension Renderer {
    /// Per-glyph animated state after applying all animators.
    struct GlyphState {
        var offset = Vec2.zero
        var scale = Vec2(1, 1)
        var rotation = 0.0
        var skew = 0.0
        var opacity = 1.0
        var color = RGBA.white
        var tracking = 0.0
        var blur = 0.0
        var charOffset = 0.0
        var rotX = 0.0
        var rotY = 0.0
        var z = 0.0
        var outline = 0.0
        /// Pivot offset (px).
        var anchor = Vec2.zero
        /// How much `color` replaces the style-stack fills (char colors / animator fill).
        var tintMix = 0.0
        var fillOpacity = 1.0
        /// px added to stroke widths.
        var strokeWidth = 0.0
        var strokeColor: RGBA? = nil
        var strokeMix = 0.0
        /// Extra glow (0...n).
        var glow = 0.0
        var hueShift = 0.0
        var dirBlur = 0.0
        var dirBlurAngle = 0.0
        /// 0...1 chance a letter shows a random character this frame.
        var scramble = 0.0
    }

    static func glyphStates(_ text: TextData, layout: TextLayout, time: Double) -> [GlyphState] {
        TextEngine.glyphStates(text, layout: layout, time: time)
    }

    /// AE Character Offset: letters move through A-Z / a-z, digits through 0-9; other characters stay.
    static func offsetCharacter(_ c: Character, by n: Int) -> Character? {
        guard let v = c.unicodeScalars.first?.value, c.unicodeScalars.count == 1 else { return nil }
        func wrap(_ base: UInt32, _ count: Int) -> Character? {
            let i = ((Int(v - base) + n) % count + count) % count
            return UnicodeScalar(base + UInt32(i)).map(Character.init)
        }
        switch v {
        case 65...90: return wrap(65, 26)
        case 97...122: return wrap(97, 26)
        case 48...57: return wrap(48, 10)
        default: return nil
        }
    }

    /// Builds the params of one glyph pass. `G` maps quad-local px -> target px.
    private func glyphParams(G: simd_double3x3, halfSize hs: Vec2, target: MTLTexture, aa: Double, opacity: Double,
                             blend: UInt32, isColor: Bool) -> GlyphParamsTxt1? {
        let det = G[0][0] * G[1][1] - G[1][0] * G[0][1]
        if abs(det) < 1e-12 || !det.isFinite { return nil }
        let inv = G.inverse
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for cx in [-hs.x - 2, hs.x + 2] { for cy in [-hs.y - 2, hs.y + 2] {
            let p = G * SIMD3(cx, cy, 1)
            let z = max(p.z, 1e-6)
            minX = min(minX, p.x / z); maxX = max(maxX, p.x / z); minY = min(minY, p.y / z); maxY = max(maxY, p.y / z)
        } }
        guard minX.isFinite, minY.isFinite, maxX.isFinite, maxY.isFinite else { return nil }
        let x0 = max(0, Int(floor(max(-1e7, minX)))), y0 = max(0, Int(floor(max(-1e7, minY))))
        let x1 = min(target.width, Int(ceil(min(1e7, maxX)))), y1 = min(target.height, Int(ceil(min(1e7, maxY))))
        if x1 <= x0 || y1 <= y0 { return nil }
        var p = GlyphParamsTxt1()
        p.invRow0 = SIMD4(Float(inv[0][0]), Float(inv[1][0]), Float(inv[2][0]), 0)
        p.invRow1 = SIMD4(Float(inv[0][1]), Float(inv[1][1]), Float(inv[2][1]), 0)
        p.invRow2 = SIMD4(Float(inv[0][2]), Float(inv[1][2]), Float(inv[2][2]), 0)
        p.geom = SIMD4(Float(hs.x), Float(hs.y), Float(max(0, min(1, opacity))), Float(aa))
        p.extra = SIMD4(isColor ? 1 : 0, 1, 0, 0)
        p.modes = SIMD4(blend, 0, 0, 0)
        p.region = SIMD4(UInt32(x0), UInt32(y0), UInt32(x1 - x0), UInt32(y1 - y0))
        return p
    }

    /// Encodes glyph passes into one compute encoder (dispatches run in order).
    func encodeGlyphDraws(cb: MTLCommandBuffer, target: MTLTexture, draws: [GlyphDrawTxt1]) {
        guard !draws.isEmpty, let enc = cb.makeComputeCommandEncoder() else { return }
        enc.setComputePipelineState(glyphPSO)
        enc.setTexture(target, index: 0)
        for d in draws {
            var p = d.params
            enc.setTexture(d.tex, index: 1)
            enc.setBytes(&p, length: MemoryLayout<GlyphParamsTxt1>.stride, index: 0)
            dispatch(enc, pso: glyphPSO, width: Int(p.region.z), height: Int(p.region.w))
        }
        enc.endEncoding()
    }

    /// Draws a text layer. `M` maps layer-local px -> target px; `density` = target px per local px.
    func drawText(cb: MTLCommandBuffer, target: MTLTexture, matrix M: simd_double3x3, density: Double,
                  layer: Layer, time: Double, opacity: Double, blend: BlendMode) {
        guard let text = Self.renderTextData(layer, time: time) else { return }
        let beats = textBeats
        let lay = TextEngine.shared.layout(text, time: time)
        let states = TextEngine.glyphStates(text, layout: lay, time: time, beats: beats)
        let chars = Array(text.string)
        // Path for text-on-path (the layer's first mask), measured once per frame.
        let pathTrack: PathTrack? = (text.onPath ?? false) ? layer.masks.first.map {
            PathTrack($0.path.value(at: time), offsetPercent: text.pathOffset?.value(at: time) ?? 0)
        } : nil
        // Letter effects: per animator, how much each glyph belongs to its effected copy.
        let fxAnimators = text.animators.filter { a in a.isEnabled && (a.letterEffects ?? []).contains { $0.isEnabled } }
        let fxWeights: [[Double]] = fxAnimators.map { a in
            lay.glyphs.map { g in min(1, max(0, TextEngine.selection(a, glyph: g, layout: lay, time: time, beats: beats))) }
        }
        var baseDraws: [GlyphDrawTxt1] = []
        var fxDraws: [[GlyphDrawTxt1]] = Array(repeating: [], count: fxAnimators.count)
        let style = text.style
        let blendIndex = blend.shaderIndex
        let addIndex = BlendMode.add.shaderIndex
        let boxCenter = Vec2(Double(lay.bounds.midX), Double(lay.bounds.midY))
        let boxHalf = Vec2(Double(lay.bounds.width) / 2, Double(lay.bounds.height) / 2)
        let frameStep = Int((time * 20).rounded(.down))

        for (gi, g0) in lay.glyphs.enumerated() where !g0.isSpace {
            let st = states[gi]
            let a = opacity * st.opacity
            if a <= 0.001 { continue }
            var g = g0
            // Character Offset / scramble: swap in the shifted letter's glyph (same spot, its own size).
            var shift = Int(max(-1e6, min(1e6, st.charOffset)).rounded())
            if st.scramble > 0.001, SelectorMath.hash01(g.charIndex, frameStep &* 7919) < st.scramble {
                shift += 1 + Int(SelectorMath.hash01(g.charIndex &+ 31, frameStep) * 24)
            }
            if shift != 0, g.charIndex < chars.count, let shifted = Self.offsetCharacter(chars[g.charIndex], by: shift) {
                var u = Array(String(shifted).utf16), gl = [CGGlyph](repeating: 0, count: u.count)
                if CTFontGetGlyphsForCharacters(g.font, &u, &gl, u.count), gl[0] != 0 {
                    var r = CGRect.zero
                    CTFontGetBoundingRectsForGlyphs(g.font, .horizontal, &gl, &r, 1)
                    g.glyph = gl[0]
                    g.halfSize = Vec2(Double(r.width) / 2, Double(r.height) / 2)
                    g.center = Vec2(g.origin.x + Double(r.midX), g.origin.y - Double(r.midY))
                }
            }
            guard let H = TextEngine.placement(g, st, layout: lay, track: pathTrack) else { continue }
            let G = M * H
            let rasterScale = density * max(abs(st.scale.x), abs(st.scale.y), 0.05)
            let aa = 1 / max(1e-4, density * min(abs(st.scale.x), abs(st.scale.y)))
            var passes: [GlyphDrawTxt1] = []
            func add(_ r: GlyphRaster?, _ Gm: simd_double3x3, alpha: Double, blend b: UInt32, paint: (inout GlyphParamsTxt1) -> Void) {
                guard let r, alpha > 0.0005 else { return }
                let hs = Vec2(g.halfSize.x + r.pad / r.scale, g.halfSize.y + r.pad / r.scale)
                guard var p = glyphParams(G: Gm, halfSize: hs, target: target, aa: aa, opacity: alpha, blend: b, isColor: r.isColor) else { return }
                paint(&p)
                passes.append(GlyphDrawTxt1(params: p, tex: r.tex))
            }
            func solid(_ c: RGBA) -> (inout GlyphParamsTxt1) -> Void { { p in p.c0 = c.simd; p.gradA = SIMD4(0, 0, 0, 1) } }
            let engine = TextEngine.shared
            let cs = text.charStyles?[g.charID]

            // Stroke layers for this letter (char style / animator overrides applied).
            var strokes: [(w: Double, pos: Int, join: Int, color: RGBA, alpha: Double)] = []
            for s in style?.strokes ?? [] where s.isEnabled {
                strokes.append((max(0, s.width.value(at: time) + st.strokeWidth),
                                s.position == .outside ? 0 : (s.position == .center ? 1 : 2),
                                s.join == .round ? 0 : (s.join == .miter ? 1 : 2),
                                s.color.value(at: time), max(0, s.opacity.value(at: time) / 100)))
            }
            if let cs, cs.strokeColor != nil || cs.strokeWidth != nil {
                if strokes.isEmpty {
                    if let w = cs.strokeWidth, w > 0 { strokes.append((w + st.strokeWidth, 0, 0, cs.strokeColor ?? .black, 1)) }
                } else {
                    if let c = cs.strokeColor { strokes[0].color = c }
                    if let w = cs.strokeWidth { strokes[0].w = max(0, w + st.strokeWidth) }
                }
            }
            if strokes.isEmpty, st.strokeWidth > 0 { strokes.append((st.strokeWidth, 0, 0, st.strokeColor ?? .black, 1.0)) }
            if let sc = st.strokeColor, st.strokeMix > 0 {
                for k in strokes.indices { strokes[k].color = RGBA.lerp(strokes[k].color, sc, st.strokeMix) }
            }
            let reach = strokes.reduce(0.0) { max($0, $1.pos == 2 ? 0 : ($1.pos == 1 ? $1.w / 2 : $1.w)) }
            let fillColor = st.color.hueShifted(st.hueShift)

            // 1. Drop shadows.
            for s in style?.shadows ?? [] where s.isEnabled && s.kind == .drop {
                let o = s.offset(at: time)
                let T = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(o.x, o.y, 1)))
                let r = engine.raster(g, scale: rasterScale, op: .shape(reach + max(0, st.outline)), blur: st.blur + max(0, s.blur.value(at: time)),
                                      dirBlur: st.dirBlur, dirAngle: st.dirBlurAngle, device: device)
                var c = s.color.value(at: time); c.a *= max(0, s.opacity.value(at: time) / 100)
                add(r, M * T * H, alpha: a, blend: blendIndex, paint: solid(c))
            }
            // 2. Strokes, outermost (last) first.
            for s in strokes.reversed() where s.w > 0 {
                let r = engine.raster(g, scale: rasterScale, op: .stroke(s.w, s.pos, s.join), blur: st.blur,
                                      dirBlur: st.dirBlur, dirAngle: st.dirBlurAngle, device: device)
                var c = s.color; c.a *= s.alpha
                add(r, G, alpha: a, blend: blendIndex, paint: solid(c))
            }
            // 3. Fills.
            let fillOp: GlyphMaskOp = st.outline > 0.25 ? .outline(st.outline) : .fill
            let fillRaster = engine.raster(g, scale: rasterScale, op: fillOp, blur: st.blur, dirBlur: st.dirBlur,
                                           dirAngle: st.dirBlurAngle, device: device)
            let fills = (style?.fills ?? []).filter(\.isEnabled)
            if fills.isEmpty {
                add(fillRaster, G, alpha: a * st.fillOpacity, blend: blendIndex, paint: solid(fillColor))
            } else {
                for f in fills {
                    let colors = f.colors.prefix(4).map { $0.value(at: time).hueShifted(st.hueShift) }
                    let n = max(1, colors.count)
                    let stops: [Double] = (f.stops?.count == colors.count ? f.stops! : (0..<n).map { n == 1 ? 0 : Double($0) / Double(n - 1) })
                    let ang = f.angle.value(at: time) * .pi / 180
                    let rel = f.space == .text ? g.center - boxCenter : Vec2.zero
                    let half = f.space == .text ? boxHalf : g.halfSize
                    let kind: Float = f.kind == .solid ? 0 : (f.kind == .linear ? 1 : 2)
                    let radial = max(0.01, (f.radialScale?.value(at: time) ?? 100) / 100)
                    add(fillRaster, G, alpha: a * st.fillOpacity * max(0, f.opacity.value(at: time) / 100), blend: blendIndex) { p in
                        let cc = colors.isEmpty ? [RGBA.white] : colors
                        p.c0 = cc[0].simd
                        p.c1 = cc[min(1, cc.count - 1)].simd
                        p.c2 = cc[min(2, cc.count - 1)].simd
                        p.c3 = cc[min(3, cc.count - 1)].simd
                        p.stops = SIMD4(Float(stops[0]), Float(stops[min(1, stops.count - 1)]),
                                        Float(stops[min(2, stops.count - 1)]), Float(stops[min(3, stops.count - 1)]))
                        p.gradA = SIMD4(kind, Float(cos(ang)), Float(sin(ang)), Float(cc.count))
                        p.gradB = SIMD4(Float(rel.x), Float(rel.y), Float(half.x), Float(half.y))
                        p.tint = SIMD4(Float(fillColor.r), Float(fillColor.g), Float(fillColor.b), Float(st.tintMix))
                        p.extra.y = Float(radial)
                    }
                }
            }
            // 4. Inner shadows.
            for s in style?.shadows ?? [] where s.isEnabled && s.kind == .inner {
                let o = s.offset(at: time)
                let r = engine.raster(g, scale: rasterScale, op: .inner(o.x, o.y), blur: max(0, s.blur.value(at: time)), device: device)
                var c = s.color.value(at: time); c.a *= max(0, s.opacity.value(at: time) / 100)
                add(r, G, alpha: a, blend: blendIndex, paint: solid(c))
            }
            // 5. Glow (additive light, keeps the hue).
            var glowAmount = st.glow
            var glowColor = fillColor
            var glowRadius = 12.0
            if let gl = style?.glow, gl.isEnabled {
                glowAmount += max(0, gl.intensity.value(at: time) / 100)
                if gl.useFillColor != true { glowColor = gl.color.value(at: time) }
                glowRadius = max(0, gl.radius.value(at: time))
            }
            if glowAmount > 0.001, glowRadius > 0 {
                let r = engine.raster(g, scale: rasterScale, op: .shape(reach), blur: glowRadius + st.blur, device: device)
                let n = Int(min(4, glowAmount).rounded(.up))
                for _ in 0..<max(1, n) {
                    add(r, G, alpha: a * min(4, glowAmount) / Double(max(1, n)), blend: addIndex, paint: solid(glowColor))
                }
            }

            // Split between the plain letter and its letter-effect copies.
            let weights = fxWeights.map { $0[gi] }
            let total = weights.reduce(0, +)
            let baseW = max(0, 1 - min(1, total))
            func scaled(_ list: [GlyphDrawTxt1], _ k: Double) -> [GlyphDrawTxt1] {
                list.map { d in var c = d; c.params.geom.z *= Float(k); return c }
            }
            if baseW > 0.0005 { baseDraws += baseW >= 0.9995 ? passes : scaled(passes, baseW) }
            for k in weights.indices where weights[k] > 0.0005 {
                let wk = total > 1 ? weights[k] / total : weights[k]
                var list = scaled(passes, wk)
                // Effect buffers are composited with the layer's blend afterwards.
                for i in list.indices where list[i].params.modes.x != addIndex { list[i].params.modes.x = BlendMode.normal.shaderIndex }
                fxDraws[k] += list
            }
        }
        encodeGlyphDraws(cb: cb, target: target, draws: baseDraws)
        guard !fxAnimators.isEmpty, let pool = currentPool else { return }
        for (k, anim) in fxAnimators.enumerated() where !fxDraws[k].isEmpty {
            let buf = pool.acquire(width: target.width, height: target.height)
            fx.run("fxClear", cb, textures: [buf], grid: buf)
            encodeGlyphDraws(cb: cb, target: buf, draws: fxDraws[k])
            var current: MTLTexture = buf
            for e in anim.letterEffects ?? [] where e.isEnabled {
                guard let def = EffectRegistry.definition(e.typeID), case .pixels(let run) = def.stage else { continue }
                current = run(EffectContext(gpu: fx, cb: cb, input: current, effect: e, time: time, unit: density, pool: pool))
            }
            let whole = simd_double3x3(columns: (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(Double(target.width) / 2, Double(target.height) / 2, 1)))
            drawQuad(cb: cb, target: target, matrix: whole, halfSize: Vec2(Double(target.width) / 2, Double(target.height) / 2), aa: 1,
                     opacity: 1, layer: layer, time: time, source: .image(current), premultipliedImage: true, blendOverride: blend)
        }
    }

    /// The text a layer draws at `time` (counter value, spacing effect applied).
    static func renderTextData(_ layer: Layer, time: Double) -> TextData? {
        guard var text = layer.text?.resolved(at: time) else { return nil }
        for effect in layer.effects where effect.isEnabled && effect.typeID == "awi.textSpacing" {
            let spacing = effect.number("spacing", time)
            if spacing.isFinite { text.tracking = Animated(text.tracking.value(at: time) + min(1000, max(-300, spacing))) }
            let anchor = effect.choice("anchor")
            if anchor > 0 { text.spacingAnchor = anchor - 1 }
        }
        return text
    }

    /// Local bounds of a text layer (unanimated layout) — handles, snapping, UI.
    static func textBounds(_ layer: Layer, time: Double) -> CGRect? {
        guard let t = renderTextData(layer, time: time) else { return nil }
        return TextEngine.shared.layout(t, time: time).bounds
    }

    /// Local bounds of everything a text layer draws at `time` (animated letters, style stack, letter effects).
    static func textRenderBounds(_ layer: Layer, time: Double, beats: [Double] = []) -> CGRect? {
        guard let t = renderTextData(layer, time: time) else { return nil }
        let lay = TextEngine.shared.layout(t, time: time)
        let track: PathTrack? = (t.onPath ?? false) ? layer.masks.first.map {
            PathTrack($0.path.value(at: time), offsetPercent: t.pathOffset?.value(at: time) ?? 0)
        } : nil
        return TextEngine.animatedBounds(t, layout: lay, time: time, beats: beats, track: track)
    }
}


/// A path measured by length: point + direction at any distance along it (for text on path).
struct PathTrack {
    private var pts: [Vec2] = []
    private var cum: [Double] = [0]
    let offset: Double
    var length: Double { cum.last ?? 0 }

    init(_ path: BezierPath, offsetPercent: Double) {
        let segs = path.segments(stepsPerCurve: 24)
        if let f = segs.first { pts.append(Vec2(Double(f.x), Double(f.y))) }
        for s in segs {
            let p = Vec2(Double(s.z), Double(s.w))
            cum.append(cum.last! + hypot(p.x - pts.last!.x, p.y - pts.last!.y))
            pts.append(p)
        }
        let total = cum.last ?? 0
        offset = total * offsetPercent / 100
    }

    /// Point and angle (radians) at `d` px along the path (clamped to the ends, extended along the end tangents).
    func point(at d: Double) -> (Vec2, Double) {
        guard pts.count >= 2 else { return (pts.first ?? .zero, 0) }
        var i = 1
        while i < cum.count - 1 && cum[i] < d { i += 1 }
        let a = pts[i - 1], b = pts[i]
        let segLen = max(1e-9, cum[i] - cum[i - 1])
        let f = (d - cum[i - 1]) / segLen
        return (a + (b - a) * f, atan2(b.y - a.y, b.x - a.x))
    }
}
