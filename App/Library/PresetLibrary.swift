import Foundation
import SwiftUI

/// Built-in presets. Every preset is made of real keyframes + real effects, so it stays fully editable after you apply it.
struct LayerPreset: Identifiable {
    enum Kind: String, CaseIterable {
        case transitionIn = "In", transitionOut = "Out", shake = "Shakes", glow = "Glow & Light", loop = "Loops", look = "Looks & CC", velocity = "Velocity"
    }
    let id: String
    let name: String
    let kind: Kind
    let symbol: String
    /// Applies to `layer` (comp settings available), `t` = time anchor (in point, out point or playhead).
    let apply: (inout Layer, Project, Double) -> Void
}

enum PresetLibrary {
    private static func key<V: Interpolatable>(_ a: inout Animated<V>, _ t: Double, _ v: V, _ interp: Interpolation = .bezier,
                                                 out: EaseHandle = .easyOut, into: EaseHandle = .easyIn) {
        a.insertKeyframe(Keyframe(time: t, value: v, interpolation: interp, easeOut: out, easeIn: into))
    }

    private static func effect(_ def: EffectDefinition, _ layer: inout Layer, _ params: [String: ParamValue] = [:]) -> Int {
        var e = def.makeInstance()
        for (k, v) in params { e.params[k] = v }
        layer.effects.append(e)
        return layer.effects.count - 1
    }

    private static func keyEffect(_ layer: inout Layer, _ idx: Int, _ param: String, _ pairs: [(Double, Double)], _ interp: Interpolation = .bezier) {
        guard case .number(var a) = layer.effects[idx].params[param] else { return }
        for (t, v) in pairs { a.insertKeyframe(Keyframe(time: t, value: v, interpolation: interp)) }
        layer.effects[idx].params[param] = .number(a)
    }

