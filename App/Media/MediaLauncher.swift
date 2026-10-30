import SwiftUI

/// Lets panels ask the editor to show media pickers.
final class MediaLauncher: ObservableObject {
    @Published var pickVideo = false
    @Published var pickAudio = false
    @Published var pickModel = false
    /// Layer whose media is being replaced (footage placeholders from .aep imports, or any clip).
    @Published var replaceTarget: UUID?
}
