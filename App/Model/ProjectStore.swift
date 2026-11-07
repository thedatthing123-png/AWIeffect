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

/// Lightweight card data written next to project.json on every save, so the project list never decodes whole
/// projects (big projects made the home screen slow).
struct ProjectMeta: Codable, Equatable {
    var id: UUID
    var name: String
    var width: Int
    var height: Int
    var fps: Double
    var duration: Double
    var modifiedAt: Date
    init(_ p: Project) {
        id = p.id; name = p.name; width = p.width; height = p.height; fps = p.fps; duration = p.duration; modifiedAt = p.modifiedAt
    }
}

/// A project in Recently Deleted (restorable for `ProjectStore.deletedRetention`).
struct DeletedProject: Identifiable, Equatable {
    var summary: ProjectSummary
    var deletedAt: Date
    var id: UUID { summary.id }
}

/// Stores projects as folders in Documents/Projects/<uuid>/ with project.json, media/, versions/, thumb.jpg.
/// Projects live in the Files app (UIFileSharingEnabled) so they can be backed up outside the app.
final class ProjectStore {
    static let shared = ProjectStore()

    private let ioLock = NSRecursiveLock()
    let root: URL
    private(set) var recoveredVersions: [UUID: String] = [:]
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
    private func metaURL(for id: UUID) -> URL { folder(for: id).appendingPathComponent("meta.json") }
    /// Deleted projects wait here (hidden from the list) until restored or older than `deletedRetention`.
    var deletedRoot: URL { root.appendingPathComponent(".RecentlyDeleted", isDirectory: true) }
    private func deletedFolder(for id: UUID) -> URL { deletedRoot.appendingPathComponent(id.uuidString, isDirectory: true) }
    static let deletedRetention: TimeInterval = 30 * 24 * 3600

    func save(_ project: Project, snapshotVersion: Bool = false) throws {
        ioLock.lock(); defer { ioLock.unlock() }
        let fm = FileManager.default
        try fm.createDirectory(at: mediaFolder(for: project.id), withIntermediateDirectories: true)
        let data = try encoder.encode(project)
        // Atomic write so a crash mid-save never corrupts the project.
        try data.write(to: jsonURL(for: project.id), options: .atomic)
        writeMeta(ProjectMeta(project))
        if snapshotVersion { try snapshot(data, for: project.id) }
    }

    private func writeMeta(_ meta: ProjectMeta) {
        if let d = try? encoder.encode(meta) { try? d.write(to: metaURL(for: meta.id), options: .atomic) }
    }

    /// Card data: meta.json when it's current, else the full project once (older projects), which then writes it.
    private func meta(for id: UUID, in dir: URL) -> ProjectMeta? {
        let fm = FileManager.default
        let metaFile = dir.appendingPathComponent("meta.json"), json = dir.appendingPathComponent("project.json")
        func modified(_ u: URL) -> Date? { (try? fm.attributesOfItem(atPath: u.path))?[.modificationDate] as? Date }
        if let m = try? decoder.decode(ProjectMeta.self, from: Data(contentsOf: metaFile)), m.id == id,
           let mt = modified(metaFile), let jt = modified(json), mt >= jt.addingTimeInterval(-1) {
            return m
        }
        guard let data = try? Data(contentsOf: json), let p = try? decoder.decode(Project.self, from: data) else {
            // Damaged project.json: fall back to the normal recovery path.
            return (try? load(id)).map { ProjectMeta($0) }
        }
        var m = ProjectMeta(p); m.id = id
        if let d = try? encoder.encode(m) { try? d.write(to: metaFile, options: .atomic) }
        return m
    }

    /// Restores a saved version. The current state is kept as a new version first, so restoring never loses work.
    func restoreVersion(_ url: URL, for id: UUID) throws {
        ioLock.lock(); defer { ioLock.unlock() }
        if let current = try? Data(contentsOf: jsonURL(for: id)) { try snapshot(current, for: id) }
        var v = try loadVersion(url)
        v.id = id
        v.modifiedAt = Date()
        try save(v)
    }

    private func snapshot(_ data: Data, for id: UUID) throws {
        let fm = FileManager.default
        let dir = versionsFolder(for: id)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let stamp = formatter.string(from: now).replacingOccurrences(of: ":", with: "-") + "-" + String(format: "%020.6f", now.timeIntervalSince1970) + "-" + UUID().uuidString
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
        ioLock.lock(); defer { ioLock.unlock() }
        return try decoder.decode(Project.self, from: Data(contentsOf: url))
    }

