import Foundation

struct LayerTimeFX: Codable, Equatable {
    /// Echo: number of trailing copies, seconds between them, opacity kept per copy (0-1).
    var echoCount = 0
    var echoDelay = 0.05
    var echoDecay = 0.6
    /// Posterize time: the layer only updates this many times per second (0 = off).
    var posterizeFPS = 0.0
    /// Freeze frame: the layer holds this moment (nil = off).
    var freezeAt: Double? = nil
    /// AE Frame Blending: slowed-down footage blends neighbouring frames instead of repeating them.
    var frameBlendStore: Bool? = nil
    var frameBlend: Bool { get { frameBlendStore ?? false } set { frameBlendStore = newValue ? true : nil } }
    /// Pixel Motion Blur (RSMB-style) on footage: blur along how pixels move inside the clip, % of one frame.
    var pixelMotionBlurStore: Double? = nil
    var pixelMotionBlur: Double { get { pixelMotionBlurStore ?? 0 } set { pixelMotionBlurStore = newValue > 0 ? newValue : nil } }

    /// Time at which the layer's content and animation are evaluated.
    func localTime(_ t: Double) -> Double {
        if let f = freezeAt { return f }
        if posterizeFPS > 0 { return (t * posterizeFPS).rounded(.down) / posterizeFPS }
        return t
    }
    var isEmpty: Bool { echoCount == 0 && posterizeFPS == 0 && freezeAt == nil && !frameBlend && pixelMotionBlur == 0 }
}

/// AE track matte: the layer directly above cuts this one out (and hides itself).
enum TrackMatte: String, Codable, CaseIterable, Identifiable {
    case none, alpha, alphaInverted, luma, lumaInverted
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .alpha: return "Alpha"
        case .alphaInverted: return "Alpha Inverted"
        case .luma: return "Luma"
        case .lumaInverted: return "Luma Inverted"
        }
    }
}

enum BlendMode: String, Codable, CaseIterable, Identifiable {
    case normal, darken, multiply, colorBurn, linearBurn, darkerColor
    case add, lighten, screen, colorDodge, linearDodge, lighterColor
    case overlay, softLight, hardLight, linearLight, vividLight, pinLight, hardMix
    case difference, exclusion, subtract, divide
    case hue, saturation, color, luminosity
    var id: String { rawValue }
    var title: String {
        switch self {
        case .colorBurn: return "Color Burn"
        case .linearBurn: return "Linear Burn"
        case .darkerColor: return "Darker Color"
        case .colorDodge: return "Color Dodge"
        case .linearDodge: return "Linear Dodge"
        case .lighterColor: return "Lighter Color"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        case .linearLight: return "Linear Light"
        case .vividLight: return "Vivid Light"
        case .pinLight: return "Pin Light"
        case .hardMix: return "Hard Mix"
        default: return rawValue.capitalized
        }
    }
    /// The same groups After Effects uses in its blend menu.
    var group: String {
        switch self {
        case .normal: return "Normal"
        case .darken, .multiply, .colorBurn, .linearBurn, .darkerColor: return "Darken"
        case .add, .lighten, .screen, .colorDodge, .linearDodge, .lighterColor: return "Lighten"
        case .overlay, .softLight, .hardLight, .linearLight, .vividLight, .pinLight, .hardMix: return "Contrast"
        case .difference, .exclusion, .subtract, .divide: return "Difference"
        case .hue, .saturation, .color, .luminosity: return "Color"
        }
    }
    static let groups = ["Normal", "Darken", "Lighten", "Contrast", "Difference", "Color"]
    /// Index passed to the Metal compositors; must match Shaders.metal / Paths.metal / Draw.metal.
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
        case .colorBurn: return 8
        case .linearBurn: return 9
        case .darkerColor: return 10
        case .colorDodge: return 11
        case .linearDodge: return 12
        case .lighterColor: return 13
        case .softLight: return 14
        case .hardLight: return 15
        case .linearLight: return 16
        case .vividLight: return 17
        case .pinLight: return 18
        case .hardMix: return 19
        case .exclusion: return 20
        case .subtract: return 21
        case .divide: return 22
        case .hue: return 23
        case .saturation: return 24
        case .color: return 25
        case .luminosity: return 26
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
    /// AE-style 3D camera; its transform + `Layer.camera` options drive every 3D layer.
    case camera
    /// AE-style light (point / spot / parallel / ambient); lights every 3D layer, settings in `Layer.light`.
    case light
    /// Real 3D: imported model (usdz/obj) or extruded 3D text, rendered with lights; settings in `Layer.model3D`.
    case model
    /// Nested composition (AE pre-comp), stored in `Project.precomps`.
    case precomp(id: UUID)
    /// Text layer; content lives in `Layer.text`.
    case text
    /// Video clip in the project's media folder.
    case video(fileName: String, pixelWidth: Int, pixelHeight: Int, hasAudio: Bool)
    /// Audio-only clip.
    case audio(fileName: String, duration: Double)

