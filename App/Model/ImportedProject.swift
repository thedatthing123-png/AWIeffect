import Foundation

enum ImportedProjectFormat: String, Codable, Equatable {
    case afterEffects, alightMotion

    var title: String {
        switch self {
        case .afterEffects: return "After Effects"
        case .alightMotion: return "Alight Motion"
        }
    }
}

/// Source-native data lives beside the editable adapter tracks. It is inert and
/// can outlive a missing renderer without dropping the source effect from the stack.
struct ImportedProperty: Codable, Equatable {
    var name: String
    var attributes: [String: String]? = nil
    var text: String? = nil
    var bytes: Data? = nil
    var children: [ImportedProperty] = []
}

struct ImportedEffect: Codable, Equatable {
    enum Support: String, Codable { case nativeAdapter, approximation, unavailable, layerSettings }
    var format: ImportedProjectFormat
    var matchName: String
    var displayName: String
    var support: Support
    var version = 1
    var properties: [ImportedProperty] = []
    var phaseOrigin: Double? = nil
    var rateScale: Double? = nil

    var sourceID: String { "\(format.rawValue):\(matchName)" }
}

struct ImportedFootage: Codable, Equatable {
    var name: String
    var sourceReference: String
}
