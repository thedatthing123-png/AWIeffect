import Foundation

/// A parameter value stored on an effect instance. Every numeric kind is keyframeable.
enum ParamValue: Codable, Equatable {
    case number(Animated<Double>)
    case point(Animated<Vec2>)
    case color(Animated<RGBA>)
    case toggle(Bool)
    case choice(Int)

    func number(at t: Double) -> Double {
        switch self {
        case .number(let a):
            let v = a.value(at: t)
            return v.isFinite ? min(max(v, -1e7), 1e7) : 0
        case .toggle(let b): return b ? 1 : 0
        case .choice(let i): return Double(i)
        default: return 0
        }
    }
    func point(at t: Double) -> Vec2 {
        guard case .point(let a) = self else { return .zero }
        let v = a.value(at: t)
        return v.x.isFinite && v.y.isFinite ? v : .zero
    }
    func color(at t: Double) -> RGBA { if case .color(let a) = self { return a.value(at: t) }; return .white }

    var keyframeTimes: [Double] {
        switch self {
        case .number(let a): return a.keyframeTimes
        case .point(let a): return a.keyframeTimes
        case .color(let a): return a.keyframeTimes
        default: return []
        }
    }
}

enum EffectCategory: String, CaseIterable, Identifiable {
    case blur = "Blur", color = "Color & Light", stylize = "Stylize", distort = "Distortion/Warp"
    case generate = "Procedural", motion = "Move/Transform", keying = "Matte/Mask/Key", transition = "Transitions"
    case glitch = "Glitch"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .blur: return "drop.halffull"
        case .color: return "sun.max"
        case .stylize: return "wand.and.stars"
        case .distort: return "water.waves"
        case .generate: return "circle.hexagongrid"
        case .motion: return "move.3d"
        case .keying: return "person.crop.rectangle"
        case .transition: return "square.split.diagonal.2x2"
        case .glitch: return "waveform.path.ecg.rectangle"
        }
    }
}

enum ParamKind: Equatable {
    case number(min: Double, max: Double, step: Double, unit: String)
    case angle
    case point
    case color
    case toggle
    case choice([String])
}

struct ParamDef: Identifiable {
    let id: String
    let name: String
    let kind: ParamKind
    let defaultValue: ParamValue
    /// AE parameter match-name suffix order (for .aep import mapping later).
    var aeIndex: Int? = nil

    static func number(_ id: String, _ name: String, _ def: Double, _ min: Double, _ max: Double, step: Double = 0, unit: String = "", ae: Int? = nil) -> ParamDef {
        ParamDef(id: id, name: name, kind: .number(min: min, max: max, step: step, unit: unit), defaultValue: .number(Animated(def)), aeIndex: ae)
    }
    static func angle(_ id: String, _ name: String, _ def: Double, ae: Int? = nil) -> ParamDef {
        ParamDef(id: id, name: name, kind: .angle, defaultValue: .number(Animated(def)), aeIndex: ae)
    }
    static func point(_ id: String, _ name: String, _ def: Vec2, ae: Int? = nil) -> ParamDef {
        ParamDef(id: id, name: name, kind: .point, defaultValue: .point(Animated(def)), aeIndex: ae)
    }
    static func color(_ id: String, _ name: String, _ def: RGBA, ae: Int? = nil) -> ParamDef {
        ParamDef(id: id, name: name, kind: .color, defaultValue: .color(Animated(def)), aeIndex: ae)
    }
    static func toggle(_ id: String, _ name: String, _ def: Bool, ae: Int? = nil) -> ParamDef {
        ParamDef(id: id, name: name, kind: .toggle, defaultValue: .toggle(def), aeIndex: ae)
    }
    static func choice(_ id: String, _ name: String, _ options: [String], _ def: Int, ae: Int? = nil) -> ParamDef {
        ParamDef(id: id, name: name, kind: .choice(options), defaultValue: .choice(def), aeIndex: ae)
    }
}

struct EffectInstance: Codable, Equatable, Identifiable {
    var id = UUID()
    var typeID: String
    var isEnabled = true
    var params: [String: ParamValue]
    /// Text settings that aren't numbers (e.g. the chosen LUT file of a grade).
    var text: [String: String]? = nil

    func value(_ key: String) -> ParamValue? { params[key] }
    func number(_ key: String, _ t: Double) -> Double { params[key]?.number(at: t) ?? 0 }
    func point(_ key: String, _ t: Double) -> Vec2 { params[key]?.point(at: t) ?? .zero }
    func color(_ key: String, _ t: Double) -> RGBA { params[key]?.color(at: t) ?? .white }
    func bool(_ key: String) -> Bool { if case .toggle(let b) = params[key] { return b }; return false }
    func choice(_ key: String) -> Int { if case .choice(let i) = params[key] { return i }; return 0 }

    var keyframeTimes: [Double] { params.values.flatMap(\.keyframeTimes) }
}