    var symbol: String {
        switch self {
        case .shape(let k): return k.symbol
        case .solid: return "rectangle.fill"
        case .image: return "photo"
        case .adjustment: return "slider.horizontal.below.rectangle"
        case .camera: return "video"
        case .light: return "lightbulb.fill"
        case .model: return "cube.transparent"
        case .precomp: return "square.stack.3d.up"
        case .text: return "textformat"
        case .video: return "film"
        case .audio: return "waveform"
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
    // 3D (used when the layer is 3D): Z position (px, + = away from camera) and X/Y rotation (degrees).
    var positionZ = Animated(0.0)
    var rotationX = Animated(0.0)
    var rotationY = Animated(0.0)

    init(position: Animated<Vec2>) { self.position = position }

    private enum CodingKeys: String, CodingKey { case anchor, position, scale, rotation, opacity, positionZ, rotationX, rotationY }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        anchor = try c.decodeIfPresent(Animated<Vec2>.self, forKey: .anchor) ?? Animated(.zero)
        position = try c.decode(Animated<Vec2>.self, forKey: .position)
        scale = try c.decodeIfPresent(Animated<Vec2>.self, forKey: .scale) ?? Animated(Vec2(100, 100))
        rotation = try c.decodeIfPresent(Animated<Double>.self, forKey: .rotation) ?? Animated(0)
        opacity = try c.decodeIfPresent(Animated<Double>.self, forKey: .opacity) ?? Animated(100)
        positionZ = try c.decodeIfPresent(Animated<Double>.self, forKey: .positionZ) ?? Animated(0)
        rotationX = try c.decodeIfPresent(Animated<Double>.self, forKey: .rotationX) ?? Animated(0)
        rotationY = try c.decodeIfPresent(Animated<Double>.self, forKey: .rotationY) ?? Animated(0)
    }
}

/// AE camera options (Zoom = focal length in comp pixels; depth of field like AE's camera).
enum LightType: String, Codable, CaseIterable, Identifiable {
    case point, spot, parallel, ambient
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct LightOptions: Codable, Equatable {
    var type: LightType = .spot
    var color = Animated(RGBA(1, 0.96, 0.9))
    var intensity = Animated(100.0)       // %
    var coneAngle = Animated(70.0)        // degrees (spot)
    var coneFeather = Animated(50.0)      // %
    var falloffRadius = Animated(0.0)     // px, 0 = no falloff
    /// Shadows are off unless turned on (AE).
    var castsShadowsStore: Bool? = nil
    var castsShadows: Bool { get { castsShadowsStore ?? false } set { castsShadowsStore = newValue ? true : nil } }
    var shadowDarknessStore: Double? = nil
    var shadowDarkness: Double { get { shadowDarknessStore ?? 70 } set { shadowDarknessStore = newValue } }
}

struct CameraOptions: Codable, Equatable {
    var zoom = Animated(1000.0)
    var depthOfField = false
    var focusDistance = Animated(1000.0)
    var aperture = Animated(25.0)       // px
    var blurLevel = Animated(100.0)     // %
    /// Alight Motion-style 2D camera: the camera's position / scale / rotation (and shakes on it) move every
    /// 2D layer, like filming the whole scene. 3D layers always follow the 3D camera.
    var affects2DStore: Bool? = nil
    var affects2D: Bool { get { affects2DStore ?? false } set { affects2DStore = newValue } }
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
    /// Draw Studio document behind this image layer (live link for re-editing).
    var drawingID: UUID? = nil
    /// Media timing: playback speed (1 = normal, 0.5 = slow-mo), trim offset into the source (s), optional AE-style
    /// Time Remap (source seconds as a function of comp time), volume (0-200 %).
    var speed: Double = 1
    var sourceStart: Double = 0
    var timeRemap: Animated<Double>? = nil
    var volume = Animated(100.0)
    var frameBlending = false
    /// AI background cutout (image/video layers).
    var cutout: CutoutSettings? = nil
    /// AE 3D layer switch.
    var is3D = false
    /// Locked layers can't be picked or dragged on the canvas. Solo hides every non-solo layer.
    var isLocked = false
    var isSolo = false
    /// AE motion-blur switch (only renders when the scene's motion blur is enabled too).
    var motionBlur = false
    var trackMatte: TrackMatte = .none
    /// Time effects: echo trails, posterize time (choppy frame rate), freeze frame.
    var timeFX: LayerTimeFX? = nil
    /// Parent layer (position lives in the parent's space; rotation and scale follow it).
    var parentID: UUID? = nil
    /// Options for `.light` layers.
    var light: LightOptions? = nil
    /// AE null object: never rendered, used as a parent / control handle.
    var isNull = false
    /// Thickness (px) given to a 3D layer: the picture is extruded into a solid slab.
    var extrude = Animated(0.0)
    /// Options for `.camera` layers.
    var camera: CameraOptions? = nil
    /// Options for `.model` layers.
    var model3D: Model3DOptions? = nil
    /// Alight Motion-style group: this layer is a group container; its parts are the layers whose `groupID` is
    /// this layer's id. The group's transform, masks, effects, blend mode and matte apply to all parts together.
    var isGroup = false
    var groupCollapsed = false
    /// The group this layer is a part of.
    var groupID: UUID? = nil
    /// AE shape operators (Repeater, Offset / Wiggle Paths, Zig Zag, Pucker & Bloat) for shape layers.
    var shapeOps: ShapeOps? = nil
    /// Two-bone IK rig (this layer is the lower limb).
    var ik: IKRig? = nil
    /// IK tips and physics bodies can't pass through this layer.
    var isCollider = false
    /// 3D shadows (AE defaults: layers don't cast, do accept).
    var castsShadows = false
    var acceptsShadows = true

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
        drawingID = try c.decodeIfPresent(UUID.self, forKey: .drawingID)
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        sourceStart = try c.decodeIfPresent(Double.self, forKey: .sourceStart) ?? 0
        timeRemap = try c.decodeIfPresent(Animated<Double>.self, forKey: .timeRemap)
        volume = try c.decodeIfPresent(Animated<Double>.self, forKey: .volume) ?? Animated(100)
        frameBlending = try c.decodeIfPresent(Bool.self, forKey: .frameBlending) ?? false
        cutout = try c.decodeIfPresent(CutoutSettings.self, forKey: .cutout)
        is3D = try c.decodeIfPresent(Bool.self, forKey: .is3D) ?? false
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        isSolo = try c.decodeIfPresent(Bool.self, forKey: .isSolo) ?? false
        motionBlur = try c.decodeIfPresent(Bool.self, forKey: .motionBlur) ?? false
        trackMatte = try c.decodeIfPresent(TrackMatte.self, forKey: .trackMatte) ?? .none
        timeFX = try c.decodeIfPresent(LayerTimeFX.self, forKey: .timeFX)
        parentID = try c.decodeIfPresent(UUID.self, forKey: .parentID)
        light = try c.decodeIfPresent(LightOptions.self, forKey: .light)
        isNull = try c.decodeIfPresent(Bool.self, forKey: .isNull) ?? false
        extrude = try c.decodeIfPresent(Animated<Double>.self, forKey: .extrude) ?? Animated(0)
        camera = try c.decodeIfPresent(CameraOptions.self, forKey: .camera)
        model3D = try c.decodeIfPresent(Model3DOptions.self, forKey: .model3D)
        isGroup = try c.decodeIfPresent(Bool.self, forKey: .isGroup) ?? false
        groupCollapsed = try c.decodeIfPresent(Bool.self, forKey: .groupCollapsed) ?? false
        groupID = try c.decodeIfPresent(UUID.self, forKey: .groupID)
        shapeOps = try c.decodeIfPresent(ShapeOps.self, forKey: .shapeOps)
        ik = try c.decodeIfPresent(IKRig.self, forKey: .ik)
        isCollider = try c.decodeIfPresent(Bool.self, forKey: .isCollider) ?? false
        castsShadows = try c.decodeIfPresent(Bool.self, forKey: .castsShadows) ?? false
        acceptsShadows = try c.decodeIfPresent(Bool.self, forKey: .acceptsShadows) ?? true
    }

