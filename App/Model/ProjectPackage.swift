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
        let fm = FileManager.default
        let media = store.mediaFolder(for: project.id)
        var files: [(String, URL)] = []
        for name in (try? fm.contentsOfDirectory(atPath: media.path)) ?? [] where !name.hasPrefix(".") {
            let url = media.appendingPathComponent(name)
            if (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true { files.append(("media/" + name, url)) }
        }
        func usedLUTs(_ p: Project) -> Set<String> {
            var names = Set(p.layers.flatMap(\.effects).compactMap { $0.text?["lut"] })
            for child in p.precomps { names.formUnion(usedLUTs(child)) }
            return names
        }
        for name in usedLUTs(project).sorted() {
            files.append(("luts/" + name, LUTLibrary.folder.appendingPathComponent(name)))
        }
        let dir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = project.name.replacingOccurrences(of: "/", with: "-")
        let url = dir.appendingPathComponent("\(safe.isEmpty ? "Project" : safe).awi")
        guard fm.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let out = try FileHandle(forWritingTo: url)
        var success = false
        defer { try? out.close(); if !success { try? fm.removeItem(at: dir) } }
        func u32(_ v: Int) throws {
            guard let value = UInt32(exactly: v) else { throw Failure.notAPackage }
            var x = value.littleEndian; try out.write(contentsOf: Data(bytes: &x, count: 4))
        }
        func header(_ name: String, _ length: UInt64) throws {
            let n = Data(name.utf8); try u32(n.count); try out.write(contentsOf: n)
            var x = length.littleEndian; try out.write(contentsOf: Data(bytes: &x, count: 8))
        }
        try out.write(contentsOf: Data(magic)); try u32(files.count + 1)
        let json = try coder().0.encode(project)
        try header("project.json", UInt64(json.count)); try out.write(contentsOf: json)
        // Stream video/drawing assets rather than retaining the whole project twice in RAM.
        for (name, source) in files {
            let input = try FileHandle(forReadingFrom: source)
            defer { try? input.close() }
            let length = try input.seekToEnd(); try input.seek(toOffset: 0)
            try header(name, length)
            var remaining = length
            while remaining > 0 {
                let data = try input.read(upToCount: Int(min(remaining, 1_048_576))) ?? Data()
                guard !data.isEmpty else { throw Failure.notAPackage }
                try out.write(contentsOf: data); remaining -= UInt64(data.count)
            }
        }
        try out.synchronize(); try out.close(); success = true
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
            i += 8; return Int(exactly: v)
        }
        guard let count = u32(), count <= (data.count - i) / 12 else { throw Failure.notAPackage }
        var project: Project?
        var files: [(String, Data)] = []
        for _ in 0..<count {
            guard let nl = u32(), nl <= data.count - i else { throw Failure.notAPackage }
            let name = String(decoding: data[i..<(i + nl)], as: UTF8.self); i += nl
            guard let dl = u64(), dl <= data.count - i else { throw Failure.notAPackage }
            let body = data[i..<(i + dl)]; i += dl
            if name == "project.json" {
                guard project == nil else { throw Failure.notAPackage }
                project = try coder().1.decode(Project.self, from: body)
            } else { files.append((name, body)) }
        }
        guard i == data.count else { throw Failure.notAPackage }
        guard var p = project else { throw Failure.missingProject }
        p.id = UUID()
        p.modifiedAt = Date()
        let media = store.mediaFolder(for: p.id)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        var success = false
        defer { if !success { try? FileManager.default.removeItem(at: store.folder(for: p.id)) } }
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
        success = true
        return p
    }
}
