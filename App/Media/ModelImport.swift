import Foundation
import SceneKit

enum ModelImport {
    static func load(url: URL) throws -> SCNScene { try AWIModelLoader.load(url: url) }
}