    func isActive(at time: Double) -> Bool { isVisible && time >= inPoint && time < outPoint }

    var isAudioOnly: Bool { if case .audio = content { return true }; return false }
    var isImage: Bool { if case .image = content { return true }; return false }

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
        t += transform.rotationX.keyframeTimes + transform.rotationY.keyframeTimes + transform.positionZ.keyframeTimes
        t += extrude.keyframeTimes + volume.keyframeTimes + sides.keyframeTimes + innerRatio.keyframeTimes
        t += (timeRemap?.keyframeTimes ?? []) + (path?.keyframeTimes ?? [])
        for m in masks { t += m.path.keyframeTimes }
        if let c = camera { t += c.zoom.keyframeTimes + c.focusDistance.keyframeTimes + c.aperture.keyframeTimes + c.blurLevel.keyframeTimes }
        if let m = model3D { t += m.yaw.keyframeTimes + m.pitch.keyframeTimes + m.roll.keyframeTimes + m.color.keyframeTimes }
        if let o = light { t += o.color.keyframeTimes + o.intensity.keyframeTimes + o.coneAngle.keyframeTimes + o.coneFeather.keyframeTimes + o.falloffRadius.keyframeTimes }
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
    /// Nested compositions used by `.precomp` layers (optional so older saves still decode).
    var precompList: [Project]? = nil
    var precomps: [Project] {
        get { precompList ?? [] }
        set { precompList = newValue.isEmpty ? nil : newValue }
    }
    /// Render-time nesting depth (guards against a comp containing itself).
    var precompDepth: Int? = nil
    /// Beat / comp markers in seconds (optional so older saves still decode).
    var markerTimes: [Double]? = nil
    /// Scene motion blur (optional storage so older saves decode).
    var motionBlurOn: Bool? = nil
    /// Alight Motion-style length: the project is as long as its layers (grows/shrinks with them).
    var autoLengthStore: Bool? = nil
    /// Alight Motion behaviour, always on: the project is exactly as long as its layers.
    var autoLength: Bool { get { autoLengthStore ?? true } set { autoLengthStore = newValue } }

