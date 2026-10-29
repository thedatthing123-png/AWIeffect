import Foundation

enum BlendMode: String, Codable, CaseIterable, Identifiable {
    case normal, add, screen, multiply, overlay, lighten, darken, difference
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// Index passed to the Metal compositor; must match Shaders.metal.
    var shaderIndex: UInt32 {
        switch self {
        case .normal: return 0
        case .add: return 1
        case .screen: return 2
        case .multiply: return 3
        case .overlay: return 4
        case .lighten: return 5
        case .darken: return 6
        case .difference: return 7
        }
    }
}

enum ShapeKind: String, Codable, CaseIterable, Identifiable {
    case rectangle, ellipse, polygon, star, path
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .rectangle: return "square.fill"
        case .ellipse: return "circle.fill"
        case .polygon: return "hexagon.fill"
        case .star: return "star.fill"
        case .path: return "scribble.variable"
        }
    }
    var shaderIndex: UInt32 {
        switch self {
        case .rectangle: return 0
        case .ellipse: return 1
        case .polygon: return 2
        case .star: return 3
        case .path: return 0
        }
    }
}

enum LayerContent: Codable, Equatable {
    case shape(ShapeKind)
    case solid
    /// Image stored in the project's media folder, referenced by file name.
    case image(fileName: String, pixelWidth: Int, pixelHeight: Int)
    /// Adjustment layer: its effects apply to everything below, inside its bounds.
    case adjustment
    /// Text layer; content lives in `Layer.text`.
    case text

    var symbol: String {
        switch self {
        case .shape(let k): return k.symbol
        case .solid: return "rectangle.fill"
        case .image: return "photo"
        case .adjustment: return "slider.horizontal.below.rectangle"
        case .text: return "textformat"
        }
    }
}

struct LayerTransform: Codable, Equatable {
    /// Anchor point in layer-local pixels, relative to the layer's center.
    var anchor = Animated(Vec2.zero)
    /// Position in composition pixels.
    var position: Animated<Vec2>
    /// Scale in percent.
    var scale = Animated(Vec2(100, 100))
    /// Rotation in degrees, clockwise.
    var rotation = Animated(0.0)
    /// Opacity 0...100.
    var opacity = Animated(100.0)
}

/// Layer color tags for the timeline (user-changeable).
enum LayerTag: String, Codable, CaseIterable {
    case purple, blue, teal, pink, amber, green
}

