import AVFoundation
import Foundation
import Speech

/// Anything that can turn a media file's audio into timed words (the real one uses Speech; tests inject a fake).
protocol CaptionTranscribing {
    /// Words with times in SOURCE seconds of the file. `range` limits the part of the file heard.
    /// `progress` gets 0...1. Cancel by cancelling the calling Task.
    func transcribe(url: URL, range: ClosedRange<Double>?, localeID: String,
                    progress: @escaping (Double) -> Void) async throws -> [CaptionWord]
}

enum TranscriberError: LocalizedError {
    case notAuthorized, unavailable(String), noAudio, failed(String)
    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Speech recognition is off for AWIeffect. Turn it on in Settings › Privacy › Speech Recognition."
        case .unavailable(let l): return "Speech recognition for \(l) isn't available right now."
        case .noAudio: return "This clip has no audio to caption."
        case .failed(let m): return m
        }
    }
}

/// On-device word-timed transcription with SFSpeechRecognizer. Long files are cut into ~50 s chunks
/// (Speech stops at about a minute per request); each chunk's word times are shifted back to file time.
final class SpeechTranscriber: CaptionTranscribing {
    var chunkLength: Double = 50

    static var supportedLocaleIDs: [String] {
        SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted {
            (Locale.current.localizedString(forIdentifier: $0) ?? $0) < (Locale.current.localizedString(forIdentifier: $1) ?? $1)
        }
    }

    static func requestPermission() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
    }

    func transcribe(url: URL, range: ClosedRange<Double>?, localeID: String,
                    progress: @escaping (Double) -> Void) async throws -> [CaptionWord] {
        guard await Self.requestPermission() else { throw TranscriberError.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)), recognizer.isAvailable else {
            throw TranscriberError.unavailable(Locale.current.localizedString(forIdentifier: localeID) ?? localeID)
        }
        let asset = AVURLAsset(url: url)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw TranscriberError.noAudio }
        let duration = try await asset.load(.duration).seconds
        let lo = max(0, range?.lowerBound ?? 0)
        let hi = min(duration.isFinite ? duration : 0, range?.upperBound ?? duration)
        guard hi > lo else { throw TranscriberError.noAudio }

        var words: [CaptionWord] = []
        var t = lo
        progress(0)
        while t < hi - 0.05 {
            try Task.checkCancellation()
            let end = min(hi, t + chunkLength)
            let file = FileManager.default.temporaryDirectory.appendingPathComponent("caption-\(UUID().uuidString).m4a")
            defer { try? FileManager.default.removeItem(at: file) }
            try await Self.exportAudio(asset, from: t, to: end, into: file)
            try Task.checkCancellation()
            let chunkStart = t
            let found = try await Self.recognize(file, recognizer: recognizer) { p in
                progress(min(1, ((chunkStart - lo) + p * (end - chunkStart)) / (hi - lo)))
            }
            words += found.map { CaptionWord(text: $0.text, start: $0.start + chunkStart, end: $0.end + chunkStart) }
            progress(min(1, (end - lo) / (hi - lo)))
            t = end
        }
        return words
    }

    private static func exportAudio(_ asset: AVAsset, from a: Double, to b: Double, into url: URL) async throws {
        guard let ex = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriberError.failed("Couldn't read the clip's audio.")
        }
        ex.timeRange = CMTimeRange(start: CMTime(seconds: a, preferredTimescale: 600),
                                   end: CMTime(seconds: b, preferredTimescale: 600))
        try await ex.export(to: url, as: .m4a)
    }

    /// Guards the continuation so it resumes exactly once (Speech can call back several times).
    private final class Once {
        private let lock = NSLock()
        private var done = false
        func run(_ f: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true
            f()
        }
    }

    private final class TaskBox { var task: SFSpeechRecognitionTask? }

    private static func recognize(_ url: URL, recognizer: SFSpeechRecognizer,
                                  progress: @escaping (Double) -> Void) async throws -> [CaptionWord] {
        let req = SFSpeechURLRecognitionRequest(url: url)
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
        req.addsPunctuation = true
        req.taskHint = .dictation
        let box = TaskBox()
        let once = Once()
        let loadedDuration = try await AVURLAsset(url: url).load(.duration).seconds
        let chunkDuration = max(0.1, loadedDuration.isFinite ? loadedDuration : 0.1)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (c: CheckedContinuation<[CaptionWord], Error>) in
                box.task = recognizer.recognitionTask(with: req) { result, error in
                    if let result {
                        let segs = result.bestTranscription.segments
                        if let last = segs.last { progress(min(0.99, (last.timestamp + last.duration) / chunkDuration)) }
                        if result.isFinal {
                            let ws = segs.map { CaptionWord(text: $0.substring, start: $0.timestamp, end: $0.timestamp + $0.duration) }
                            once.run { c.resume(returning: ws) }
                            return
                        }
                    }
                    if let error {
                        // "No speech detected" ends a silent chunk: that's an empty chunk, not a failure.
                        let ns = error as NSError
                        if ns.domain == "kAFAssistantErrorDomain" && (ns.code == 1110 || ns.code == 203) {
                            once.run { c.resume(returning: []) }
                        } else if box.task?.isCancelled == true || box.task?.state == .canceling {
                            once.run { c.resume(throwing: CancellationError()) }
                        } else {
                            once.run { c.resume(throwing: TranscriberError.failed(error.localizedDescription)) }
                        }
                    }
                }
            }
        } onCancel: {
            box.task?.cancel()
        }
    }
}