    static let all: [LayerPreset] = [
        // MARK: Transitions in (start at the layer's in point)
        .init(id: "zoomBlurIn", name: "Zoom Blur In", kind: .transitionIn, symbol: "plus.magnifyingglass") { l, _, t in
            let s = l.transform.scale.value(at: t)
            key(&l.transform.scale, t, s * 1.6, .bezier, out: EaseHandle(x: 0.1, y: 0.9)); key(&l.transform.scale, t + 0.35, s)
            let i = effect(EffectRegistry.radialBlur, &l); keyEffect(&l, i, "amount", [(t, 60), (t + 0.35, 0)])
        },
        .init(id: "whipIn", name: "Whip Pan In", kind: .transitionIn, symbol: "arrow.right.to.line") { l, p, t in
            let pos = l.transform.position.value(at: t)
            key(&l.transform.position, t, pos + Vec2(Double(p.width) * 0.8, 0), .bezier, out: EaseHandle(x: 0.05, y: 0.95)); key(&l.transform.position, t + 0.3, pos)
            let i = effect(EffectRegistry.directionalBlur, &l, ["direction": .number(Animated(90))]); keyEffect(&l, i, "length", [(t, 220), (t + 0.3, 0)])
        },
        .init(id: "spinIn", name: "Spin In", kind: .transitionIn, symbol: "arrow.clockwise") { l, _, t in
            let r = l.transform.rotation.value(at: t), s = l.transform.scale.value(at: t)
            key(&l.transform.rotation, t, r - 180); key(&l.transform.rotation, t + 0.45, r)
            key(&l.transform.scale, t, s * 0.2); key(&l.transform.scale, t + 0.45, s)
            let i = effect(EffectRegistry.radialBlur, &l, ["type": .choice(0)]); keyEffect(&l, i, "amount", [(t, 40), (t + 0.45, 0)])
        },
        .init(id: "glitchIn", name: "Glitch In", kind: .transitionIn, symbol: "bolt.horizontal") { l, _, t in
            let i = effect(EffectRegistry.glitch, &l); keyEffect(&l, i, "amount", [(t, 100), (t + 0.4, 0)], .linear)
            keyEffect(&l, i, "rgb", [(t, 25), (t + 0.4, 0)], .linear)
            key(&l.transform.opacity, t, 0, .hold); key(&l.transform.opacity, t + 0.04, 100, .hold)
        },
        .init(id: "flashIn", name: "Flash In", kind: .transitionIn, symbol: "sun.max.fill") { l, _, t in
            let i = effect(EffectRegistry.exposure, &l); keyEffect(&l, i, "exposure", [(t, 4), (t + 0.25, 0)])
        },
        .init(id: "fadeUpIn", name: "Fade Up", kind: .transitionIn, symbol: "arrow.up.circle") { l, _, t in
            let pos = l.transform.position.value(at: t)
            key(&l.transform.position, t, pos + Vec2(0, 120)); key(&l.transform.position, t + 0.5, pos)
            key(&l.transform.opacity, t, 0); key(&l.transform.opacity, t + 0.5, 100)
        },
        .init(id: "bounceIn", name: "Bounce In", kind: .transitionIn, symbol: "arrow.down.to.line") { l, _, t in
            let s = l.transform.scale.value(at: t)
            key(&l.transform.scale, t, s * 0); key(&l.transform.scale, t + 0.25, s * 1.18); key(&l.transform.scale, t + 0.4, s * 0.94); key(&l.transform.scale, t + 0.55, s)
        },
        .init(id: "warpIn", name: "Lens Warp In", kind: .transitionIn, symbol: "circle.dashed") { l, _, t in
            let i = effect(EffectRegistry.opticsCompensation, &l); keyEffect(&l, i, "fov", [(t, 150), (t + 0.4, 0)])
            let s = l.transform.scale.value(at: t); key(&l.transform.scale, t, s * 1.3); key(&l.transform.scale, t + 0.4, s)
        },
        // MARK: Transitions out (end at the layer's out point)
        .init(id: "zoomBlurOut", name: "Zoom Blur Out", kind: .transitionOut, symbol: "minus.magnifyingglass") { l, _, t in
            let s = l.transform.scale.value(at: t - 0.35)
            key(&l.transform.scale, t - 0.35, s); key(&l.transform.scale, t, s * 1.6, .bezier, into: EaseHandle(x: 0.9, y: 0.1))
            let i = effect(EffectRegistry.radialBlur, &l); keyEffect(&l, i, "amount", [(t - 0.35, 0), (t, 60)])
        },
        .init(id: "whipOut", name: "Whip Pan Out", kind: .transitionOut, symbol: "arrow.left.to.line") { l, p, t in
            let pos = l.transform.position.value(at: t - 0.3)
            key(&l.transform.position, t - 0.3, pos); key(&l.transform.position, t, pos - Vec2(Double(p.width) * 0.8, 0), .bezier, into: EaseHandle(x: 0.95, y: 0.05))
            let i = effect(EffectRegistry.directionalBlur, &l, ["direction": .number(Animated(90))]); keyEffect(&l, i, "length", [(t - 0.3, 0), (t, 220)])
        },
        .init(id: "fadeOut", name: "Fade Out", kind: .transitionOut, symbol: "circle.lefthalf.filled") { l, _, t in
            key(&l.transform.opacity, t - 0.5, l.transform.opacity.value(at: t - 0.5)); key(&l.transform.opacity, t, 0)
        },
        // MARK: Shakes (at the playhead)
        .init(id: "shakeImpact", name: "Impact Shake", kind: .shake, symbol: "waveform.path") { l, _, t in
            let i = effect(EffectRegistry.shake, &l, ["frequency": .number(Animated(14)), "rotation": .number(Animated(4)), "zoom": .number(Animated(6))])
            keyEffect(&l, i, "amplitude", [(t, 70), (t + 0.5, 0)])
        },
        .init(id: "shakeSmooth", name: "Smooth Handheld", kind: .shake, symbol: "hand.raised") { l, _, _ in
            _ = effect(EffectRegistry.shake, &l, ["frequency": .number(Animated(1.5)), "amplitude": .number(Animated(18)), "rotation": .number(Animated(1)), "octaves": .number(Animated(3))])
        },
        .init(id: "shakeTwitch", name: "Twitchy Shake", kind: .shake, symbol: "bolt") { l, _, _ in
            _ = effect(EffectRegistry.shake, &l, ["frequency": .number(Animated(24)), "amplitude": .number(Animated(25)), "rotation": .number(Animated(3)), "octaves": .number(Animated(1))])
        },
        .init(id: "shakeEarthquake", name: "Earthquake", kind: .shake, symbol: "waveform") { l, _, _ in
            _ = effect(EffectRegistry.shake, &l, ["frequency": .number(Animated(9)), "amplitude": .number(Animated(45)), "zoom": .number(Animated(4)), "octaves": .number(Animated(3))])
            _ = effect(EffectRegistry.motionTile, &l, ["mirror": .toggle(true), "tileW": .number(Animated(100)), "tileH": .number(Animated(100))])
        },
        // MARK: Looks / CC
        .init(id: "animeCC", name: "Anime CC", kind: .look, symbol: "sparkles") { l, _, _ in
            _ = effect(EffectRegistry.looks, &l, ["contrast": .number(Animated(25)), "sat": .number(Animated(30)), "vib": .number(Animated(35)), "temp": .number(Animated(-10))])
            _ = effect(EffectRegistry.glow, &l, ["threshold": .number(Animated(70)), "radius": .number(Animated(25)), "intensity": .number(Animated(0.6))])
        },
        .init(id: "tealOrange", name: "Teal & Orange", kind: .look, symbol: "circle.lefthalf.filled.righthalf.striped.horizontal") { l, _, _ in
            _ = effect(EffectRegistry.looks, &l, ["temp": .number(Animated(30)), "tint": .number(Animated(-15)), "contrast": .number(Animated(20)), "shad": .number(Animated(-20))])
            _ = effect(EffectRegistry.curves, &l, ["channel": .choice(3), "shadows": .number(Animated(33)), "highs": .number(Animated(70))])
        },
        .init(id: "vintage", name: "Vintage Film", kind: .look, symbol: "film") { l, _, _ in
            _ = effect(EffectRegistry.looks, &l, ["fade": .number(Animated(45)), "sat": .number(Animated(-25)), "temp": .number(Animated(25))])
            _ = effect(EffectRegistry.grain, &l, ["amount": .number(Animated(12))])
            _ = effect(EffectRegistry.vignette, &l)
        },
        .init(id: "neon", name: "Neon Night", kind: .look, symbol: "lightbulb.max") { l, _, _ in
            _ = effect(EffectRegistry.looks, &l, ["contrast": .number(Animated(35)), "sat": .number(Animated(40)), "temp": .number(Animated(-40)), "tint": .number(Animated(30))])
            _ = effect(EffectRegistry.deepGlow, &l, ["radius": .number(Animated(80)), "exposure": .number(Animated(0.5))])
        },
        .init(id: "mangaLook", name: "Manga Panel", kind: .look, symbol: "book") { l, _, _ in
            _ = effect(EffectRegistry.mangaFX, &l)
        },
        .init(id: "vhsLook", name: "VHS Tape", kind: .look, symbol: "videoprojector") { l, _, _ in
            _ = effect(EffectRegistry.vhs, &l); _ = effect(EffectRegistry.crt, &l, ["strength": .number(Animated(35))])
        },
        .init(id: "bw", name: "Black & White Punch", kind: .look, symbol: "circle.righthalf.filled") { l, _, _ in
            _ = effect(EffectRegistry.hueSaturation, &l, ["saturation": .number(Animated(-100))])
            _ = effect(EffectRegistry.curves, &l, ["shadows": .number(Animated(15)), "highs": .number(Animated(85))])
        },
        // MARK: More transitions (community favourites)
        .init(id: "swipe3DIn", name: "3D Swipe In", kind: .transitionIn, symbol: "rotate.3d") { l, _, t in
            l.is3D = true
            key(&l.transform.rotationY, t, -90, .bezier, out: EaseHandle(x: 0.1, y: 0.9)); key(&l.transform.rotationY, t + 0.45, 0)
            let i = effect(EffectRegistry.directionalBlur, &l, ["direction": .number(Animated(90))]); keyEffect(&l, i, "length", [(t, 80), (t + 0.45, 0)])
        },
        .init(id: "flipIn", name: "3D Flip In", kind: .transitionIn, symbol: "arrow.triangle.2.circlepath") { l, _, t in
            l.is3D = true
            key(&l.transform.rotationX, t, 90, .bezier, out: EaseHandle(x: 0.15, y: 0.9)); key(&l.transform.rotationX, t + 0.5, 0)
            key(&l.transform.opacity, t, 0); key(&l.transform.opacity, t + 0.15, 100)
        },
        .init(id: "chromaZoomIn", name: "Chromatic Zoom In", kind: .transitionIn, symbol: "camera.aperture") { l, _, t in
            let s = l.transform.scale.value(at: t)
            key(&l.transform.scale, t, s * 1.8, .bezier, out: EaseHandle(x: 0.05, y: 0.95)); key(&l.transform.scale, t + 0.4, s)
            let i = effect(EffectRegistry.chromaticZoom, &l); keyEffect(&l, i, "amount", [(t, 80), (t + 0.4, 0)])
        },
        .init(id: "slideBounceIn", name: "Slide Bounce", kind: .transitionIn, symbol: "arrow.up.to.line") { l, p, t in
            let pos = l.transform.position.value(at: t)
            key(&l.transform.position, t, pos + Vec2(0, Double(p.height) * 0.6), .bezier, out: EaseHandle(x: 0.2, y: 1))
            key(&l.transform.position, t + 0.35, pos - Vec2(0, 30)); key(&l.transform.position, t + 0.5, pos)
        },
        .init(id: "flickerIn", name: "Flicker In", kind: .transitionIn, symbol: "lightbulb.led") { l, _, t in
            for (k, v) in [(0.0, 0.0), (0.06, 100), (0.1, 0), (0.16, 100), (0.22, 20), (0.3, 100)] {
                key(&l.transform.opacity, t + k, v, .hold)
            }
        },
        .init(id: "blurIn", name: "Blur Reveal", kind: .transitionIn, symbol: "aqi.medium") { l, _, t in
            let i = effect(EffectRegistry.gaussianBlur, &l); keyEffect(&l, i, "blurriness", [(t, 60), (t + 0.5, 0)])
            key(&l.transform.opacity, t, 0); key(&l.transform.opacity, t + 0.3, 100)
        },
        .init(id: "swipe3DOut", name: "3D Swipe Out", kind: .transitionOut, symbol: "rotate.3d") { l, _, t in
            l.is3D = true
            key(&l.transform.rotationY, t - 0.45, 0, .bezier, into: EaseHandle(x: 0.9, y: 0.1)); key(&l.transform.rotationY, t, 90)
        },
        .init(id: "spinOut", name: "Spin Out", kind: .transitionOut, symbol: "arrow.counterclockwise") { l, _, t in
            let r = l.transform.rotation.value(at: t - 0.45), s = l.transform.scale.value(at: t - 0.45)
            key(&l.transform.rotation, t - 0.45, r); key(&l.transform.rotation, t, r + 180)
            key(&l.transform.scale, t - 0.45, s); key(&l.transform.scale, t, s * 0.1)
        },
        .init(id: "glitchOut", name: "Glitch Out", kind: .transitionOut, symbol: "bolt.horizontal.fill") { l, _, t in
            let i = effect(EffectRegistry.glitch, &l); keyEffect(&l, i, "amount", [(t - 0.35, 0), (t, 100)], .linear)
            key(&l.transform.opacity, t - 0.04, 100, .hold); key(&l.transform.opacity, t, 0, .hold)
        },

        // MARK: Glow & light
        .init(id: "outlineGlowP", name: "Character Glow", kind: .glow, symbol: "person.fill.viewfinder") { l, _, _ in
            _ = effect(EffectRegistry.outlineGlow, &l)
        },
        .init(id: "auraP", name: "Power Aura", kind: .glow, symbol: "flame.fill") { l, _, _ in
            _ = effect(EffectRegistry.energyAura, &l)
            _ = effect(EffectRegistry.shake, &l, ["amplitude": .number(Animated(4)), "frequency": .number(Animated(14))])
        },
        .init(id: "neonOutlineP", name: "Neon Outline", kind: .glow, symbol: "scribble.variable") { l, _, _ in
            _ = effect(EffectRegistry.neonStroke, &l, ["only": .toggle(false)])
            _ = effect(EffectRegistry.flicker, &l, ["amount": .number(Animated(0.15))])
        },
        .init(id: "rimP", name: "Rim Light", kind: .glow, symbol: "sun.max") { l, _, _ in
            _ = effect(EffectRegistry.rimLight, &l)
        },
        .init(id: "glowPulseP", name: "Glow Pulse", kind: .glow, symbol: "light.max") { l, _, t in
            let i = effect(EffectRegistry.deepGlow, &l)
            keyEffect(&l, i, "exposure", [(t, 0.2), (t + 0.3, 1.2), (t + 0.6, 0.2)])
        },
        .init(id: "godRaysP", name: "God Rays", kind: .glow, symbol: "sun.haze.fill") { l, _, _ in
            _ = effect(EffectRegistry.godRays, &l)
        },
        .init(id: "leakP", name: "Light Leak", kind: .glow, symbol: "flare") { l, _, _ in
            _ = effect(EffectRegistry.lightLeak, &l)
        },
        .init(id: "dreamyP", name: "Dreamy Haze", kind: .glow, symbol: "cloud.fill") { l, _, _ in
            _ = effect(EffectRegistry.glow, &l, ["threshold": .number(Animated(45)), "radius": .number(Animated(40)), "intensity": .number(Animated(0.8))])
            _ = effect(EffectRegistry.looks, &l, ["fade": .number(Animated(20)), "temp": .number(Animated(15))])
        },

        // MARK: Loops (no keyframes needed)
        .init(id: "swingLoop", name: "Swing", kind: .loop, symbol: "metronome") { l, _, _ in _ = effect(EffectRegistry.swing, &l) },
        .init(id: "floatLoop", name: "Float", kind: .loop, symbol: "cloud") { l, _, _ in
            _ = effect(EffectRegistry.oscillate, &l, ["distance": .number(Animated(18)), "direction": .number(Animated(90)), "frequency": .number(Animated(0.5))])
        },
        .init(id: "pulseLoop", name: "Beat Pulse", kind: .loop, symbol: "heart.fill") { l, _, _ in _ = effect(EffectRegistry.pulse, &l) },
        .init(id: "spinLoop", name: "Spin", kind: .loop, symbol: "arrow.clockwise.circle") { l, _, _ in _ = effect(EffectRegistry.spin, &l) },
        .init(id: "bounceLoop", name: "Bounce", kind: .loop, symbol: "figure.jumprope") { l, _, _ in _ = effect(EffectRegistry.bounce, &l) },
        .init(id: "jitterLoop", name: "Stop Motion", kind: .loop, symbol: "film.stack") { l, _, _ in _ = effect(EffectRegistry.jitter, &l) },
        .init(id: "rainbowLoop", name: "Rainbow", kind: .loop, symbol: "rainbow") { l, _, _ in _ = effect(EffectRegistry.hueCycle, &l) },

        // MARK: Velocity (speed-ramp style motion)
        .init(id: "velocityPunch", name: "Velocity Punch", kind: .velocity, symbol: "hare.fill") { l, _, t in
            let s = l.transform.scale.value(at: t)
            // Hits hard on the beat, then eases back.
            key(&l.transform.scale, t, s * 1.3, .bezier, out: EaseHandle(x: 0.05, y: 0.95)); key(&l.transform.scale, t + 0.5, s)
            let i = effect(EffectRegistry.chromaticZoom, &l); keyEffect(&l, i, "amount", [(t, 50), (t + 0.5, 0)])
        },
        .init(id: "zoomShake", name: "Zoom Shake", kind: .velocity, symbol: "plus.magnifyingglass") { l, _, t in
            let s = l.transform.scale.value(at: t)
            key(&l.transform.scale, t, s * 1.4, .bezier, out: EaseHandle(x: 0.05, y: 0.95)); key(&l.transform.scale, t + 0.3, s)
            let i = effect(EffectRegistry.shake, &l); keyEffect(&l, i, "amplitude", [(t, 60), (t + 0.4, 0)])
        },
        .init(id: "whipSpin", name: "Whip Spin", kind: .velocity, symbol: "tornado") { l, _, t in
            let r = l.transform.rotation.value(at: t)
            key(&l.transform.rotation, t, r - 360, .bezier, out: EaseHandle(x: 0.05, y: 0.95)); key(&l.transform.rotation, t + 0.4, r)
            let i = effect(EffectRegistry.radialBlur, &l, ["type": .choice(0)]); keyEffect(&l, i, "amount", [(t, 50), (t + 0.4, 0)])
        },
        .init(id: "impactFlash", name: "Impact Flash", kind: .velocity, symbol: "burst.fill") { l, _, t in
            let i = effect(EffectRegistry.exposure, &l); keyEffect(&l, i, "exposure", [(t, 3), (t + 0.12, 0)])
            let j = effect(EffectRegistry.shake, &l); keyEffect(&l, j, "amplitude", [(t, 40), (t + 0.3, 0)])
        },

        // MARK: More looks
        .init(id: "oldFilmLook", name: "Old Film", kind: .look, symbol: "film.fill") { l, _, _ in _ = effect(EffectRegistry.oldFilm, &l) },
        .init(id: "cinemaLook", name: "Cinematic", kind: .look, symbol: "rectangle.ratio.16.to.9") { l, _, _ in
            _ = effect(EffectRegistry.looks, &l, ["contrast": .number(Animated(20)), "temp": .number(Animated(15)), "shad": .number(Animated(-15))])
            _ = effect(EffectRegistry.halation, &l, ["intensity": .number(Animated(0.6))])
            _ = effect(EffectRegistry.cinematicBars, &l)
        },
        .init(id: "duotoneLook", name: "Duotone", kind: .look, symbol: "circle.lefthalf.striped.horizontal") { l, _, _ in
            _ = effect(EffectRegistry.gradientMap, &l)
        },
        .init(id: "sketchLook", name: "Anime Sketch", kind: .look, symbol: "pencil.and.scribble") { l, _, _ in
            _ = effect(EffectRegistry.inkSketch, &l, ["paper": .number(Animated(0.6))])
        },
        .init(id: "retroLook", name: "8-Bit", kind: .look, symbol: "gamecontroller.fill") { l, _, _ in
            _ = effect(EffectRegistry.retroDither, &l, ["palette": .number(Animated(1))])
        },
        .init(id: "bokehLook", name: "Dreamy Bokeh", kind: .look, symbol: "circle.hexagongrid.fill") { l, _, _ in
            _ = effect(EffectRegistry.lensBlur, &l)
        },
    ]
}

