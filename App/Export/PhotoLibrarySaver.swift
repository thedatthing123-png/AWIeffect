import Photos
import AVFoundation
import UniformTypeIdentifiers

enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case permission, unsupported, missingFile, failed
        var errorDescription: String? {
            switch self {
            case .permission: return "Photos access is disabled. Allow AWIeffect to add photos in Settings, or use Share."
            case .unsupported: return "Photos cannot store this format. Use Share to keep the original file."
            case .missingFile: return "The exported file is unavailable. Export it again before saving."
            case .failed: return "Photos could not save the file. The original is still available through Share."
            }
        }
    }

    static func resourceType(for url: URL) -> PHAssetResourceType? {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return nil }
        if type.conforms(to: .image) { return .photo }
        if type.conforms(to: .movie) { return .video }
        return nil
    }

    static func save(_ url: URL) async throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw SaveError.missingFile }
        guard let type = resourceType(for: url) else { throw SaveError.unsupported }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.permission }
        // Give this operation its own stable file, retained until Photos finishes reading it.
        let staged = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: staged)
        defer { try? FileManager.default.removeItem(at: staged) }
        do {
            try await add(staged, type: type)
        } catch {
            // A fallback conversion must never flatten a transparent MOV without the user's knowledge.
            guard type == .video, url.pathExtension.lowercased() == "mp4" else { throw error }
            let asset = AVURLAsset(url: staged)
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080),
                  session.supportedFileTypes.contains(.mp4) else { throw error }
            let compatible = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            defer { try? FileManager.default.removeItem(at: compatible) }
            session.outputURL = compatible
            session.outputFileType = .mp4
            await session.export()
            guard session.status == .completed else { throw session.error ?? error }
            try await add(compatible, type: .video)
        }
    }

    private static func add(_ url: URL, type: PHAssetResourceType) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            options.originalFilename = url.lastPathComponent
            PHAssetCreationRequest.forAsset().addResource(with: type, fileURL: url, options: options)
        }
    }
}
