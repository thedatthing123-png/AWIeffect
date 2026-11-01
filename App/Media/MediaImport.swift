import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import CoreTransferable

/// A movie picked from Photos, copied to a temporary file.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { m in SentTransferredFile(m.url) } importing: { received in
            let dst = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dst)
            return PickedMovie(url: dst)
        }
    }
}

extension EditorState {
    /// Copies a video into the project and adds it as a layer that fits the comp.
    func addVideo(from url: URL) {
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        guard let data = try? Data(contentsOf: url), let name = try? store.importMedia(data: data, ext: ext, into: project.id) else { return }
        let asset = AVURLAsset(url: store.mediaURL(name, projectID: project.id))
        guard let track = asset.tracks(withMediaType: .video).first else { return }
        let size = track.naturalSize.applying(track.preferredTransform)
        let w = Int(abs(size.width)), h = Int(abs(size.height))
        let duration = CMTimeGetSeconds(asset.duration)
        let audio = !asset.tracks(withMediaType: .audio).isEmpty
        let fit = min(Double(project.width) / Double(max(w, 1)), Double(project.height) / Double(max(h, 1)))
        mutate("Add Video") { p in
            var l = p.makeLayer(name: url.deletingPathExtension().lastPathComponent,
                                content: .video(fileName: name, pixelWidth: w, pixelHeight: h, hasAudio: audio),
                                size: Vec2(Double(w), Double(h)))
            l.transform.scale = Animated(Vec2(fit * 100, fit * 100))
            l.inPoint = currentTime
            l.outPoint = min(p.duration, currentTime + duration)
            l.fill = Animated(.white)
            // Grow the comp if the clip is longer than it.
            if currentTime + duration > p.duration { p.duration = currentTime + duration; l.outPoint = p.duration }
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        panel = .clip
        AudioPreview.shared.invalidate()
    }

    /// Pulls the sound out of a video file into an .m4a (AAC). Calls back on the main thread with the file, or nil.
    static func extractAudio(from url: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVURLAsset(url: url)
        guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else { completion(nil); return }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("sound-\(UUID().uuidString).m4a")
        ex.outputURL = out
        ex.outputFileType = .m4a
        ex.exportAsynchronously {
            DispatchQueue.main.async { completion(ex.status == .completed ? out : nil) }
        }
    }

    /// Music from a video (Photos or Files): only its sound becomes an audio layer.
    func addAudioFromVideo(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        let name = url.deletingPathExtension().lastPathComponent
        Self.extractAudio(from: url) { out in
            if access { url.stopAccessingSecurityScopedResource() }
            guard let out else { return }
            let named = out.deletingLastPathComponent().appendingPathComponent("\(name) (sound).m4a")
            try? FileManager.default.removeItem(at: named)
            let use = (try? FileManager.default.moveItem(at: out, to: named)) != nil ? named : out
            self.addAudio(from: use)
        }
    }

    /// Extract Audio: the selected video's sound becomes its own audio layer, lined up with the clip; the video is muted.
    func extractAudioFromSelected() {
        guard let l = selectedLayer, case .video(let file, _, _, _) = l.content else { return }
        let id = l.id, inP = l.inPoint, outP = l.outPoint, src = l.sourceStart, speed = l.speed, layerName = l.name
        Self.extractAudio(from: mediaURL(file)) { out in
            guard let out, let data = try? Data(contentsOf: out),
                  let name = try? self.store.importMedia(data: data, ext: "m4a", into: self.project.id) else { return }
            let duration = CMTimeGetSeconds(AVURLAsset(url: self.store.mediaURL(name, projectID: self.project.id)).duration)
            self.mutate("Extract Audio") { p in
                var a = p.makeLayer(name: "\(layerName) Audio", content: .audio(fileName: name, duration: duration), size: Vec2(1, 1))
                a.inPoint = inP; a.outPoint = outP; a.sourceStart = src; a.speed = speed
                a.tag = .green
                if let i = p.layers.firstIndex(where: { $0.id == id }) {
                    p.layers[i].volume = Animated(0)
                    p.layers.insert(a, at: i + 1)
                } else { p.layers.append(a) }
                self.selectedLayerID = a.id
            }
            AudioPreview.shared.invalidate()
        }
    }

    func addAudio(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let name = try? store.importMedia(data: data, ext: url.pathExtension.isEmpty ? "m4a" : url.pathExtension, into: project.id) else { return }
        let duration = CMTimeGetSeconds(AVURLAsset(url: store.mediaURL(name, projectID: project.id)).duration)
        mutate("Add Audio") { p in
            var l = p.makeLayer(name: url.deletingPathExtension().lastPathComponent, content: .audio(fileName: name, duration: duration),
                                size: Vec2(1, 1))
            l.inPoint = currentTime
            if currentTime + duration > p.duration { p.duration = currentTime + duration }
            l.outPoint = min(p.duration, currentTime + duration)
            l.tag = .green
            p.layers.append(l)
            selectedLayerID = l.id
        }
        panel = .clip
        AudioPreview.shared.invalidate()
    }

    /// Enables AE-style Time Remap with keyframes matching the current speed.
    func enableTimeRemap() {
        guard let i = selectedIndex else { return }
        mutate("Enable Time Remap") { p in
            let l = p.layers[i]
            var a = Animated(l.sourceStart)
            a.insertKeyframe(Keyframe(time: l.inPoint, value: l.sourceTime(at: l.inPoint), interpolation: .linear))
            a.insertKeyframe(Keyframe(time: l.outPoint, value: l.sourceTime(at: l.outPoint), interpolation: .linear))
            p.layers[i].timeRemap = a
        }
    }

    /// Velocity edit preset: fast → slow-mo at the playhead → fast (the classic edit ramp).
    func applySpeedRamp(slow: Double = 0.25, fast: Double = 1.6, window: Double = 0.4) {
        guard let i = selectedIndex else { return }
        let t = currentTime
        mutate("Speed Ramp") { p in
            let l = p.layers[i]
            let base = l.sourceTime(at: l.inPoint)
            var a = Animated(base)
            // Integrate speed over segments: fast until t-window, slow for 2*window, fast after.
            let t0 = max(l.inPoint, t - window), t1 = min(l.outPoint, t + window)
            let s0 = base + (t0 - l.inPoint) * fast
            let s1 = s0 + (t1 - t0) * slow
            let s2 = s1 + (l.outPoint - t1) * fast
            a.insertKeyframe(Keyframe(time: l.inPoint, value: base, interpolation: .bezier))
            a.insertKeyframe(Keyframe(time: t0, value: s0, interpolation: .bezier))
            a.insertKeyframe(Keyframe(time: t1, value: s1, interpolation: .bezier))
            a.insertKeyframe(Keyframe(time: l.outPoint, value: s2, interpolation: .linear))
            p.layers[i].timeRemap = a
        }
    }
}

// MARK: - Audio preview (keeps an AVPlayer in sync with the editor)

final class AudioPreview {
    static let shared = AudioPreview()
    private var player: AVPlayer?
    private var builtFor: String?