extension EditorState {
    func applyPreset(_ p: LayerPreset) {
        guard let i = selectedIndex else { return }
        let l = project.layers[i]
        let t: Double
        switch p.kind {
        case .transitionIn: t = l.inPoint
        case .transitionOut: t = l.outPoint
        default: t = currentTime
        }
        mutate("Preset \(p.name)") { proj in
            var layer = proj.layers[i]
            p.apply(&layer, proj, t)
            proj.layers[i] = layer
        }
    }
}

struct PresetsPanel: View {
    @ObservedObject var state: EditorState
    @State private var kind: LayerPreset.Kind = .transitionIn

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: "Presets", showKeyNav: false)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LayerPreset.Kind.allCases, id: \.self) { k in
                        Button { kind = k } label: {
                            Text(k.rawValue).font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Capsule().fill(kind == k ? Theme.accent : Theme.surface))
                                .foregroundStyle(kind == k ? Color.white : Theme.text)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 6)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(PresetLibrary.all.filter { $0.kind == kind }) { p in
                        ToolTile(icon: p.symbol, title: p.name) { state.applyPreset(p) }
                    }
                }
                .padding(.horizontal, 12)
                Text("Presets add real keyframes and effects — open Effects or the timeline to tweak them.")
                    .font(.caption).foregroundStyle(Theme.textDim).padding(10)
            }
        }
    }
}
