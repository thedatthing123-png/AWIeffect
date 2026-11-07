import Foundation

/// A project edit invalidates only changed layers. Clock ticks never touch this cache or compare/hash a Layer.
final class PropertyLaneCache {
    private struct Entry {
        var lanes: [PropertyLane]
        var markers: [(id: UUID, time: Double)]
        var effectMarkers: [UUID: [(id: UUID, time: Double)]]
    }
    private var entries: [UUID: Entry] = [:]
    private(set) var builds = 0
    private(set) var revision = 0
    func invalidate(old: Project, new: Project) {
        revision &+= 1
        guard old.id == new.id else { entries.removeAll(); return }
        let previous = Dictionary(old.layers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let ids = Set(new.layers.map(\.id))
        entries = entries.filter { ids.contains($0.key) }
        for l in new.layers where entries[l.id] != nil && previous[l.id] != l { entries[l.id] = nil }
    }
    private func entry(_ layer: Layer) -> Entry {
        if let cached = entries[layer.id] { return cached }
        let result = Entry(lanes: layer.propertyLanes(), markers: layer.keyframeMarkers,
                           effectMarkers: Dictionary(uniqueKeysWithValues: layer.effects.map { ($0.id, layer.keyframeMarkers(effect: $0.id)) }))
        entries[layer.id] = result; builds += 1; return result
    }
    func lanes(_ layer: Layer) -> [PropertyLane] { entry(layer).lanes }
    func markers(_ layer: Layer, effect: UUID? = nil) -> [(id: UUID, time: Double)] {
        let e = entry(layer); return effect.flatMap { e.effectMarkers[$0] } ?? e.markers
    }
}
