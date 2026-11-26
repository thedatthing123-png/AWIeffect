import Foundation

/// Small title collection with distinct timing, designed to keep the original text and font editable.
enum TextTitleCollection {
    static let animations: [TextPreset] = [
        TextPreset(id: "titles.chapter", name: "Chapter Reveal", category: "Titles") { start, duration in
            var lines = TextSelector()
            lines.basedOn = .lines
            lines.shape = .rampUp
            lines.easeHigh = 62
            lines.start = track(start, duration, [(0, -58), (0.9, 100)])
            lines.end = track(start, duration, [(0, 0), (0.9, 158)])
            return [animator("Line Reveal", selector: lines) {
                $0.position = Animated(Vec2(0, 44))
                $0.opacity = Animated(0)
                $0.blur = track(start, duration, [(0, 11), (0.68, 2), (0.95, 0)])
            }, animator("Tracking Settle") {
                $0.tracking = track(start, duration, [(0, 8), (0.58, 2.5), (1, 0)])
            }]
        },
        TextPreset(id: "titles.impact", name: "Impact Cut", category: "Titles") { start, duration in
            [animator("Impact") {
                $0.opacity = track(start, duration, [(0, 0), (0.12, 0), (0.17, 100)])
                $0.scale = track(start, duration, [(0, Vec2(150, 114)), (0.18, Vec2(109, 94)),
                                                  (0.33, Vec2(96, 103)), (0.56, Vec2(100, 100))])
                $0.rotation = track(start, duration, [(0, -5), (0.18, 2), (0.34, -0.65), (0.56, 0)])
                $0.directionalBlur = track(start, duration, [(0, 26), (0.17, 14), (0.33, 0)])
                $0.directionalBlurAngle = Animated(15)
            }]
        },
        TextPreset(id: "titles.quote", name: "Quote Reveal", category: "Titles") { start, duration in
            var words = TextSelector()
            words.basedOn = .words
            words.shape = .rampUp
            words.easeHigh = 78
            words.start = track(start, duration, [(0, -36), (0.92, 100)])
            words.end = track(start, duration, [(0, 0), (0.92, 136)])
            return [animator("Word Reveal", selector: words) {
                $0.opacity = Animated(0)
                $0.position = Animated(Vec2(-24, 9))
                $0.skew = Animated(-10)
            }]
        },
        TextPreset(id: "titles.edgeTurn", name: "Edge Turn", category: "Titles") { start, duration in
            var letters = TextSelector()
            letters.basedOn = .charactersExcludingSpaces
            letters.shape = .rampUp
            letters.easeHigh = 56
            letters.start = track(start, duration, [(0, -42), (0.86, 100)])
            letters.end = track(start, duration, [(0, 0), (0.86, 142)])
            return [animator("Turn in Depth", selector: letters) {
                $0.positionZ = Animated(105)
                $0.rotationY = Animated(-88)
                $0.opacity = Animated(0)
            }, animator("Depth Settle") {
                $0.rotationY = track(start, duration, [(0.55, 0), (0.79, 10), (0.94, -2), (1, 0)])
                $0.positionZ = track(start, duration, [(0.55, 0), (0.79, -12), (1, 0)])
            }]
        }
    ]

    static let looks: [TextLookPreset] = [
        TextLookPreset(id: "look.titles.ink", name: "Ink Stamp", category: "Manga/AMV",
                       style: TextStyleStack(
                        fills: [TextFillLayer(colors: [RGBA(hex: 0xF4E8CD)])],
                        strokes: [TextStrokeLayer(color: RGBA(hex: 0x17141B), width: 3.5)],
                        shadows: [TextShadowLayer(color: RGBA(hex: 0x5C2530), distance: 7, blur: 1)])),
        TextLookPreset(id: "look.titles.paper", name: "Paper Caption", category: "Cinematic",
                       style: TextStyleStack(
                        fills: [TextFillLayer(kind: .linear, colors: [RGBA(hex: 0xFFF8E7), RGBA(hex: 0xD3BFA2)])],
                        shadows: [TextShadowLayer(color: RGBA(hex: 0x141522), distance: 4, blur: 8)])),
        TextLookPreset(id: "look.titles.enamel", name: "Black Enamel", category: "3D", text3D: enamel)
    ]

    private static var enamel: Text3DOptions {
        let face = Text3DMaterial(color: RGBA(hex: 0x435168), metalness: 0.28, roughness: 0.28, clearcoat: 0.75)
        var material = Text3DOptions(material: face, extrusion: 24, bevelSize: 2.4, bevelSegments: 2, bevelProfile: .angle)
        material.bevel = Text3DMaterial(color: RGBA(hex: 0x9BB4C4), metalness: 0.62, roughness: 0.3)
        material.side = Text3DMaterial(color: RGBA(hex: 0x202332), metalness: 0.15, roughness: 0.42)
        material.environmentRotation = Animated(28)
        return material
    }

    private static func animator(_ name: String, selector: TextSelector = TextSelector(),
                                 _ change: (inout TextAnimatorProperties) -> Void) -> TextAnimator {
        var animator = TextAnimator(name: name)
        animator.selector = selector
        change(&animator.properties)
        return animator
    }

    private static func track<Value: Interpolatable>(_ start: Double, _ duration: Double,
                                                      _ keys: [(Double, Value)]) -> Animated<Value> {
        var track = Animated(keys[0].1)
        for (fraction, value) in keys {
            track.insertKeyframe(Keyframe(time: start + duration * fraction, value: value, interpolation: .bezier))
        }
        return track
    }
}
