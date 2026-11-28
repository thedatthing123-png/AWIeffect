import Foundation
import UIKit

/// Imports Alight Motion project exports (.xml): scene settings, layers with timing, transforms, keyframes with
/// AM bezier easing, and AM effects mapped onto this app's equivalents (shake, oscillate, swing, pulsate, spin,
/// jitter, tile, ripple, pinch/bulge, blurs, exposure, hue, motion blur…). AM-internal media isn't inside the XML,
/// so media layers come in as placeholders to relink with Replace Media.
enum AMImporter {
    // MARK: Tiny XML tree

    final class Node {
        let name: String
        let attrs: [String: String]
        var children: [Node] = []
        var text = ""
        init(_ name: String, _ attrs: [String: String]) { self.name = name; self.attrs = attrs }
        func child(_ n: String) -> Node? { children.first { $0.name == n } }
        func all(_ n: String) -> [Node] { children.filter { $0.name == n } }
        subscript(_ k: String) -> String? { attrs[k] }
    }

    private final class TreeBuilder: NSObject, XMLParserDelegate {
        var stack: [Node] = [Node("#root", [:])]
        func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
            let n = Node(name, attributes)
            stack.last?.children.append(n)
            stack.append(n)
        }
        func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { _ = stack.popLast() }
        func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    }

    static func parse(_ data: Data) -> Node? {
        let p = XMLParser(data: data)
        let b = TreeBuilder()
        p.shouldResolveExternalEntities = false
        p.delegate = b
        guard p.parse() else { return nil }
        return b.stack.first?.children.first
    }

    static func isAMProject(_ data: Data) -> Bool {
        let head = String(decoding: data.prefix(600), as: UTF8.self)
        return head.contains("<scene") || head.contains("Alight Motion")
    }

    // MARK: Values

    static func nums(_ s: String?) -> [Double] { (s ?? "").split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
    static func color(_ s: String?) -> RGBA? {
        guard var h = s?.trimmingCharacters(in: .whitespaces), h.hasPrefix("#") else { return nil }
        h.removeFirst()
        guard let v = UInt64(h, radix: 16) else { return nil }
        if h.count == 8 {   // AM writes #AARRGGBB
            return RGBA(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255, Double((v >> 24) & 0xFF) / 255)
        }
        return RGBA(Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }

    /// Keyframes / static value of an AM property node. AM key times are 0…1 across the layer's duration.
    static func animated<V: Interpolatable>(_ node: Node?, inPoint: Double, length: Double, _ convert: ([Double]) -> V?) -> Animated<V>? {
        animatedProperty(node, inPoint: inPoint, length: length) { convert(nums($0)) }
    }

    private static func animatedProperty<V: Interpolatable>(_ node: Node?, inPoint: Double, length: Double,
                                                               _ convert: (String?) -> V?) -> Animated<V>? {
        guard let node else { return nil }
        let kfs = node.all("kf")
        if kfs.isEmpty {
            guard let v = convert(node["value"]) else { return nil }
            return Animated(v)
        }
        let parsed: [(t: Double, v: V, e: String?)] = kfs.compactMap { k in
            guard let tt = Double(k["t"] ?? ""), let v = convert(k["v"]) else { return nil }
            return (inPoint + tt * length, v, k["e"])
        }.sorted { $0.t < $1.t }
        guard let first = parsed.first else { return nil }
        var a = Animated(first.v)
        var keys: [Keyframe<V>] = parsed.map { Keyframe(time: $0.t, value: $0.v, interpolation: .linear) }
        // AM puts the easing of a segment on the key it arrives at: "cubicBezier x1 y1 x2 y2".
        for i in parsed.indices where i > 0 {
            guard let e = parsed[i].e else { continue }
            let parts = e.split(separator: " ").map(String.init)
            if parts.first == "cubicBezier", parts.count >= 5, let x1 = Double(parts[1]), let y1 = Double(parts[2]),
               let x2 = Double(parts[3]), let y2 = Double(parts[4]) {
                keys[i - 1].interpolation = .bezier
                keys[i - 1].easeOut = EaseHandle(x: x1, y: y1)
                keys[i].easeIn = EaseHandle(x: x2, y: y2)
            } else if parts.first == "hold" {
                keys[i - 1].interpolation = .hold
            } else if parts.count >= 6, parts[0] == "local", let x1 = Double(parts[2]), let y1 = Double(parts[3]),
                      let x2 = Double(parts[4]), let y2 = Double(parts[5]) {
                // AM "local elastic/cyclic a b c d": keep the curve's handles (springy overshoot is approximated).
                keys[i - 1].interpolation = .bezier
                keys[i - 1].easeOut = EaseHandle(x: min(max(x1, 0), 1), y: y1)
                keys[i].easeIn = EaseHandle(x: min(max(x2, 0), 1), y: y2)
            }
        }
        for k in keys { a.insertKeyframe(k) }
        return a
    }

    static func double(_ node: Node?, _ inPoint: Double, _ length: Double, scale: Double = 1, offset: Double = 0) -> Animated<Double>? {
        animated(node, inPoint: inPoint, length: length) { $0.first.map { $0 * scale + offset } }
    }

    // MARK: Effects

    /// Older source effects that need a host adapter. Register full IDs and
    /// versions so an unrelated effect with the same suffix stays independent.
    private static let legacyEffectIDs: [String: String] = {
        let effects = [
            "ripplelight", "time_slice_mask", "halftonedots", "drawing.progress", "shake", "shake2",
            "oscillate", "oscillate2", "oscillate3", "swing", "pulsate", "spin", "jitter", "randomdisplace",
            "tile", "circularripple", "circularripple2", "pinchbulge", "pinchbulge2", "zoomblur", "zoomblur3",
            "gaussianblur", "blur", "exposure", "hueshift", "motionblur", "motionblur4",
            "softglow", "glow", "edgeglow", "lift", "findedges", "invert", "blink", "blink2", "innerblur",
            "chromakey", "dblur", "rgbsep", "vhs", "threshold", "sharpen", "pixelate", "pixelate2",
            "fractalwarp", "fractalwarp4", "brightcont", "brightcont2", "colorize", "colorhot", "unmult", "fade",
            "textprogress", "textspacing", "texttransform", "solidcolor", "replacecolor", "blackbars",
            "boxblur", "boxblur3", "stretch", "stretch2", "scaleassist"
        ]
        var ids = Dictionary(uniqueKeysWithValues: effects.map { ("com.alightcreative.effects." + $0, $0) })
        ids["com.alightcreative.solidcolor"] = "solidcolor"
        ids["com.alightcreative.replacecolor"] = "replacecolor"
        ids["com.customfx.effects.blackbars"] = "blackbars"
        return ids
    }()

    /// Adds the source effect at its original stack position.
    static func applyEffect(_ fx: Node, to layer: inout Layer, project: inout Project, inPoint: Double, length: Double,
                            report: inout ImportReport) {
        let full = fx["id"] ?? "Unknown Alight Motion effect"
        report.effectUsage[full, default: 0] += 1
        let stackStart = layer.effects.count
        let reportStart = report.entries.count
        let original = capture(fx)
        let legacyID = legacyEffectIDs[full] ?? ""
        let base = legacyID.trimmingCharacters(in: .decimalDigits)
        let reference = ImportedEffectRenderers.xmlFragments[full]
        let enabled = fx["hidden"] != "true" && fx["enabled"] != "false"
        let layerSettings = ["motionblur", "fade", "textprogress", "textspacing", "texttransform", "stretch", "scaleassist"]
        defer {
            // Layer flags and text animators render through their existing editor controls.
            let entry = report.entries.count > reportStart ? report.entries.last : nil
            if layer.effects.count == stackStart {
                let support: ImportedEffect.Support = layerSettings.contains(base) && entry?.status != .missing ? .layerSettings : .unavailable
                var saved = EffectInstance(typeID: "source.unavailable.am." + full, params: [:])
                saved.isEnabled = enabled
                saved.imported = ImportedEffect(format: .alightMotion, matchName: full, displayName: entry?.item ?? full,
                                                support: support, properties: [original])
                layer.effects.append(saved)
            } else {
                for i in stackStart..<layer.effects.count {
                    let typeID = layer.effects[i].typeID
                    let verified = typeID == EffectRegistry.importedOscillate.id || typeID == reference?.id
                    let dedicated = verified || typeID == EffectRegistry.importedRandomDisplacement.id
                    layer.effects[i].typeID = ImportedEffectRenderers.alightMotionTypeID(full, adapterID: dedicated ? nil : typeID)
                    layer.effects[i].isEnabled = enabled
                    layer.effects[i].imported = ImportedEffect(format: .alightMotion, matchName: full,
                        displayName: entry?.item ?? full, support: verified ? .nativeAdapter : .approximation,
                        properties: [original], phaseOrigin: dedicated ? inPoint : nil)
                }
            }
        }
        if !enabled && (layerSettings.contains(base) || base == "swing") {
            report.add(layer.name, full, .approximate, "Disabled in the source. Settings retained without changing the layer.")
            return
        }
        var props: [String: Node] = [:]
        for p in fx.all("property") { if let n = p["name"] { props[n] = p } }
        func num(_ k: String, scale: Double = 1, offset: Double = 0) -> ParamValue? {
            double(props[k], inPoint, length, scale: scale, offset: offset).map { .number($0) }
        }
        func bool(_ k: String) -> Bool? { props[k]?["value"].map { $0 == "true" } }
        func make(_ def: EffectDefinition, _ params: [String: ParamValue?]) {
            var e = def.makeInstance()
            for (k, v) in params { if let v { e.params[k] = v } }
            layer.effects.append(e)
        }
        let name = layer.name
        if let reference, let definition = EffectRegistry.definition(reference.id) {
            var instance = definition.makeInstance()
            for parameter in reference.parameters {
                let control = parameter.definition
                guard let property = props[control.id] else { continue }
                switch control.kind {
                case .number:
                    let scale = parameter.scalarScale == 0 ? 1 : 1 / Double(parameter.scalarScale)
                    if let track = double(property, inPoint, length, scale: scale) { instance.params[control.id] = .number(track) }
                case .angle:
                    if let track = double(property, inPoint, length) { instance.params[control.id] = .number(track) }
                case .point:
                    if let track = animated(property, inPoint: inPoint, length: length, { values -> Vec2? in
                        guard values.count == 2 else { return nil }
                        return Vec2(values[0], values[1])
                    }) { instance.params[control.id] = .point(track) }
                case .color:
                    if let track = animatedProperty(property, inPoint: inPoint, length: length, color) {
                        instance.params[control.id] = .color(track)
                    }
                case .toggle:
                    importDiscrete(property, key: control.id, inPoint: inPoint, length: length, into: &instance,
                                   value: { $0 == 1 ? .toggle(true) : .toggle(false) }) { raw in
                        switch raw.lowercased() {
                        case "true", "1": return 1
                        case "false", "0": return 0
                        default: return nil
                        }
                    }
                case .choice(let options):
                    importDiscrete(property, key: control.id, inPoint: inPoint, length: length, into: &instance,
                                   value: ParamValue.choice) { raw in
                        Int(raw).flatMap { parameter.choiceValues.firstIndex(of: $0) }
                            ?? options.firstIndex { $0.caseInsensitiveCompare(raw) == .orderedSame }
                    }
                }
            }
            layer.effects.append(instance)
            report.add(name, definition.name, .native, "Loaded the bundled shader for this source ID.")
            return
        }
        switch base {
        case "ripplelight":
            make(EffectRegistry.litRipple23, ["strength": num("strength"), "frequency": num("frequency"), "speed": num("speed"),
                "radius": num("radius"), "decay": num("decay"), "light": num("lightIntensity"), "sharpness": num("lightSharpness"),
                "mix": num("blend", scale: 100)])
            // Combine separately animated center coordinates without discarding either key track.
            if let index = layer.effects.indices.last {
                let x = double(props["centerX"], inPoint, length) ?? Animated(0.5)
                let y = double(props["centerY"], inPoint, length) ?? Animated(0.5)
                var center = Animated(Vec2(x.staticValue, y.staticValue))
                let times = Set(x.keyframeTimes + y.keyframeTimes).sorted()
                for t in times { center.insertKeyframe(Keyframe(time: t, value: Vec2(x.value(at: t), y.value(at: t)))) }
                layer.effects[index].params["center"] = .point(center)
            }
            report.add(name, "BCC-style Lit Ripple", .approximate, "Reference controls retained; independent center easing is sampled at source key times.")
        case "time_slice_mask":
            make(EffectRegistry.timeSliceMask23, ["count": num("count"), "smoothness": num("smoothness"), "speed": num("speed"),
                "angle": num("angle"), "feather": num("feather"), "output": .choice(1),
                "reverse": .toggle((Double(props["reverse"]?["value"] ?? "0") ?? 0) >= 0.5)])
            report.add(name, "Time Slice Mask", .approximate, "White mask output; Reverse is implemented rather than ignored.")
        case "halftonedots":
            make(EffectRegistry.halftone, ["version": .choice(2), "amount": num("amount"), "strength": num("strength", scale: 100),
                "angle": num("angle"), "phase": num("phase"),
                "ink": props["color1"]?["value"].flatMap(color).map { .color(Animated($0)) },
                "paper": props["color2"]?["value"].flatMap(color).map { .color(Animated($0)) }])
            report.add(name, "Halftone Dots", .approximate, "AM Dots mode; static colors and numeric keyframes retained.")
        case "drawing.progress":
            guard case .shape = layer.content else {
                report.add(name, "Drawing Progress", .missing, "Requires vector geometry; raster/text outlines are not converted.")
                return
            }
            make(EffectRegistry.drawingProgress23, ["start": num("start"), "end": num("end")])
            report.add(name, "Drawing Progress", .native)
        case "shake":
            make(EffectRegistry.shake, ["amplitude": num("mag"), "frequency": num("freq"), "rotation": .number(Animated(0))])
            report.add(name, "Shake", .approximate, "Source controls saved. Random motion uses a compatibility renderer.")
        case "oscillate" where legacyID == "oscillate3":
            let wave = props["wave"]?["value"]?.lowercased()
            make(EffectRegistry.importedOscillate, ["distance": num("mag"), "frequency": num("freq"), "direction": num("angle"),
                "phase": num("phase"), "wave": .choice(wave == "triangle" || wave == "1" ? 1 : 0)])
            report.add(name, "Oscillate", .native, "Source frequency is cumulative over the layer clock.")
        case "oscillate":
            make(EffectRegistry.oscillate, ["distance": num("mag"), "frequency": num("freq"), "direction": num("angle"), "phase": num("phase", scale: 360)])
            report.add(name, "Oscillate", .approximate, "Legacy Oscillate version.")
        case "swing":
            let a1 = Double(props["a1"]?["value"] ?? "") ?? -30, a2 = Double(props["a2"]?["value"] ?? "") ?? 30
            make(EffectRegistry.swing, ["angle": .number(Animated(abs(a2 - a1) / 2)), "frequency": num("freq"), "phase": num("phase", scale: 180)])
            if abs(a1 + a2) > 0.01 { layer.transform.rotation = Animated(layer.transform.rotation.staticValue + (a1 + a2) / 2) }
            report.add(name, "Swing", .native)
        case "pulsate":
            let mx = Double(props["maxsize"]?["value"] ?? "") ?? 1.1
            make(EffectRegistry.pulse, ["amount": .number(Animated((mx - 1) * 100)), "bpm": num("freq", scale: 60)])
            report.add(name, "Pulsate", .approximate, "Mapped to Pulse (beat-shaped).")
        case "spin":
            make(EffectRegistry.spin, ["speed": num("rpm", scale: 6)])
            report.add(name, "Spin", .native)
        case "randomdisplace":
            make(EffectRegistry.importedRandomDisplacement, ["evolution": num("evolution"), "magnitude": num("mag"), "scatter": num("scatter")])
            report.add(name, "Random Displacement", .approximate, "Uses source evolution, magnitude and scatter with an independent smooth displacement renderer.")
        case "jitter":
            make(EffectRegistry.jitter, ["amount": num("mag"), "rate": num("freq")])
            report.add(name, base == "jitter" ? "Jitter" : "Random Displace", .approximate, "Mapped to Random Jitter.")
        case "tile":
            let s = Double(props["scale"]?["value"] ?? "") ?? 1
            make(EffectRegistry.motionTile, ["tileW": .number(Animated(100 / max(s, 0.01))), "tileH": .number(Animated(100 / max(s, 0.01))),
                                             "mirror": .toggle(bool("mirror") ?? false)])
            if let ang = props["angle"], let rot = double(ang, inPoint, length) {
                // AM rotates the tiled content inside the frame; the closest match is spinning the mirrored layer.
                make(EffectRegistry.spin, ["speed": .number(Animated(0)), "offset": .number(rot)])
            }
            report.add(name, "Tile", .approximate, "Mapped to Motion Tile (mirror edges); content rotation via Spin.")
        case "circularripple":
            make(EffectRegistry.ripple, ["height": num("strength", scale: 400), "width": num("frequency", scale: 2), "speed": num("phase", scale: 0.2)])
            report.add(name, "Circular Ripple", .approximate)
        case "pinchbulge":
            make(EffectRegistry.bulge, ["height": num("strength", scale: -2), "radius": num("radius", scale: Double(min(project.width, project.height)))])
            report.add(name, "Pinch/Bulge", .native)
        case "zoomblur":
            make(EffectRegistry.radialBlur, ["amount": num("strength", scale: 100), "type": .choice(1)])
            report.add(name, "Zoom Blur", .native)
        case "gaussianblur", "blur":
            make(EffectRegistry.gaussianBlur, ["blurriness": num("strength", scale: 100)])
            report.add(name, "Blur", .native)
        case "exposure":
            make(EffectRegistry.exposure, ["exposure": num("exposure", scale: 2), "gamma": num("gamma"), "offset": num("offset")])
            report.add(name, "Exposure", .native)
        case "hueshift":
            make(EffectRegistry.hueSaturation, ["hue": num("hue")])
            report.add(name, "Hue Shift", .native)
        case "motionblur":
            layer.motionBlur = true
            project.motionBlurEnabled = true
            if let t = Double(props["tune"]?["value"] ?? "") { project.shutterAngle = max(project.shutterAngle, 180 * max(t, 0.2)) }
            report.add(name, "Motion Blur", .native, "Layer + scene motion blur switched on.")
        case "softglow", "glow", "edgeglow":
            make(EffectRegistry.glow, ["intensity": num("strength", scale: 8), "radius": .number(Animated(30))])
            report.add(name, "Soft Glow", .approximate, "Mapped to Glow.")
        case "lift":
            make(EffectRegistry.exposure, ["offset": num("fill", scale: 0.5)])
            report.add(name, "Lift", .approximate, "Mapped to Exposure offset.")
        case "findedges":
            make(EffectRegistry.findEdges, ["invert": bool("invert").map { .toggle($0) }])
            report.add(name, "Find Edges", .native)
        case "invert":
            make(EffectRegistry.invert, [:]); report.add(name, "Invert", .native)
        case "blink":
            make(EffectRegistry.flicker, ["frequency": num("freq"), "amount": .number(Animated(1)), "smooth": .number(Animated(0))])
            report.add(name, "Blink", .approximate, "Mapped to Flicker.")
        case "innerblur":
            if let d = EffectRegistry.definition("awi15.innerBlur") { make(d, [:]) } else { make(EffectRegistry.gaussianBlur, ["blurriness": num("strength", scale: 60)]) }
            report.add(name, "Inner Blur", .approximate)
        case "chromakey":
            make(EffectRegistry.chromaKey, ["key": props["keyColor"]?["value"].flatMap(color).map { .color(Animated($0)) },
                                            "tolerance": num("threshold", scale: 100)])
            report.add(name, "Chroma Key", .native)
        case "dblur":
            make(EffectRegistry.directionalBlur, ["length": num("strength", scale: 120), "direction": num("angle")])
            report.add(name, "Directional Blur", .native)
        case "rgbsep":
            make(EffectRegistry.rgbSplit, ["amount": num("strength", scale: 20)]); report.add(name, "RGB Split", .native)
        case "vhs":
            make(EffectRegistry.vhs, [:]); report.add(name, "VHS", .approximate)
        case "threshold":
            make(EffectRegistry.threshold, [:]); report.add(name, "Threshold", .approximate)
        case "sharpen":
            make(EffectRegistry.sharpen, [:]); report.add(name, "Sharpen", .approximate)
        case "pixelate":
            make(EffectRegistry.mosaic, [:]); report.add(name, "Pixelate", .approximate)
        case "fractalwarp":
            make(EffectRegistry.turbulentDisplace, ["amount": num("mag", scale: 150)]); report.add(name, "Fractal Warp", .approximate)
        case "brightcont":
            make(EffectRegistry.brightnessContrast, ["brightness": num("brightness", scale: 100), "contrast": num("contrast", scale: 50)])
            report.add(name, "Brightness & Contrast", .native)
        case "colorize", "colorhot":
            make(EffectRegistry.tint, [:]); report.add(name, base, .approximate, "Mapped to Tint.")
        case "unmult":
            make(EffectRegistry.lumaKey, [:]); report.add(name, "Unmult", .approximate)
        case "fade":
            let fi = Double(props["inTime"]?["value"] ?? "") ?? 0.5, fo = Double(props["outTime"]?["value"] ?? "") ?? 0.5
            var o = layer.transform.opacity
            o.insertKeyframe(Keyframe(time: inPoint, value: 0, interpolation: .linear))
            o.insertKeyframe(Keyframe(time: inPoint + min(fi, length / 2), value: 100, interpolation: .linear))
            o.insertKeyframe(Keyframe(time: inPoint + length - min(fo, length / 2), value: 100, interpolation: .linear))
            o.insertKeyframe(Keyframe(time: inPoint + length, value: 0, interpolation: .linear))
            layer.transform.opacity = o
            report.add(name, "Fade In/Out", .native)
        case "textprogress":
            // Typewriter: reveal characters by the "end" amount.
            if layer.text != nil, let end = double(props["end"], inPoint, length, scale: 100) {
                var a = TextAnimator(name: "Typewriter")
                a.importedStart = inPoint
                a.selector.start = end
                a.selector.end = Animated(100)
                a.properties.opacity = Animated(0)
                layer.text?.animators.append(a)
                report.add(name, "Text Progress", .native, "Became a typewriter animator.")
            }
        case "textspacing":
            if let ls = double(props["letterspacing"], inPoint, length, scale: 20) { layer.text?.tracking = ls }
            report.add(name, "Text Spacing", .native)
        case "texttransform":
            guard layer.text != nil else {
                report.add(name, "Text Transform", .missing, "Requires a text layer. Source settings were kept.")
                return
            }
            var animator = TextAnimator(name: "Text Transform")
            animator.importedStart = inPoint
            animator.selector.start = double(props["start"], inPoint, length, scale: 100) ?? Animated(0)
            animator.selector.end = double(props["end"], inPoint, length, scale: 100) ?? Animated(100)
            switch (props["basedOn"]?["value"] ?? "").lowercased() {
            case "word", "words": animator.selector.basedOn = .words
            case "line", "lines": animator.selector.basedOn = .lines
            default: break
            }
            animator.properties.position = animated(props["offset"], inPoint: inPoint, length: length) {
                guard $0.count == 2 else { return nil }
                return Vec2($0[0], $0[1])
            }
            animator.properties.rotation = double(props["angle"], inPoint, length)
            animator.properties.scale = animated(props["stretch"], inPoint: inPoint, length: length) { values in
                values.first.map { Vec2(max(0, 100 * (1 + $0)), 100) }
            }
            guard animator.properties.position != nil || animator.properties.rotation != nil || animator.properties.scale != nil else {
                report.add(name, "Text Transform", .missing, "This version has no transform controls AWIeffect can render. Source settings were kept.")
                return
            }
            layer.text?.animators.append(animator)
            report.add(name, "Text Transform", .approximate, "Range, offset, rotation and stretch use an editable text animator. Source overlap and range-easing settings are retained.")
        case "solidcolor":
            make(EffectRegistry.fill, ["color": props["color"]?["value"].flatMap(color).map { .color(Animated($0)) },
                                       "opacity": num("alpha", scale: 100)])
            report.add(name, "Solid Color", .native)
        case "replacecolor":
            if let d = EffectRegistry.definition("ae.changeToColor") { make(d, [:]) }
            report.add(name, "Replace Color", .approximate)
        case "blackbars":
            make(EffectRegistry.cinematicBars, [:]); report.add(name, "Black Bars", .native)
        case "boxblur":
            make(EffectRegistry.gaussianBlur, ["blurriness": num("strength", scale: 60)]); report.add(name, "Box Blur", .native)
        case "stretch", "scaleassist":
            let s = Double(props["scale"]?["value"] ?? "") ?? 1
            let sc = layer.transform.scale.staticValue
            layer.transform.scale = Animated(Vec2(sc.x * s, sc.y))
            report.add(name, base == "stretch" ? "Stretch" : "Scale Assist", .approximate, "Applied as a static scale.")
        default:
            report.add(name, full, .missing, "Source parameters retained. A compatible renderer is unavailable.")
        }
    }

    private static func importDiscrete(_ property: Node, key: String, inPoint: Double, length: Double,
                                       into instance: inout EffectInstance, value: (Int) -> ParamValue,
                                       parse: (String) -> Int?) {
        if let raw = property["value"], let decoded = parse(raw) { instance.params[key] = value(decoded) }
        var keys: [EffectStackR4.HoldKey] = []
        for keyframe in property.all("kf") {
            guard let normalized = keyframe["t"].flatMap(Double.init), normalized.isFinite,
                  let raw = keyframe["v"], let decoded = parse(raw) else { continue }
            keys.append(.init(time: inPoint + normalized * length, value: decoded))
        }
        if let encoded = EffectStackR4.encode(keys) {
            var text = instance.text ?? [:]
            text[EffectStackR4.holdPrefix + key] = encoded
            instance.text = text
        }
    }

    private static func capture(_ node: Node) -> ImportedProperty {
        let text = node.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ImportedProperty(name: node.name, attributes: node.attrs.isEmpty ? nil : node.attrs,
                                text: text.isEmpty ? nil : text, children: node.children.map(capture))
    }

    // MARK: Scene

    static func blend(_ s: String?) -> BlendMode {
        switch s ?? "" {
        case "screen", "lighten-add": return .screen
        case "add", "linear-dodge": return .add
        case "multiply": return .multiply
        case "overlay", "soft-overlay": return .overlay
        case "soft-light": return .softLight
        case "hard-light": return .hardLight
        case "color-dodge": return .colorDodge
        case "color-burn": return .colorBurn
        case "linear-burn": return .linearBurn
        case "hue": return .hue
        case "saturation": return .saturation
        case "color": return .color
        case "luminosity": return .luminosity
        case "subtract": return .subtract
        case "divide": return .divide
        case "lighten": return .lighten
        case "darken": return .darken
        case "difference": return .difference
        case "exclude", "exclusion": return .exclusion
        default: return .normal
        }
    }

    /// Builds this app's layers from one AM scene element (recursing into groups as pre-comps).
    static func layers(of scene: Node, project: inout Project, media: [String: Node], report: inout ImportReport,
                       depth: Int = 0) -> [Layer] {
        let w = Double(project.width), h = Double(project.height), fps = project.fps
        var out: [Layer] = []
        var idMap: [String: UUID] = [:]
        var parentOf: [UUID: String] = [:]
        var n = 0
        for node in scene.children where ["shape", "text", "image", "video", "embedScene", "audio", "nullobj", "drawing", "camera"].contains(node.name) {
            n += 1
            let start = (Double(node["startTime"] ?? "") ?? 0) / 1000
            let end = (Double(node["endTime"] ?? "") ?? project.duration * 1000) / 1000
            let length = max(end - start, 1 / fps)
            let tr = node.child("transform")
            let label = node["label"] ?? "\(node.name.capitalized) \(n)"
            var l = project.makeLayer(name: label, content: .solid, size: Vec2(w, h))
            l.isVisible = node["hidden"] != "true"
            l.inPoint = start; l.outPoint = end
            if let loc = animated(tr?.child("location"), inPoint: start, length: length, { v in v.count >= 2 ? Vec2(v[0], v[1]) : nil }) { l.transform.position = loc }
            if let z = animated(tr?.child("location"), inPoint: start, length: length, { v in v.count >= 3 ? v[2] : nil }), (z.isAnimated || z.staticValue != 0) {
                l.transform.positionZ = z; l.is3D = true
            }
            if let sc = animated(tr?.child("scale"), inPoint: start, length: length, { v -> Vec2? in
                v.count >= 2 ? Vec2(v[0] * 100, v[1] * 100) : (v.first.map { Vec2($0 * 100, $0 * 100) })
            }) { l.transform.scale = sc }
            if let r = double(tr?.child("rotation"), start, length) { l.transform.rotation = r }
            if let o = double(tr?.child("opacity"), start, length, scale: 100) { l.transform.opacity = o }
            if let pv = animated(tr?.child("pivot"), inPoint: start, length: length, { v in v.count >= 2 ? Vec2(v[0], v[1]) : nil }) { l.transform.anchor = pv }
            if let fc = node.child("fillColor") {
                if let c = color(fc["value"]) { l.fill = Animated(c) }
                else if !fc.all("kf").isEmpty {
                    // Animated color: keys carry hex values.
                    var a = Animated(color(fc.all("kf").first?["v"]) ?? .white)
                    for k in fc.all("kf") { if let tt = Double(k["t"] ?? ""), let c = color(k["v"]) {
                        a.insertKeyframe(Keyframe(time: start + tt * length, value: c, interpolation: .linear)) } }
                    l.fill = a
                }
            }
            l.blendMode = blend(node["blending"])
            if let size = animated(node.all("property").first { $0["name"] == "size" }, inPoint: start, length: length, { v in
                v.count >= 2 ? Vec2(v[0] * 2, v[1] * 2) : nil }) { l.size = size }

            switch node.name {
            case "camera":
                l.content = .camera
                l.is3D = true
                let zoom = animated(node.child("fov"), inPoint: start, length: length) { values in
                    values.first.flatMap { $0.isFinite ? w / 2 / tan(min(179, max(1, $0)) * .pi / 360) : nil }
                } ?? Animated(w / 2 / tan(.pi / 6))
                var camera = CameraOptions(zoom: zoom, focusDistance: zoom)
                camera.affects2D = true
                if let focus = node.child("focus-blur") {
                    camera.depthOfField = focus["enabled"] == "true"
                    if let distance = double(focus.child("distance"), start, length) { camera.focusDistance = distance }
                }
                l.camera = camera
                report.add(label, "Camera", .native)
            case "nullobj":
                l.isNull = true
                l.size = Animated(Vec2(100, 100))
                l.fill = Animated(RGBA(1, 1, 1, 0))
                report.add(label, "Null", .native)
            case "text":
                l.content = .text
                if node.child("fillColor") == nil { l.fill = Animated(.white) }
                var t = TextData(string: node.child("content")?.text ?? label)
                // AM text "size" is in points before the layer's scale; ×10 matches its on-screen size.
                t.fontSize = (Double(node["size"] ?? "") ?? 12) * 10
                if let width = Double(node["wrapWidth"] ?? ""), width.isFinite, width > 0 { t.boxWidth = width }
                t.fill = l.fill
                t.alignment = node["align"] == "left" ? .left : (node["align"] == "right" ? .right : .center)
                let sourceFont = node["font"] ?? ""
                if !sourceFont.isEmpty {
                    t.importedFontReference = sourceFont
                    let query = URLComponents(string: sourceFont)?.queryItems
                    let fontName = query?.first(where: { $0.name == "name" })?.value ?? sourceFont
                    let weight = query?.first(where: { $0.name == "weight" })?.value
                    let stem = (fontName as NSString).deletingPathExtension
                    let weighted = weight.flatMap { Int($0) }.map {
                        stem.replacingOccurrences(of: " ", with: "") + ($0 >= 700 ? "-Bold" : ($0 >= 500 ? "-Medium" : "-Regular"))
                    }
                    let candidates = [weighted, stem, UIFont.fontNames(forFamilyName: fontName).first].compactMap { $0 }
                    if let face = candidates.lazy.compactMap({ UIFont(name: $0, size: 12)?.fontName }).first {
                        t.fontName = face
                        report.add(label, "Text", .native, "Using installed source font \(face).")
                    } else {
                        t.fontName = "Helvetica"
                        report.add(label, "Text", .approximate, "Source font \(fontName) is unavailable. Install it and select it in Text Studio.")
                    }
                } else {
                    report.add(label, "Text", .native)
                }
                l.text = t
                if let shadow = node.child("shadow"), shadow["enabled"] != "false" {
                    l.effects.append(EffectRegistry.dropShadow.makeInstance())
                }
            case "drawing":
                // Each pen stroke becomes an open path with a stroke.
                var strokes: [Layer] = []
                for (si, st) in node.all("stroke").enumerated() {
                    let pts = (st["points"] ?? "").split(separator: ";").compactMap { tri -> Vec2? in
                        let v = tri.split(separator: ",").compactMap { Double($0) }
                        return v.count >= 2 ? Vec2(v[0], v[1]) : nil
                    }
                    guard pts.count >= 2 else { continue }
                    var sl = l
                    sl.id = UUID()
                    sl.name = "\(label) stroke \(si + 1)"
                    sl.content = .shape(.path)
                    sl.path = Animated(BezierPath.smoothed(pts, closed: false))
                    sl.fill = Animated(RGBA(0, 0, 0, 0))
                    sl.stroke.enabled = true
                    sl.stroke.color = Animated(color(st["color"]) ?? .white)
                    sl.stroke.width = Animated(Double(st["width"] ?? "") ?? 8)
                    strokes.append(sl)
                }
                for fx in node.all("effect") {
                    if fx["id"]?.hasSuffix("drawing.progress") == true {
                        for i in strokes.indices {
                            var pr: [String: Node] = [:]; for p in fx.all("property") { if let k = p["name"] { pr[k] = p } }
                            if let e = double(pr["end"], start, length) { strokes[i].stroke.trimEnd = e }
                            if let b = double(pr["start"], start, length) { strokes[i].stroke.trimStart = b }
                        }
                        report.add(label, "Drawing Progress", .native, "Became Trim Paths.")
                    }
                }
                report.add(label, "Drawing (\(strokes.count) strokes)", .native)
                if let pid = node["parent"] { for s in strokes { parentOf[s.id] = pid } }
                if let first = strokes.first, let nid = node["id"] { idMap[nid] = first.id }
                out += strokes
                continue
            case "embedScene":
                if let inner = node.child("scene"), depth < 6 {
                    let iw = Int(inner["width"] ?? "") ?? project.width, ih = Int(inner["height"] ?? "") ?? project.height
                    var comp = Project.new(name: label, width: iw, height: ih, fps: fps,
                                           duration: max(length, (Double(inner["totalTime"] ?? "") ?? length * 1000) / 1000),
                                           background: RGBA(0, 0, 0, 0))
                    comp.importedFormat = .alightMotion
                    comp.autoLength = false
                    comp.smoothMotion = false
                    comp.layers = layers(of: inner, project: &comp, media: media, report: &report, depth: depth + 1)
                    var all = project.precomps; all.append(comp); all += comp.precomps; project.precomps = all
                    comp.precompList = nil
                    l.content = .precomp(id: comp.id)
                    l.size = Animated(Vec2(Double(iw), Double(ih)))
                    report.add(label, "Group", .native, "Became a pre-comp.")
                }
            case "audio":
                report.add(label, "Audio", .missing, "Re-add your music (AM media isn't inside the XML).")
                continue
            default:
                let sk = node["s"] ?? ""
                if node["fillType"] == "media", let uri = node["fillVideo"] ?? node["fillImage"] {
                    let m = media[uri]
                    let mw = Double(m?["width"] ?? "") ?? w, mh = Double(m?["height"] ?? "") ?? h
                    l.importedFootage = ImportedFootage(name: m?["name"] ?? label, sourceReference: uri)
                    l.fill = Animated(RGBA(0.25, 0.2, 0.35))
                    l.sourceStart = (Double(node["inTime"] ?? "") ?? 0) / 1000
                    if let sp = Double(node["speed"] ?? "") { l.speed = sp }
                    if node.all("property").first(where: { $0["name"] == "size" }) == nil { l.size = Animated(Vec2(mw, mh)) }
                    report.add(label, "Media", .missing, "Media isn't inside AM exports — Replace Media on this layer relinks your clip (timing kept).")
                } else if sk.contains("ellipse") || sk.contains("circle") { l.content = .shape(.ellipse); report.add(label, "Ellipse", .native) }
                else if sk.contains("star") || sk.contains("foil") { l.content = .shape(.star); report.add(label, "Star", .native) }
                else if sk.contains("poly") || sk.contains("triangle") || sk.contains("hex") { l.content = .shape(.polygon); report.add(label, "Polygon", .native) }
                else if sk.contains("rect") || sk.contains("square") { l.content = .shape(.rectangle); report.add(label, "Rectangle", .native) }
                else { report.add(label, node.name, .approximate, "Imported as a solid.") }
            }
            if let g = node.child("gain"), let v = Double(g["value"] ?? "") { l.volume = Animated(v * 100) }
            for fx in node.all("effect") {
                applyEffect(fx, to: &l, project: &project, inPoint: start, length: length, report: &report)
            }
            if let nid = node["id"] { idMap[nid] = l.id }
            if let pid = node["parent"] { parentOf[l.id] = pid }
            out.append(l)
        }
        // Parenting (AM "parent" attribute → this app's parent links; positions are already parent-relative).
        for i in out.indices { if let pid = parentOf[out[i].id], let p = idMap[pid] { out[i].parentID = p } }
        // AM lists bottom layer first; this app lists top first.
        return out.reversed()
    }

    static func load(data: Data, fallbackName: String) throws -> AEPImportResult {
        guard let scene = parse(data), scene.name == "scene" else {
            throw NSError(domain: "AM", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not an Alight Motion project export."])
        }
        let w = Int(scene["width"] ?? "") ?? 1080, h = Int(scene["height"] ?? "") ?? 1920
        let fps = Double(scene["fps"] ?? "") ?? 30
        let duration = max(0.1, (Double(scene["totalTime"] ?? "") ?? 10_000) / 1000)
        var project = Project.new(name: scene["title"] ?? fallbackName, width: w, height: h, fps: fps, duration: duration,
                                  background: color(scene["bgcolor"]) ?? .black)
        var report = ImportReport()
        report.compName = project.name
        var media: [String: Node] = [:]
        for m in scene.all("media") { if let u = m["uri"] { media[u] = m } }
        project.importedFormat = .alightMotion
        project.autoLength = false
        project.smoothMotion = false
        project.layers = layers(of: scene, project: &project, media: media, report: &report)
        project.markers = scene.all("bookmark").compactMap { Double($0["t"] ?? "").map { $0 / 1000 } }
        return AEPImportResult(project: project, report: report)
    }
}
