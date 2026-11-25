import Foundation

struct ArtworkBone: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var start: Vec2
    var end: Vec2
    var parentID: UUID?
}

struct ArtworkRig: Codable, Equatable {
    var bones: [ArtworkBone] = []

    func canParent(_ boneID: UUID, to parentID: UUID?) -> Bool {
        guard bones.contains(where: { $0.id == boneID }) else { return false }
        var next = parentID
        var visited: Set<UUID> = [boneID]
        while let id = next {
            guard visited.insert(id).inserted, let parent = bones.first(where: { $0.id == id }) else { return false }
            next = parent.parentID
        }
        return true
    }

    mutating func reparent(_ boneID: UUID, to parentID: UUID?) {
        guard canParent(boneID, to: parentID),
              let index = bones.firstIndex(where: { $0.id == boneID }) else { return }
        bones[index].parentID = parentID
    }
}
