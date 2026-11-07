import Foundation
import CoreText
import simd

extension Renderer {
    /// Real 3D text: one Text3DGlyph per visible letter. Every letter animator still drives it — the glyph state
    /// (offset, scale, skew, rotation, X / Y flips, depth, anchor, opacity) becomes a real 3D transform, so letters turn
    /// and fly in true depth. Coordinates follow `modelPlacement` (model space = layer px / fit, y up, z toward viewer).
    static func text3DGlyphs(_ layer: Layer, time: Double, beats: [Double]) -> [Text3DGlyph] {
        guard let text = renderTextData(layer, time: time) else { return [] }
        let lay = TextEngine.shared.layout(text, time: time)
        let states = TextEngine.glyphStates(text, layout: lay, time: time, beats: beats)
        let size = layer.size.value(at: time), sc = layer.transform.scale.value(at: time)
        let fit = max(1e-3, min(size.x, size.y) / 2)
        let depthScale = max(1e-3, (abs(sc.x) + abs(sc.y)) / 200)
        // Layer local px (y down, z away) -> model space (same map as modelPlacement's `local * flip`, inverted).
        let toModel = simd_double4x4(diagonal: SIMD4(1 / fit, -1 / fit, -1 / (fit * depthScale), 1))
        // Glyph space (CoreText: y up, z toward the viewer) -> layer local orientation.
        let glyphFlip = simd_double4x4(diagonal: SIMD4(1, -1, -1, 1))
        var out: [Text3DGlyph] = []
        out.reserveCapacity(lay.glyphs.count)
        for (gi, g) in lay.glyphs.enumerated() where !g.isSpace {
            let st = gi < states.count ? states[gi] : Renderer.GlyphState()
            guard st.opacity > 0.001 else { continue }
            let m = letterMatrix(g, st)
            let full = toModel * m * glyphFlip
            guard (0..<4).allSatisfy({ c in (0..<4).allSatisfy { full[c][$0].isFinite } }) else { continue }
            let fontName = CTFontCopyPostScriptName(g.font) as String
            let fontSize = Double(CTFontGetSize(g.font))
            out.append(Text3DGlyph(glyph: g.glyph, fontName: fontName, fontSize: fontSize, transform: floatMatrix(full),
                                   opacity: min(1, max(0, st.opacity))))
        }
        return out
    }

    /// Glyph baseline origin -> layer local px, with the same pivot / order as TextEngine.placement (2D letters).
    static func letterMatrix(_ g: LaidGlyph, _ st: GlyphState) -> simd_double4x4 {
        let rot = st.rotation * .pi / 180 + g.baseRotation
        let skew = tan(max(-89, min(89, st.skew)) * .pi / 180)
        let pivot = (g.baseRotation != 0 ? g.center : Vec2(g.center.x, g.origin.y)) + st.offset + st.anchor
        let origin = g.origin + st.offset
        let rx = st.rotX * .pi / 180, ry = st.rotY * .pi / 180
        let sz = (abs(st.scale.x) + abs(st.scale.y)) / 2
        let KS = simd_double4x4(columns: (SIMD4(st.scale.x, 0, 0, 0), SIMD4(-skew * st.scale.y, st.scale.y, 0, 0),
                                          SIMD4(0, 0, sz, 0), SIMD4(0, 0, 0, 1)))
        let Rx = simd_double4x4(columns: (SIMD4(1, 0, 0, 0), SIMD4(0, cos(rx), sin(rx), 0), SIMD4(0, -sin(rx), cos(rx), 0), SIMD4(0, 0, 0, 1)))
        let Ry = simd_double4x4(columns: (SIMD4(cos(ry), 0, -sin(ry), 0), SIMD4(0, 1, 0, 0), SIMD4(sin(ry), 0, cos(ry), 0), SIMD4(0, 0, 0, 1)))
        let Rz = simd_double4x4(columns: (SIMD4(cos(rot), sin(rot), 0, 0), SIMD4(-sin(rot), cos(rot), 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, 0, 0, 1)))
        func translate(_ x: Double, _ y: Double, _ z: Double) -> simd_double4x4 {
            var m = matrix_identity_double4x4
            m.columns.3 = SIMD4(x, y, z, 1)
            return m
        }
        return translate(pivot.x, pivot.y, st.z) * Rz * Ry * Rx * KS * translate(origin.x - pivot.x, origin.y - pivot.y, 0)
    }

    private static func floatMatrix(_ m: simd_double4x4) -> simd_float4x4 {
        simd_float4x4(SIMD4<Float>(m.columns.0), SIMD4<Float>(m.columns.1), SIMD4<Float>(m.columns.2), SIMD4<Float>(m.columns.3))
    }
}
