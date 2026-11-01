import SwiftUI

/// Lets panels ask the editor to show media pickers.
final class MediaLauncher: ObservableObject {
    @Published var pickVideo = false
    /// Music button: asks where the sound comes from (Files or a video in Photos).
    @Published var pickAudio = false
    @Published var pickAudioFile = false
    @Published var pickAudioVideo = false
    @Published var pickModel = false
    /// Layer whose media is being replaced (footage placeholders from .aep imports, or any clip).
    @Published var replaceTarget: UUID?
}
