import Foundation

/// Edge profile of the bevel that joins the front/back faces to the extruded sides.
enum Text3DBevelProfile: String, Codable, CaseIterable {
    /// No bevel: faces meet the sides at a hard 90° edge.
    case flat
    /// Quarter-circle rounded edge.
    case round
    /// Straight 45° chamfer.
    case angle
}

/// One surface material of real 3D text (front face, bevel or sides). Every numeric value keyframes.
struct Text3DMaterial: Codable, Equatable {
    var color = Animated(RGBA(0.85, 0.85, 0.88))
    /// 0 = dielectric, 1 = metal.
    var metalness = Animated(0.0)
    /// 0 = mirror, 1 = matte.
    var roughness = Animated(0.4)
    /// Self glow in the base color (0 = none, 1 = full, >1 = bloom-ready hot).
    var emission = Animated(0.0)
    /// Lacquer layer over the surface (0-1).
    var clearcoat = Animated(0.0)
    /// Cel shading with a dark outline instead of PBR.
    var toon = false
    /// Overall opacity (0-1).
    var opacity = Animated(1.0)
    /// Glass: how much the environment shows through the surface (0-1).
    var transmission = Animated(0.0)

    init(color: RGBA = RGBA(0.85, 0.85, 0.88), metalness: Double = 0, roughness: Double = 0.4, emission: Double = 0,
         clearcoat: Double = 0, toon: Bool = false, opacity: Double = 1, transmission: Double = 0) {
        self.color = Animated(color); self.metalness = Animated(metalness); self.roughness = Animated(roughness)
        self.emission = Animated(emission); self.clearcoat = Animated(clearcoat); self.toon = toon
        self.opacity = Animated(opacity); self.transmission = Animated(transmission)
    }

    private enum CodingKeys: String, CodingKey { case color, metalness, roughness, emission, clearcoat, toon, opacity, transmission }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Text3DMaterial()
        color = try c.decodeIfPresent(Animated<RGBA>.self, forKey: .color) ?? d.color
        metalness = try c.decodeIfPresent(Animated<Double>.self, forKey: .metalness) ?? d.metalness
        roughness = try c.decodeIfPresent(Animated<Double>.self, forKey: .roughness) ?? d.roughness
        emission = try c.decodeIfPresent(Animated<Double>.self, forKey: .emission) ?? d.emission
        clearcoat = try c.decodeIfPresent(Animated<Double>.self, forKey: .clearcoat) ?? d.clearcoat
        toon = try c.decodeIfPresent(Bool.self, forKey: .toon) ?? d.toon
        opacity = try c.decodeIfPresent(Animated<Double>.self, forKey: .opacity) ?? d.opacity
        transmission = try c.decodeIfPresent(Animated<Double>.self, forKey: .transmission) ?? d.transmission
    }

    /// Named looks for the 3D text presets (front, bevel and sides use the same look unless edited).
    static let presets: [(name: String, material: Text3DMaterial)] = [
        ("Chrome", chrome), ("Gold", gold), ("Glass", glass), ("Toon", toonLook),
        ("Neon", neon), ("Stone", stone), ("Plastic", plastic)
    ]
    static func preset(named name: String) -> Text3DMaterial? { presets.first { $0.name.lowercased() == name.lowercased() }?.material }

    static let chrome = Text3DMaterial(color: RGBA(0.96, 0.96, 0.98), metalness: 1, roughness: 0.08, clearcoat: 0.3)
    static let gold = Text3DMaterial(color: RGBA(1.0, 0.77, 0.34), metalness: 1, roughness: 0.22)
    static let glass = Text3DMaterial(color: RGBA(0.85, 0.95, 1.0), metalness: 0, roughness: 0.03, clearcoat: 1, opacity: 0.55, transmission: 0.8)
    static let toonLook = Text3DMaterial(color: RGBA(1.0, 0.36, 0.45), metalness: 0, roughness: 1, toon: true)
    static let neon = Text3DMaterial(color: RGBA(0.2, 0.95, 1.0), metalness: 0, roughness: 0.5, emission: 2.5)
    static let stone = Text3DMaterial(color: RGBA(0.52, 0.5, 0.47), metalness: 0, roughness: 0.92)
    static let plastic = Text3DMaterial(color: RGBA(0.16, 0.42, 1.0), metalness: 0, roughness: 0.35, clearcoat: 0.6)
}

/// Real extruded 3D text settings for a text layer (`text3D`). Distances are in layer pixels at 100% scale.
struct Text3DOptions: Codable, Equatable {
    var extrusion = Animated(40.0)
    var bevelSize = Animated(4.0)
    var bevelSegments = 4
    var bevelProfile: Text3DBevelProfile = .round
    var front = Text3DMaterial.chrome
    var bevel = Text3DMaterial.chrome
    var side = Text3DMaterial.chrome
    /// Strength of the procedural studio environment (reflections and image-based light).
    var environmentIntensity = Animated(1.0)
    /// Environment turn around the vertical axis, degrees.
    var environmentRotation = Animated(0.0)

    init() {}

    /// Same look on all three parts.
    init(material: Text3DMaterial, extrusion: Double = 40, bevelSize: Double = 4,
         bevelSegments: Int = 4, bevelProfile: Text3DBevelProfile = .round) {
        front = material; bevel = material; side = material
        self.extrusion = Animated(extrusion); self.bevelSize = Animated(bevelSize)
        self.bevelSegments = bevelSegments; self.bevelProfile = bevelProfile
    }

    private enum CodingKeys: String, CodingKey {
        case extrusion, bevelSize, bevelSegments, bevelProfile, front, bevel, side, environmentIntensity, environmentRotation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Text3DOptions()
        extrusion = try c.decodeIfPresent(Animated<Double>.self, forKey: .extrusion) ?? d.extrusion
        bevelSize = try c.decodeIfPresent(Animated<Double>.self, forKey: .bevelSize) ?? d.bevelSize
        bevelSegments = try c.decodeIfPresent(Int.self, forKey: .bevelSegments) ?? d.bevelSegments
        bevelProfile = (try? c.decodeIfPresent(Text3DBevelProfile.self, forKey: .bevelProfile)) ?? d.bevelProfile
        front = try c.decodeIfPresent(Text3DMaterial.self, forKey: .front) ?? d.front
        bevel = try c.decodeIfPresent(Text3DMaterial.self, forKey: .bevel) ?? d.bevel
        side = try c.decodeIfPresent(Text3DMaterial.self, forKey: .side) ?? d.side
        environmentIntensity = try c.decodeIfPresent(Animated<Double>.self, forKey: .environmentIntensity) ?? d.environmentIntensity
        environmentRotation = try c.decodeIfPresent(Animated<Double>.self, forKey: .environmentRotation) ?? d.environmentRotation
    }
}
