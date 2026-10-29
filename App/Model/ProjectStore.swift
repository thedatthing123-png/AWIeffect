import Foundation
import UIKit

struct ProjectSummary: Identifiable, Equatable {
    var id: UUID
    var name: String
    var width: Int
    var height: Int
    var fps: Double
    var duration: Double
    var modifiedAt: Date
    var thumbnail: UIImage?
}

/// Stores projects as folders in Documents/Projects/<uuid>/ with project.json, media/, versions/, thumb.jpg.
/// Projects live in the Files app (UIFileSharingEnabled) so they can be backed up outside the app.
final class ProjectStore {
    static let shared = ProjectStore()

    let root: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Max number of version snapshots kept per project.
    static let maxVersions = 30

    init(root: URL? = nil) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.root = root ?? docs.appendingPathComponent("Projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func folder(for id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    func mediaFolder(for id: UUID) -> URL { folder(for: id).appendingPathComponent("media", isDirectory: true) }
    private func versionsFolder(for id: UUID) -> URL { folder(for: id).appendingPathComponent("versions", isDirectory: true) }
    private func jsonURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("project.json") }
    private func thumbURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("thumb.jpg") }

    func save(_ project: Project, snapshotVersion: Bool = false) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: mediaFolder(for: project.id), withIntermediateDirectories: true)
        let data = try encoder.encode(project)
        // Atomic write so a crash mid-save never corrupts the project.
        try data.write(to: jsonURL(for: project.id), options: .atomic)
        if snapshotVersion { try snapshot(data, for: project.id) }
    }

    private func snapshot(_ data: Data, for id: UUID) throws {
        let fm = FileManager.default
        let dir = versionsFolder(for: id)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        try data.write(to: dir.appendingPathComponent("\(stamp).json"), options: .atomic)
        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if files.count > Self.maxVersions {
            for f in files.prefix(files.count - Self.maxVersions) { try? fm.removeItem(at: f) }
        }
    }

    func versions(for id: UUID) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: versionsFolder(for: id), includingPropertiesForKeys: nil)) ?? []
        return files.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func loadVersion(_ url: URL) throws -> Project {
        try decoder.decode(Project.self, from: Data(contentsOf: url))
    }

    func load(_ id: UUID) throws -> Project {
        try decoder.decode(Project.self, from: Data(contentsOf: jsonURL(for: id)))
    }

    func saveThumbnail(_ image: UIImage, for id: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: thumbURL(for: id), options: .atomic)
    }

    func list() -> [ProjectSummary] {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap { dir -> ProjectSummary? in
            guard let id = UUID(uuidString: dir.lastPathComponent), let p = try? load(id) else { return nil }
            let thumb = UIImage(contentsOfFile: thumbURL(for: id).path)
            return ProjectSummary(id: p.id, name: p.name, width: p.width, height: p.height, fps: p.fps,
                                  duration: p.duration, modifiedAt: p.modifiedAt, thumbnail: thumb)
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: folder(for: id))
    }

    func duplicate(_ id: UUID) throws -> Project {
        var p = try load(id)
        let oldMedia = mediaFolder(for: id)
        p.id = UUID()
        p.name += " copy"
        p.createdAt = Date()
        p.modifiedAt = Date()
        try save(p)
        let fm = FileManager.default
        for f in (try? fm.contentsOfDirectory(at: oldMedia, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.copyItem(at: f, to: mediaFolder(for: p.id).appendingPathComponent(f.lastPathComponent))
        }
        return p
    }

    /// Copies media into the project and returns the stored file name.
    func importMedia(data: Data, ext: String, into projectID: UUID) throws -> String {
        try FileManager.default.createDirectory(at: mediaFolder(for: projectID), withIntermediateDirectories: true)
        let name = UUID().uuidString + "." + ext
        try data.write(to: mediaFolder(for: projectID).appendingPathComponent(name), options: .atomic)
        return name
    }

    func mediaURL(_ fileName: String, projectID: UUID) -> URL {
        mediaFolder(for: projectID).appendingPathComponent(fileName)
    }
}