    func load(_ id: UUID) throws -> Project {
        ioLock.lock(); defer { ioLock.unlock() }
        do { return try decoder.decode(Project.self, from: Data(contentsOf: jsonURL(for: id))) }
        catch {
            let originalError = error
            for version in versions(for: id) {
                guard var recovered = try? loadVersion(version) else { continue }
                // Preserve the damaged file before a later autosave writes the recovered version.
                let source = jsonURL(for: id)
                if FileManager.default.fileExists(atPath: source.path) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
                    let stamp = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                    let backup = folder(for: id).appendingPathComponent("project-corrupt-\(stamp).json")
                    if !FileManager.default.fileExists(atPath: backup.path) { try FileManager.default.copyItem(at: source, to: backup) }
                }
                recovered.id = id
                recoveredVersions[id] = version.lastPathComponent
                return recovered
            }
            throw originalError
        }
    }

    func saveThumbnail(_ image: UIImage, for id: UUID) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: thumbURL(for: id), options: .atomic)
    }

    func list() -> [ProjectSummary] {
        ioLock.lock(); defer { ioLock.unlock() }
        purgeDeleted()
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap { dir -> ProjectSummary? in
            guard let id = UUID(uuidString: dir.lastPathComponent), let m = meta(for: id, in: dir) else { return nil }
            return summary(m, thumb: dir.appendingPathComponent("thumb.jpg"))
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func summary(_ m: ProjectMeta, thumb: URL) -> ProjectSummary {
        ProjectSummary(id: m.id, name: m.name, width: m.width, height: m.height, fps: m.fps,
                       duration: m.duration, modifiedAt: m.modifiedAt, thumbnail: UIImage(contentsOfFile: thumb.path))
    }

    /// Moves a project to Recently Deleted (kept `deletedRetention`, restorable from the home screen).
    func delete(_ id: UUID) {
        ioLock.lock(); defer { ioLock.unlock() }
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder(for: id).path) else { return }
        try? fm.createDirectory(at: deletedRoot, withIntermediateDirectories: true)
        let dest = deletedFolder(for: id)
        try? fm.removeItem(at: dest)
        do {
            try fm.moveItem(at: folder(for: id), to: dest)
            try? Data(ISO8601DateFormatter().string(from: Date()).utf8).write(to: dest.appendingPathComponent("deleted-at"), options: .atomic)
        } catch {
            NSLog("AWIeffect: couldn't move project to Recently Deleted: \(error)")
        }
    }

    func deletedProjects() -> [DeletedProject] {
        ioLock.lock(); defer { ioLock.unlock() }
        let dirs = (try? FileManager.default.contentsOfDirectory(at: deletedRoot, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap { dir -> DeletedProject? in
            guard let id = UUID(uuidString: dir.lastPathComponent) else { return nil }
            let m = (try? decoder.decode(ProjectMeta.self, from: Data(contentsOf: dir.appendingPathComponent("meta.json"))))
                ?? (try? decoder.decode(Project.self, from: Data(contentsOf: dir.appendingPathComponent("project.json")))).map { ProjectMeta($0) }
            guard var meta = m else { return nil }
            meta.id = id
            return DeletedProject(summary: summary(meta, thumb: dir.appendingPathComponent("thumb.jpg")), deletedAt: deletedDate(dir))
        }
        .sorted { $0.deletedAt > $1.deletedAt }
    }

    private func deletedDate(_ dir: URL) -> Date {
        if let s = try? String(contentsOf: dir.appendingPathComponent("deleted-at"), encoding: .utf8),
           let d = ISO8601DateFormatter().date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
        return ((try? FileManager.default.attributesOfItem(atPath: dir.path))?[.modificationDate] as? Date) ?? Date()
    }

    /// Puts a deleted project back in the project list.
    func restoreDeleted(_ id: UUID) throws {
        ioLock.lock(); defer { ioLock.unlock() }
        let fm = FileManager.default
        let src = deletedFolder(for: id)
        guard !fm.fileExists(atPath: folder(for: id).path) else { throw CocoaError(.fileWriteFileExists) }
        try fm.moveItem(at: src, to: folder(for: id))
        try? fm.removeItem(at: folder(for: id).appendingPathComponent("deleted-at"))
    }

    /// Removes a project from Recently Deleted for good.
    func deletePermanently(_ id: UUID) {
        ioLock.lock(); defer { ioLock.unlock() }
        try? FileManager.default.removeItem(at: deletedFolder(for: id))
    }

    /// Drops Recently Deleted projects older than the retention period.
    func purgeDeleted(now: Date = Date()) {
        ioLock.lock(); defer { ioLock.unlock() }
        let dirs = (try? FileManager.default.contentsOfDirectory(at: deletedRoot, includingPropertiesForKeys: nil)) ?? []
        for dir in dirs where now.timeIntervalSince(deletedDate(dir)) > Self.deletedRetention {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    func duplicate(_ id: UUID) throws -> Project {
        ioLock.lock(); defer { ioLock.unlock() }
        var p = try load(id)
        let oldMedia = mediaFolder(for: id)
        p.id = UUID()
        p.name += " copy"
        p.createdAt = Date()
        p.modifiedAt = Date()
        let fm = FileManager.default
        var success = false
        defer { if !success { try? fm.removeItem(at: folder(for: p.id)) } }
        try save(p)
        let files = try fm.contentsOfDirectory(at: oldMedia, includingPropertiesForKeys: nil)
        for f in files { try fm.copyItem(at: f, to: mediaFolder(for: p.id).appendingPathComponent(f.lastPathComponent)) }
        success = true
        return p
    }

    /// Copies media into the project and returns the stored file name.
    func importMedia(data: Data, ext: String, into projectID: UUID) throws -> String {
        try FileManager.default.createDirectory(at: mediaFolder(for: projectID), withIntermediateDirectories: true)
        let name = UUID().uuidString + "." + ext
        try data.write(to: mediaFolder(for: projectID).appendingPathComponent(name), options: .atomic)
        return name
    }

    /// Copies a media file into the project on disk (streamed by the file system, never loaded into memory).
    func importMedia(fileAt source: URL, ext: String, into projectID: UUID) throws -> String {
        let fm = FileManager.default
        try fm.createDirectory(at: mediaFolder(for: projectID), withIntermediateDirectories: true)
        let name = UUID().uuidString + "." + ext
        let dest = mediaFolder(for: projectID).appendingPathComponent(name)
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        try fm.copyItem(at: source, to: dest)
        return name
    }

    func mediaURL(_ fileName: String, projectID: UUID) -> URL {
        mediaFolder(for: projectID).appendingPathComponent(fileName)
    }
}
