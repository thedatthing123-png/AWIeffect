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
    /// Copies a video into the project (file copy, never the whole movie in memory) and adds it as a layer that
    /// fits the comp. Failures are shown to the user instead of silently doing nothing.
    @discardableResult
    func addVideo(from url: URL) -> Bool {
        let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
        let name: String
        do { name = try store.importMedia(fileAt: url, ext: ext, into: rootProject.id) }
        catch {
            recoveryNotice = "Couldn't import the video: " + error.localizedDescription
            return false
        }
        let stored = store.mediaURL(name, projectID: rootProject.id)
        let asset = AVURLAsset(url: stored)
        guard let track = asset.tracks(withMediaType: .video).first else {
            try? FileManager.default.removeItem(at: stored)
            recoveryNotice = "Couldn't import the video: the file has no readable video track."
            return false
        }
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
        return true
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
                  let name = try? self.store.importMedia(data: data, ext: "m4a", into: self.rootProject.id) else { return }
            let duration = CMTimeGetSeconds(AVURLAsset(url: self.store.mediaURL(name, projectID: self.rootProject.id)).duration)
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
              let name = try? store.importMedia(data: data, ext: url.pathExtension.isEmpty ? "m4a" : url.pathExtension, into: rootProject.id) else { return }
        let duration = CMTimeGetSeconds(AVURLAsset(url: store.mediaURL(name, projectID: rootProject.id)).duration)
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
        guard let i = selectedIndex, project.layers[i].supportsSourceTiming, project.layers[i].timeRemap == nil else { return }
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
        guard project.layers[i].supportsSourceTiming, slow.isFinite, fast.isFinite, window.isFinite else { return }
        let t = currentTime
        mutate("Speed Ramp") { p in
            let l = p.layers[i]
            let start = l.inPoint, end = l.outPoint
            guard end - start >= p.frameDuration * 3 else { return }
            let center = min(end - p.frameDuration, max(start + p.frameDuration, t))
            let half = min(max(p.frameDuration / 2, window), (end - start) / 2 - p.frameDuration / 2)
            let times: [Double] = [start, max(start + p.frameDuration / 2, center - half),
                         min(end - p.frameDuration / 2, center + half), end]
            let speeds: [Double] = [max(0.01, fast), max(0.01, slow), max(0.01, slow), max(0.01, fast)]
            let sourceStart = l.sourceTime(at: start), sourceEnd = l.sourceTime(at: end)
            var areas: [Double] = []
            for index in 0..<3 {
                let averageSpeed: Double = (speeds[index] + speeds[index + 1]) * 0.5
                let elapsed: Double = times[index + 1] - times[index]
                areas.append(averageSpeed * elapsed)
            }
            let scale = (sourceEnd - sourceStart) / max(areas.reduce(0, +), 1e-9)
            var a = Animated(sourceStart), value = sourceStart
            for k in 0..<4 {
                if k > 0 { value += areas[k - 1] * scale }
                a.insertKeyframe(Keyframe(time: times[k], value: value, interpolation: .bezier))
            }
            for k in 0..<3 {
                let dt = times[k + 1] - times[k], dv = a.keyframes[k + 1].value - a.keyframes[k].value
                if abs(dv) < 1e-9 { a.keyframes[k].interpolation = .hold; continue }
                a.keyframes[k].easeOut = EaseHandle(x: 1.0 / 3, y: speeds[k] * scale * dt / (3 * dv))
                a.keyframes[k + 1].easeIn = EaseHandle(x: 2.0 / 3, y: 1 - speeds[k + 1] * scale * dt / (3 * dv))
            }
            p.layers[i].timeRemap = a
        }
        AudioPreview.shared.invalidate()
    }
}

// MARK: - Audio preview (keeps an AVPlayer in sync with the editor)

struct AudioTimeline {
    let composition: AVMutableComposition
    let mix: AVAudioMix
    // Scratch-file owners stay alive for the full playback/export lifetime, even after cache eviction.
    let sources: [RetimedAudio.Source]
}

final class AudioPreview {
    static let shared = AudioPreview()
    private var player: AVPlayer?
    private var builtFor: String?
    private var buildTask: Task<Void, Never>?
    private var preparedAudio: AudioTimeline?

    func invalidate() { buildTask?.cancel(); builtFor = nil }