    /// Length = end of the last layer (at least one second).
    mutating func fitAutoLength() {
        guard autoLength, let end = layers.map(\.outPoint).max() else { return }
        let d = max(1, snapToFrame(end))
        if abs(d - duration) > 1e-6 { duration = d }
    }
    /// AE-style automatic smoothness: layers with shake / wiggle / motion effects get real motion blur
    /// without switching anything on (on unless turned off).
    var smoothMotionStore: Bool? = nil
    var smoothMotion: Bool { get { smoothMotionStore ?? true } set { smoothMotionStore = newValue } }
    var shutterAngleStore: Double? = nil
    var blurSamplesStore: Int? = nil
    var motionBlurEnabled: Bool { get { motionBlurOn ?? false } set { motionBlurOn = newValue } }
    var shutterAngle: Double { get { shutterAngleStore ?? 180 } set { shutterAngleStore = newValue } }
    var blurSamples: Int { get { blurSamplesStore ?? 12 } set { blurSamplesStore = max(2, min(64, newValue)) } }
    var markers: [Double] {
        get { markerTimes ?? [] }
        set { markerTimes = newValue.sorted() }
    }
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
        let f = max((t * fps).rounded() / fps, 0)
        // Auto length: the project grows with its layers, so times may go past the current end.
        return autoLength ? min(f, 3600) : min(f, duration)
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
