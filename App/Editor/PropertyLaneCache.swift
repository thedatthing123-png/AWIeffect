import Foundation

/// Metadata is built only for the feature that requests it; clock ticks perform dictionary lookups.
final class PropertyLaneCache {
    private final class Entry {
        var lanes: [PropertyLane]?
        var markers: [(id: UUID, time: Double)]?
        var effectMarkers: [UUID: [(id: UUID, time: Double)]] = [:]
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
        let result = Entry(); entries[layer.id] = result; return result
    }
    func lanes(_ layer: Layer) -> [PropertyLane] {
        let e = entry(layer)
        if let lanes = e.lanes { return lanes }
        let result = layer.propertyLanes(); e.lanes = result; builds += 1; return result
    }
    func markers(_ layer: Layer, effect: UUID? = nil) -> [(id: UUID, time: Double)] {
        let e = entry(layer)
        if let effect {
            if let result = e.effectMarkers[effect] { return result }
            let result = layer.keyframeMarkers(effect: effect); e.effectMarkers[effect] = result; return result
        }
        if let result = e.markers { return result }
        let result = layer.keyframeMarkers; e.markers = result; return result
    }
}