struct Layer: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var content: LayerContent
    var tag: LayerTag = .purple
    var isVisible = true
    var inPoint: Double = 0
    var outPoint: Double
    var transform: LayerTransform
    /// Layer content size in pixels (shapes, solids); images use their pixel size.
    var size: Animated<Vec2>
    var fill = Animated(RGBA(hex: 0x9B5CFF))
    var cornerRadius = Animated(0.0)
    var sides = Animated(6.0)
    /// Star inner radius as a fraction of the outer radius.
    var innerRatio = Animated(0.45)
    var blendMode: BlendMode = .normal
    /// Effect stack, applied top to bottom (AE order).
    var effects: [EffectInstance] = []
    /// Text content and animators (text layers only).
    var text: TextData? = nil
    /// AE-style masks (applied before effects).
    var masks: [LayerMask] = []
    /// Bezier path for `.shape(.path)` layers (layer-local px, origin at center).
    var path: Animated<BezierPath>? = nil
    var stroke = ShapeStroke()

    init(id: UUID = UUID(), name: String, content: LayerContent, tag: LayerTag = .purple, outPoint: Double,
         transform: LayerTransform, size: Animated<Vec2>) {
        self.id = id
        self.name = name
        self.content = content
        self.tag = tag
        self.outPoint = outPoint
        self.transform = transform
        self.size = size
    }

    // Tolerant decoding: fields added in later versions get defaults, so old projects keep opening.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        content = try c.decode(LayerContent.self, forKey: .content)
        tag = try c.decodeIfPresent(LayerTag.self, forKey: .tag) ?? .purple
        isVisible = try c.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        inPoint = try c.decodeIfPresent(Double.self, forKey: .inPoint) ?? 0
        outPoint = try c.decode(Double.self, forKey: .outPoint)
        transform = try c.decode(LayerTransform.self, forKey: .transform)
        size = try c.decode(Animated<Vec2>.self, forKey: .size)
        fill = try c.decodeIfPresent(Animated<RGBA>.self, forKey: .fill) ?? Animated(RGBA(hex: 0x9B5CFF))
        cornerRadius = try c.decodeIfPresent(Animated<Double>.self, forKey: .cornerRadius) ?? Animated(0)
        sides = try c.decodeIfPresent(Animated<Double>.self, forKey: .sides) ?? Animated(6)
        innerRatio = try c.decodeIfPresent(Animated<Double>.self, forKey: .innerRatio) ?? Animated(0.45)
        blendMode = try c.decodeIfPresent(BlendMode.self, forKey: .blendMode) ?? .normal
        effects = try c.decodeIfPresent([EffectInstance].self, forKey: .effects) ?? []
        text = try c.decodeIfPresent(TextData.self, forKey: .text)
        masks = try c.decodeIfPresent([LayerMask].self, forKey: .masks) ?? []
        path = try c.decodeIfPresent(Animated<BezierPath>.self, forKey: .path)
        stroke = try c.decodeIfPresent(ShapeStroke.self, forKey: .stroke) ?? ShapeStroke()
    }

    func isActive(at time: Double) -> Bool { isVisible && time >= inPoint && time < outPoint }

    /// All keyframe times on this layer (for timeline markers).
    var keyframeTimes: [Double] {
        var t: [Double] = []
        t += transform.anchor.keyframeTimes
        t += transform.position.keyframeTimes
        t += transform.scale.keyframeTimes
        t += transform.rotation.keyframeTimes
        t += transform.opacity.keyframeTimes
        t += size.keyframeTimes
        t += fill.keyframeTimes
        t += cornerRadius.keyframeTimes
        for e in effects { t += e.keyframeTimes }
        if let tx = text {
            t += tx.fill.keyframeTimes + tx.tracking.keyframeTimes
            for a in tx.animators {
                t += a.selector.start.keyframeTimes + a.selector.end.keyframeTimes + a.selector.offset.keyframeTimes + a.selector.amount.keyframeTimes
                let pr = a.properties
                t += (pr.position?.keyframeTimes ?? []) + (pr.scale?.keyframeTimes ?? []) + (pr.rotation?.keyframeTimes ?? [])
                t += (pr.opacity?.keyframeTimes ?? []) + (pr.fill?.keyframeTimes ?? []) + (pr.tracking?.keyframeTimes ?? [])
            }
        }
        return Array(Set(t.map { ($0 * 10000).rounded() / 10000 })).sorted()
    }
}

struct Project: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var width: Int
    var height: Int
    var fps: Double
    var duration: Double
    var background: RGBA
    /// Index 0 is the TOP layer (AE order).
    var layers: [Layer] = []
    var createdAt = Date()
    var modifiedAt = Date()

    var aspectLabel: String {
        let g = gcd(width, height)
        return "\(width / g):\(height / g)"
    }

    var center: Vec2 { Vec2(Double(width) / 2, Double(height) / 2) }
    var frameDuration: Double { 1 / fps }
    var frameCount: Int { Int((duration * fps).rounded()) }

    func snapToFrame(_ t: Double) -> Double {
        min(max((t * fps).rounded() / fps, 0), duration)
    }

    private func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? max(a, 1) : gcd(b, a % b) }

    static func new(name: String, width: Int, height: Int, fps: Double, duration: Double = 10, background: RGBA = .black) -> Project {
        Project(name: name, width: width, height: height, fps: fps, duration: duration, background: background)
    }

    mutating func makeLayer(name: String, content: LayerContent, size: Vec2) -> Layer {
        let tag = LayerTag.allCases[layers.count % LayerTag.allCases.count]
        return Layer(
            name: name, content: content, tag: tag, outPoint: duration,
            transform: LayerTransform(position: Animated(center)),
            size: Animated(size)
        )
    }
}
