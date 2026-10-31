import Foundation

/// One-file project sharing (.awi): the project JSON plus every media file it uses and its LUTs, so a friend's
/// AWIeffect opens it exactly the same. Format: "AWIPKG1" + entries of (name length, name, data length, data).
enum ProjectPackage {
    static let magic = Array("AWIPKG1".utf8)

    enum Failure: LocalizedError {
        case notAPackage, missingProject
        var errorDescription: String? {
            switch self {
            case .notAPackage: return "That file isn't an AWIeffect project."
            case .missingProject: return "The project data is missing from this file."
            }
        }
    }

    private static func coder() -> (JSONEncoder, JSONDecoder) {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return (e, d)
    }

    /// Writes `<name>.awi` to a temporary folder and returns it (for the share sheet).
    static func export(_ project: Project, store: ProjectStore = .shared) throws -> URL {
        var entries: [(String, Data)] = []
        entries.append(("project.json", try coder().0.encode(project)))
        let media = store.mediaFolder(for: project.id)
        for name in (try? FileManager.default.contentsOfDirectory(atPath: media.path)) ?? [] where !name.hasPrefix(".") {
            if let d = try? Data(contentsOf: media.appendingPathComponent(name)) { entries.append(("media/" + name, d)) }
        }
        // LUTs used by any grade in the project (they live app-wide, so carry them along).
        let luts = Set((project.layers + project.precomps.flatMap(\.layers)).flatMap(\.effects).compactMap { $0.text?["lut"] })
        for name in luts {
            if let d = try? Data(contentsOf: LUTLibrary.folder.appendingPathComponent(name)) { entries.append(("luts/" + name, d)) }
        }
        var out = Data(magic)
        func u32(_ v: Int) { var x = UInt32(v).littleEndian; out.append(Data(bytes: &x, count: 4)) }
        func u64(_ v: Int) { var x = UInt64(v).littleEndian; out.append(Data(bytes: &x, count: 8)) }
        u32(entries.count)
        for (name, data) in entries {
            let n = Data(name.utf8)
            u32(n.count); out.append(n)
            u64(data.count); out.append(data)
        }
        let safe = project.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).awi")
        try? FileManager.default.removeItem(at: url)
        try out.write(to: url, options: .atomic)
        return url
    }

    static func isPackage(_ data: Data) -> Bool { data.count > magic.count && Array(data.prefix(magic.count)) == magic }

    /// Reads a package into the store as a new project (new id, so it never overwrites one of yours).
    static func importPackage(_ data: Data, store: ProjectStore = .shared) throws -> Project {
        guard isPackage(data) else { throw Failure.notAPackage }
        var i = magic.count
        func u32() -> Int? {
            guard i + 4 <= data.count else { return nil }
            let v = data[i..<(i + 4)].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
            i += 4; return Int(v)
        }
        func u64() -> Int? {
            guard i + 8 <= data.count else { return nil }
            let v = data[i..<(i + 8)].withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
            i += 8; return Int(v)
        }
        guard let count = u32() else { throw Failure.notAPackage }
        var project: Project?
        var files: [(String, Data)] = []
        for _ in 0..<count {
            guard let nl = u32(), i + nl <= data.count else { throw Failure.notAPackage }
            let name = String(decoding: data[i..<(i + nl)], as: UTF8.self); i += nl
            guard let dl = u64(), i + dl <= data.count else { throw Failure.notAPackage }
            let body = data[i..<(i + dl)]; i += dl
            if name == "project.json" { project = try coder().1.decode(Project.self, from: Data(body)) } else { files.append((name, Data(body))) }
        }
        guard var p = project else { throw Failure.missingProject }
        p.id = UUID()
        p.modifiedAt = Date()
        let media = store.mediaFolder(for: p.id)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        for (name, body) in files {
            let file = (name as NSString).lastPathComponent
            guard !file.isEmpty, !file.contains("..") else { continue }
            if name.hasPrefix("media/") { try body.write(to: media.appendingPathComponent(file), options: .atomic) }
            else if name.hasPrefix("luts/") {
                let dest = LUTLibrary.folder.appendingPathComponent(file)
                if !FileManager.default.fileExists(atPath: dest.path) { try? body.write(to: dest, options: .atomic) }
            }
        }
        try store.save(p)
        return p
    }
}
