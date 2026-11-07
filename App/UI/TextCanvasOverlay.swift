import SwiftUI
import simd

/// Where the letters of a text layer are on screen right now (animated offsets included).
struct TextCanvasGeometry {
    struct Glyph {
        let charIndex: Int
        let id: UInt32
        let quad: [CGPoint]
        let center: CGPoint
        /// Caret line at the letter's left / right edge (top, bottom).
        let left: (CGPoint, CGPoint)
        let right: (CGPoint, CGPoint)
    }

    let M: simd_double3x3
    let fit: CGRect
    let glyphs: [Glyph]
    let ids: [UInt32]
    let charCount: Int
    let hitShape: Path

    init(layer: Layer, project: Project, text: TextData, time: Double, fit: CGRect) {
        self.fit = fit
        let s = Double(fit.width) / Double(max(1, project.width))
        let M = Renderer.placementMatrix(layer, camera: Renderer.activeCamera(project, time: time), time: time, renderScale: s)
        self.M = M
        let lay = TextEngine.shared.layout(text, time: time)
        let states = TextEngine.glyphStates(text, layout: lay, time: time)
        let ids = layer.text?.resolvedCharIDs ?? text.resolvedCharIDs
        self.ids = ids
        charCount = Array(text.string).count
        func screen(_ v: Vec2) -> CGPoint {
            let q = M * SIMD3(v.x, v.y, 1)
            let z = max(q.z, 1e-6)
            return CGPoint(x: fit.minX + CGFloat(q.x / z), y: fit.minY + CGFloat(q.y / z))
        }
        // Screen points per layer px (for a finger-sized pad around each letter).
        let p0 = screen(.zero), p1 = screen(Vec2(1, 0))
        let ppl = max(0.01, Double(hypot(p1.x - p0.x, p1.y - p0.y)))
        let pad = 10 / ppl
        let em = max(4, text.fontSize)
        var out: [Glyph] = []
        var shape = Path()
        for (gi, g) in lay.glyphs.enumerated() {
            let st = gi < states.count ? states[gi] : Renderer.GlyphState()
            let off = st.offset.x.isFinite && st.offset.y.isFinite ? st.offset : .zero
            let c = g.center + off
            let hx = max(g.halfSize.x, em * 0.14), hy = max(g.halfSize.y, em * 0.32)
            let quad = [Vec2(c.x - hx, c.y - hy), Vec2(c.x + hx, c.y - hy), Vec2(c.x + hx, c.y + hy), Vec2(c.x - hx, c.y + hy)].map(screen)
            let padded = [Vec2(c.x - hx - pad, c.y - hy - pad), Vec2(c.x + hx + pad, c.y - hy - pad),
                          Vec2(c.x + hx + pad, c.y + hy + pad), Vec2(c.x - hx - pad, c.y + hy + pad)].map(screen)
            shape.addLines(padded); shape.closeSubpath()
            let baseY = g.origin.y + off.y
            let leftX = (g.isSpace ? c.x - hx : g.origin.x + off.x), rightX = c.x + hx
            let id = g.charIndex < ids.count ? ids[g.charIndex] : g.charID
            out.append(Glyph(charIndex: g.charIndex, id: id, quad: quad, center: screen(c),
                             left: (screen(Vec2(leftX, baseY - em * 0.8)), screen(Vec2(leftX, baseY + em * 0.2))),
                             right: (screen(Vec2(rightX, baseY - em * 0.8)), screen(Vec2(rightX, baseY + em * 0.2)))))
        }
        glyphs = out
        hitShape = shape
    }

    /// Layer-local px under a screen point (on the layer plane).
    func toLocal(_ p: CGPoint) -> Vec2 {
        let h = M.inverse * SIMD3(Double(p.x - fit.minX), Double(p.y - fit.minY), 1)
        let z = abs(h.z) > 1e-9 ? h.z : 1e-9
        return Vec2(h.x / z, h.y / z)
    }

    /// The letter nearest to a screen point.
    func nearest(_ p: CGPoint) -> Glyph? {
        glyphs.min { a, b in hypot(a.center.x - p.x, a.center.y - p.y) < hypot(b.center.x - p.x, b.center.y - p.y) }
    }

    /// Caret index for a tap: before the nearest letter, or after it when the tap is on its right half.
    func caretIndex(_ p: CGPoint) -> Int {
        guard let g = nearest(p) else { return charCount }
        let mid = CGPoint(x: (g.left.0.x + g.right.0.x) / 2, y: (g.left.0.y + g.right.0.y) / 2)
        let dir = CGPoint(x: g.right.0.x - g.left.0.x, y: g.right.0.y - g.left.0.y)
        let after = (p.x - mid.x) * dir.x + (p.y - mid.y) * dir.y > 0
        return min(charCount, g.charIndex + (after ? 1 : 0))
    }

    func caretLine(_ i: Int) -> (CGPoint, CGPoint)? {
        if let g = glyphs.first(where: { $0.charIndex == i }) { return g.left }
        if let g = glyphs.last(where: { $0.charIndex < i }) { return g.right }
        return nil
    }

