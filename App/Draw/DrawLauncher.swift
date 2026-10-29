import SwiftUI

/// Opens Draw Studio from anywhere in the editor (new drawing or re-editing a drawing layer).
final class DrawLauncher: ObservableObject {
    struct Request: Equatable { let id = UUID(); let layerID: UUID? }
    struct Session: Identifiable { let id = UUID(); let engine: DrawEngine; let layerID: UUID? }
    @Published var request: Request?
    @Published var session: Session?
    func open(_ layerID: UUID?) { request = Request(layerID: layerID) }
}
