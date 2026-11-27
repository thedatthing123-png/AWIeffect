import Foundation

enum RelightPass: String, Codable, CaseIterable, Identifiable {
    case baseColor, alpha, normal, depth
    var id: String { rawValue }
    var title: String {
        switch self {
        case .baseColor: return "Base Color"
        case .alpha: return "Alpha"
        case .normal: return "Normals"
        case .depth: return "Depth"
        }
    }
    var icon: String {
        switch self {
        case .baseColor: return "paintpalette"
        case .alpha: return "circle.lefthalf.filled"
        case .normal: return "arrow.up.right"
        case .depth: return "square.3.layers.3d"
        }
    }
}

struct RelightMedia: Codable, Equatable {
    var file: String
    var name: String
    var isVideo: Bool
}

struct RelightSurface: Codable, Equatable {
    var maps: [RelightPass: RelightMedia] = [:]
    var enabled = true
    var depth = 45.0
    var normalStrength = 100.0
    var roughness = 62.0
    var specular = 25.0
    var invertDepth = false
    var flipNormalY = false
    var reliefShadows = true
}

extension Layer {
    var supportsRelight: Bool {
        if case .video = content { return true }
        return isImage
    }

    var activeRelight: RelightSurface? {
        guard supportsRelight, let surface = relight, surface.enabled, !surface.maps.isEmpty else { return nil }
        return surface
    }
}