    func invalidate() { builtFor = nil }

    /// Builds an audio-only composition for all audible layers.
    static func composition(_ project: Project, mediaURL: (String) -> URL) -> (AVMutableComposition, AVAudioMix)? {
        return try? buildComposition(project, mediaURL: mediaURL)
    }

    /// Export uses the throwing variant so failed decoding cannot masquerade as an intentionally silent project.
    static func buildComposition(_ project: Project, mediaURL: (String) -> URL) throws -> (AVMutableComposition, AVAudioMix)? {
        let comp = AVMutableComposition()
        var params: [AVMutableAudioMixInputParameters] = []
        for l in project.layers where l.isVisible && l.hasAudio {
            guard let file = l.mediaFile else { continue }
            let retimed = l.timeRemap != nil || l.speed < 0
            let url = retimed ? try RetimedAudio.file(for: l, source: mediaURL(file)) : mediaURL(file)
            let asset = AVURLAsset(url: url)
            guard let src = asset.tracks(withMediaType: .audio).first,
                  let dst = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw ExportError.writer("Cannot load audio for \(l.name).")
            }
            let compDur = l.outPoint - l.inPoint
            let sourceStart = retimed ? 0 : l.sourceStart
            let speed = retimed ? 1 : l.speed
            guard compDur.isFinite, sourceStart.isFinite, speed.isFinite, speed > 0 else { continue }
            let available = CMTimeGetSeconds(asset.duration) - sourceStart
            let seconds = min(compDur * speed, available)
            guard seconds > 0 else { continue }
            let srcStart = CMTime(seconds: max(0, sourceStart), preferredTimescale: 48000)
            let srcDur = CMTime(seconds: seconds, preferredTimescale: 48000)
            let at = CMTime(seconds: max(0, l.inPoint), preferredTimescale: 48000)
            try dst.insertTimeRange(CMTimeRange(start: srcStart, duration: srcDur), of: src, at: at)
            if abs(speed - 1) > 1e-3 {
                dst.scaleTimeRange(CMTimeRange(start: at, duration: srcDur), toDuration: CMTime(seconds: seconds / speed, preferredTimescale: 48000))
            }
            let p = AVMutableAudioMixInputParameters(track: dst)
            let ks = l.volume.keyframes.sorted { $0.time < $1.time }
            if ks.isEmpty {
                p.setVolume(Float(l.volume.staticValue / 100), at: .zero)
            } else {
                p.setVolume(Float(ks[0].value / 100), at: .zero)
                // Smooth fades: ramp between consecutive volume keyframes instead of stepping.
                for (a, b) in zip(ks, ks.dropFirst()) where b.time > a.time {
                    let range = CMTimeRange(start: CMTime(seconds: a.time, preferredTimescale: 600),
                                            end: CMTime(seconds: b.time, preferredTimescale: 600))
                    if a.interpolation == .hold { p.setVolume(Float(a.value / 100), at: range.start) }
                    else { p.setVolumeRamp(fromStartVolume: Float(a.value / 100), toEndVolume: Float(b.value / 100), timeRange: range) }
                }
                if let last = ks.last { p.setVolume(Float(last.value / 100), at: CMTime(seconds: last.time, preferredTimescale: 600)) }
            }
            params.append(p)
        }
        guard !params.isEmpty else { return nil }
        let mix = AVMutableAudioMix()
        mix.inputParameters = params
        return (comp, mix)
    }

    func play(_ project: Project, from time: Double, mediaURL: (String) -> URL) {
        let key = (try? JSONEncoder().encode(project.layers)).map { $0.base64EncodedString() } ?? UUID().uuidString
        if builtFor != key {
            if let (comp, mix) = Self.composition(project, mediaURL: mediaURL) {
                let item = AVPlayerItem(asset: comp)
                item.audioMix = mix
                player = AVPlayer(playerItem: item)
            } else {
                player = nil
            }
            builtFor = key
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
    }

    func pause() { player?.pause() }
}
