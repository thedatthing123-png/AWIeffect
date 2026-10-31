import Foundation

/// Built-in LUT pack (AWIeffect's own looks, written as standard .cube files into the LUT library on first launch,
/// so they show up in CC Studio's LUT list next to imported ones and can be shared / deleted like any LUT).
extension LUTLibrary {
    private static let packVersion = 1

    typealias Look = (Double, Double, Double) -> (Double, Double, Double)

    private static func lum(_ r: Double, _ g: Double, _ b: Double) -> Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }
    private static func sat(_ c: (Double, Double, Double), _ s: Double) -> (Double, Double, Double) {
        let l = lum(c.0, c.1, c.2); return (l + (c.0 - l) * s, l + (c.1 - l) * s, l + (c.2 - l) * s)
    }
    private static func contrast(_ v: Double, _ k: Double) -> Double { (v - 0.5) * k + 0.5 }
    private static func sCurve(_ v: Double, _ k: Double) -> Double {
        let x = min(max(v, 0), 1); let s = x * x * (3 - 2 * x); return x + (s - x) * k
    }
    /// Split toning: shadows tinted toward `sh`, highlights toward `hi`.
    private static func split(_ c: (Double, Double, Double), sh: (Double, Double, Double), hi: (Double, Double, Double), amt: Double) -> (Double, Double, Double) {
        let l = lum(c.0, c.1, c.2), ws = (1 - l) * amt, wh = l * amt
        return (c.0 + (sh.0 - 0.5) * ws + (hi.0 - 0.5) * wh, c.1 + (sh.1 - 0.5) * ws + (hi.1 - 0.5) * wh, c.2 + (sh.2 - 0.5) * ws + (hi.2 - 0.5) * wh)
    }

    static let builtInLooks: [(String, Look)] = [
        ("Teal & Orange", { r, g, b in let c = split((r, g, b), sh: (0.2, 0.55, 0.62), hi: (0.85, 0.55, 0.3), amt: 0.55); let s = sat(c, 1.15); return (sCurve(s.0, 0.4), sCurve(s.1, 0.4), sCurve(s.2, 0.4)) }),
        ("Bleach Bypass", { r, g, b in let s = sat((r, g, b), 0.45); return (contrast(s.0, 1.35), contrast(s.1, 1.35), contrast(s.2, 1.35)) }),
        ("Warm Film", { r, g, b in (0.05 + sCurve(r, 0.25) * 0.95 * 1.04, 0.04 + sCurve(g, 0.25) * 0.95, 0.03 + sCurve(b, 0.25) * 0.88) }),
        ("Cool Night", { r, g, b in let s = sat((r, g, b), 0.75); return (s.0 * 0.78, s.1 * 0.88, s.2 * 1.08 + 0.03) }),
        ("Anime Pastel", { r, g, b in let s = sat((r, g, b), 1.25); return (0.08 + s.0 * 0.92, 0.09 + s.1 * 0.92, 0.12 + s.2 * 0.9) }),
        ("Cyberpunk", { r, g, b in let c = split((r, g, b), sh: (0.35, 0.2, 0.7), hi: (0.95, 0.35, 0.85), amt: 0.6); return sat(c, 1.3) }),
        ("Noir", { r, g, b in let l = sCurve(contrast(lum(r, g, b), 1.3), 0.6); return (l, l, l) }),
        ("Faded Vintage", { r, g, b in let s = sat((r, g, b), 0.65); return (0.12 + s.0 * 0.82 + 0.02, 0.1 + s.1 * 0.8, 0.08 + s.2 * 0.72) }),
        ("Golden Hour", { r, g, b in let c = split((r, g, b), sh: (0.55, 0.42, 0.35), hi: (1.0, 0.75, 0.35), amt: 0.5); return sat(c, 1.1) }),
        ("Matrix Green", { r, g, b in let l = lum(r, g, b); return (l * 0.55, min(1, l * 1.15 + 0.03), l * 0.5) }),
        ("Moody Desat", { r, g, b in let s = sat((r, g, b), 0.55); return (sCurve(s.0, 0.5) * 0.95, sCurve(s.1, 0.5) * 0.97, sCurve(s.2, 0.5)) }),
        ("Vibrant Pop", { r, g, b in let s = sat((r, g, b), 1.45); return (sCurve(s.0, 0.35), sCurve(s.1, 0.35), sCurve(s.2, 0.35)) }),
        ("Sepia", { r, g, b in let l = lum(r, g, b); return (l * 1.07 + 0.04, l * 0.92 + 0.02, l * 0.72) }),
        ("Cross Process", { r, g, b in (sCurve(r, 0.6), min(1, g * 1.05 + 0.03), b * 0.75 + 0.12) }),
        ("Ice", { r, g, b in let s = sat((r, g, b), 0.7); return (s.0 * 0.88 + 0.04, s.1 * 0.97 + 0.04, min(1, s.2 * 1.08 + 0.08)) }),
        ("Crimson", { r, g, b in let l = lum(r, g, b); let red = max(0, r - max(g, b)); let k = min(1, red * 3); return (r, l + (g - l) * k, l + (b - l) * k) }),
        ("Soft Portrait", { r, g, b in let c = split((r, g, b), sh: (0.52, 0.48, 0.5), hi: (0.62, 0.5, 0.42), amt: 0.35); return (0.03 + sCurve(c.0, 0.15) * 0.97, 0.03 + sCurve(c.1, 0.15) * 0.97, 0.03 + sCurve(c.2, 0.15) * 0.95) }),
        ("Green Shadows", { r, g, b in let c = split((r, g, b), sh: (0.42, 0.6, 0.48), hi: (0.55, 0.52, 0.46), amt: 0.45); return sat(c, 0.95) }),
        ("Purple Sunset", { r, g, b in let c = split((r, g, b), sh: (0.45, 0.3, 0.65), hi: (1.0, 0.6, 0.45), amt: 0.55); return sat(c, 1.15) }),
        ("Manga Ink", { r, g, b in let l = lum(r, g, b); let v = 1 / (1 + exp(-(l - 0.5) * 12)); return (0.06 + v * 0.92, 0.05 + v * 0.9, 0.04 + v * 0.86) }),
    ]

    /// Writes the built-in looks as .cube files once (and again when the pack grows).
    func installBuiltIns() {
        let key = "awi.lutPackVersion"
        guard UserDefaults.standard.integer(forKey: key) < Self.packVersion else { return }
        let n = 17
        for (name, f) in Self.builtInLooks {
            var s = "TITLE \"AWI \(name)\"\nLUT_3D_SIZE \(n)\n"
            s.reserveCapacity(n * n * n * 26)
            for bi in 0..<n { for gi in 0..<n { for ri in 0..<n {
                let o = f(Double(ri) / Double(n - 1), Double(gi) / Double(n - 1), Double(bi) / Double(n - 1))
                s += String(format: "%.5f %.5f %.5f\n", min(max(o.0, 0), 1), min(max(o.1, 0), 1), min(max(o.2, 0), 1))
            } } }
            try? s.write(to: Self.folder.appendingPathComponent("AWI \(name).cube"), atomically: true, encoding: .utf8)
        }
        UserDefaults.standard.set(Self.packVersion, forKey: key)
    }
}