    /// One audio timeline for playback and export; failed decoding cannot masquerade as intentional silence.
    static func buildComposition(_ project: Project, mediaURL: (String) -> URL, isCancelled: () -> Bool = { false }) throws -> AudioTimeline? {
        let comp = AVMutableComposition()
        var retainedSources: [RetimedAudio.Source] = []
        var params: [AVMutableAudioMixInputParameters] = []
        var tracks: [UUID: (track: AVMutableCompositionTrack, param: Int, layer: Layer)] = [:]
        for l in project.layers where l.isVisible && l.hasAudio {
            guard let file = l.mediaFile else { continue }
            if isCancelled() || Task.isCancelled { throw ExportError.cancelled }
            // Tape-style speed (Keep Pitch off) resamples like a remap, so the pitch follows the speed.
            let tapeSpeed = l.audioFX?.keepPitch == false && abs(l.speed - 1) > 1e-3
            let retimed = l.timeRemap != nil || l.speed < 0 || l.timeFX?.freezeAt != nil || tapeSpeed
            var asset: AVURLAsset
            if retimed {
                let source = try RetimedAudio.source(for: l, source: mediaURL(file), isCancelled: isCancelled)
                retainedSources.append(source)
                asset = source.asset
            } else { asset = AVURLAsset(url: mediaURL(file)) }
            // EQ / compressor / pitch: same timing, processed sound.
            if let fx = l.audioFX, fx.needsProcessing {
                let processed = try AudioFXRender.process(asset, fx: fx, isCancelled: isCancelled)
                retainedSources.append(processed)
                asset = processed.asset
            }
            guard let src = asset.tracks(withMediaType: .audio).first,
                  let dst = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                throw ExportError.writer("Cannot load audio for \(l.name).")
            }
            let timelineStart = max(0, l.inPoint)
            let compDur = min(project.duration, l.outPoint) - timelineStart
            let sourceStart = retimed ? timelineStart - l.inPoint : l.sourceTime(at: timelineStart)
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
            tracks[l.id] = (dst, params.count, l)
            params.append(p)
        }
        guard !params.isEmpty else { return nil }
        // Fades and ducking: the volume becomes a sampled envelope (keys × fade curve × duck gain).
        for (_, entry) in tracks {
            guard let fx = entry.layer.audioFX, fx.needsEnvelope else { continue }
            let end = min(project.duration, comp.duration.seconds)
            guard end > 0 else { continue }
            var gains: [Float] = []
            if let keyID = fx.duckUnder, keyID != entry.layer.id, let key = tracks[keyID] {
                let levels = try AudioDucking.levels(of: key.track, in: comp, until: end, isCancelled: isCancelled)
                gains = AudioDucking.gains(levelsDB: levels, amountDB: fx.duckAmount, release: fx.duckRelease)
            }
            let p = AVMutableAudioMixInputParameters(track: entry.track)
            AudioDucking.apply(gains: gains, layer: entry.layer, to: p, end: end)
            params[entry.param] = p
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = params
        return AudioTimeline(composition: comp, mix: mix, sources: retainedSources)
    }

    func play(_ project: Project, from time: Double, mediaURL: @escaping (String) -> URL) {
        buildTask?.cancel()
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let media = project.layers.compactMap(\.mediaFile).map { mediaURL($0).path }.joined(separator: "|")
        let key = "\(project.id)|\(project.duration)|\(media)|" + ((try? encoder.encode(project.layers)).map { $0.base64EncodedString() } ?? UUID().uuidString)
        if builtFor == key {
            startPlayer(at: time)
            return
        }
        player?.pause()
        let started = ProcessInfo.processInfo.systemUptime
        // Reverse/remap preprocessing can be substantial. Never block the editor's display link.
        buildTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try Self.buildComposition(project, mediaURL: mediaURL, isCancelled: { Task.isCancelled })
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled, let self else { return }
                    if let result {
                        let item = AVPlayerItem(asset: result.composition)
                        item.audioMix = result.mix
                        self.player = AVPlayer(playerItem: item)
                    } else { self.player = nil }
                    self.preparedAudio = result
                    self.builtFor = key
                    let now = time + ProcessInfo.processInfo.systemUptime - started
                    if now < project.duration { self.startPlayer(at: now) }
                }
            } catch {
                if !Task.isCancelled { NSLog("AWIeffect audio preview: %@", error.localizedDescription) }
            }
        }
    }

    private func startPlayer(at time: Double) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        player?.play()
    }

    func pause() { buildTask?.cancel(); player?.pause() }
}