    func draw(_ ctx: GraphicsContext, selected: Set<UInt32>, caret: Range<Int>?) {
        for g in glyphs where selected.contains(g.id) {
            var p = Path(); p.addLines(g.quad); p.closeSubpath()
            ctx.fill(p, with: .color(Theme.accent.opacity(0.32)))
            ctx.stroke(p, with: .color(Theme.accentGlow), lineWidth: 1.5)
        }
        guard let caret else { return }
        if caret.isEmpty {
            if let l = caretLine(caret.lowerBound) {
                var p = Path(); p.move(to: l.0); p.addLine(to: l.1)
                ctx.stroke(p, with: .color(Theme.accentGlow), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        } else {
            for g in glyphs where caret.contains(g.charIndex) {
                var p = Path(); p.addLines(g.quad); p.closeSubpath()
                ctx.fill(p, with: .color(Theme.accentGlow.opacity(0.28)))
            }
        }
    }
}

/// On-canvas letter editing while Text Studio is open: tap a letter to type there (real caret), drag across letters
/// to select them, drag selected letters to move them (writes their animator, keyframes when animated).
/// Pinch sizing is handled by the canvas pinch (TextStudioSession.pinch). Touches outside the letters fall through
/// to the canvas (moving the layer as usual).
struct TextCanvasOverlay: View {
    @ObservedObject var state: EditorState
    @ObservedObject private var session = TextStudioSession.shared
    let fit: CGRect
    @State private var mode: Mode?

    enum Mode {
        case select(anchor: Int)
        case move(base: Vec2, startLocal: Vec2, ids: [UInt32], anchor: Bool)
    }

    var body: some View {
        let p = state.canvasProject
        let t = state.currentTime
        if let id = state.selectedLayerID,
           let layer = Renderer.resolveParenting(p, time: t).layers.first(where: { $0.id == id }), layer.isActive(at: t),
           layer.text?.counter == nil, layer.text?.onPath != true, layer.text?.text3D == nil,
           let text = Renderer.renderTextData(layer, time: t) {
            let geo = TextCanvasGeometry(layer: layer, project: p, text: text, time: t, fit: fit)
            let selected = Set(session.selectedIDs)
            let caret = state.textTyping ? session.caret : nil
            ZStack {
                Canvas { ctx, _ in geo.draw(ctx, selected: selected, caret: caret) }
                    .allowsHitTesting(false)
                Color.clear
                    .contentShape(geo.hitShape)
                    .gesture(drag(geo, layerText: layer.text ?? text, time: t))
                    .simultaneousGesture(SpatialTapGesture().onEnded { v in tap(geo, at: v.location) })
                    .accessibilityLabel("Text Letters")
            }
            .onAppear { session.follow(id) }
        }
    }

    private func tap(_ geo: TextCanvasGeometry, at point: CGPoint) {
        let i = geo.caretIndex(point)
        session.selectedIDs = []
        session.caret = i..<i
        if !state.textTyping { state.beginTyping() }
    }

    private func drag(_ geo: TextCanvasGeometry, layerText: TextData, time: Double) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                if mode == nil {
                    guard let g = geo.nearest(v.startLocation) else { return }
                    if session.selectedIDs.contains(g.id) {
                        let ids = session.selectedIDs
                        let anchor = session.dragMovesAnchor
                        let base = anchor ? TextStudioLogic.selectionAnchor(layerText, ids: ids, at: time)
                                          : TextStudioLogic.selectionOffset(layerText, ids: ids, at: time)
                        mode = .move(base: base, startLocal: geo.toLocal(v.startLocation), ids: ids, anchor: anchor)
                        state.beginPanelGesture(anchor ? "Move Letter Anchor" : "Move Letters")
                    } else {
                        mode = .select(anchor: g.charIndex)
                    }
                }
                switch mode {
                case .select(let a)?:
                    guard let g = geo.nearest(v.location) else { return }
                    let lo = min(a, g.charIndex), hi = max(a, g.charIndex) + 1
                    let ids = Array(geo.ids[max(0, min(lo, geo.ids.count))..<max(0, min(hi, geo.ids.count))])
                    if ids != session.selectedIDs { session.selectedIDs = ids }
                    if state.textTyping { session.caret = lo..<hi }
                case .move(let base, let start, let ids, let anchor)?:
                    let d = geo.toLocal(v.location) - start
                    guard d.x.isFinite, d.y.isFinite else { return }
                    let value = base + d
                    let tt = state.currentTime
                    state.editTextContinuous { td in
                        if anchor { TextStudioLogic.setSelectionAnchor(&td, ids: ids, to: value, at: tt) }
                        else { TextStudioLogic.setSelectionOffset(&td, ids: ids, to: value, at: tt) }
                    }
                case nil:
                    break
                }
            }
            .onEnded { _ in
                if case .move? = mode { state.endPanelGesture() }
                mode = nil
            }
    }
}
