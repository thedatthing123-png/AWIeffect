import Foundation

/// Minimal streaming ZIP (store method, no compression): PNG sequences and project backups open in Files and on any
/// computer. Entries are streamed from disk, so large backups never sit in memory. Limit: 4 GB (no ZIP64).
enum ZipArchive {
    enum Failure: LocalizedError {
        case tooLarge, notAZip, unsupported, unsafePath
        var errorDescription: String? {
            switch self {
            case .tooLarge: return "The archive is larger than 4 GB. Export a shorter range or fewer projects."
            case .notAZip: return "That file isn't a readable ZIP archive."
            case .unsupported: return "This ZIP uses compression AWIeffect can't read. Use a backup made by AWIeffect."
            case .unsafePath: return "The archive contains an unsafe file path."
            }
        }
    }

    private static let table: [UInt32] = (0..<256).map { n -> UInt32 in
        var c = UInt32(n)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        return c
    }

    static func crc32<D: DataProtocol>(_ data: D, start: UInt32 = 0) -> UInt32 {
        var c = start ^ 0xFFFF_FFFF
        for region in data.regions {
            for b in region { c = table[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
        }
        return c ^ 0xFFFF_FFFF
    }

    /// Writes entries one by one to `url`.
    final class Writer {
        private let out: FileHandle
        private var central = Data()
        private var count = 0
        private var offset: UInt64 = 0
        private var finished = false

        init(url: URL) throws {
            try? FileManager.default.removeItem(at: url)
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            out = try FileHandle(forWritingTo: url)
        }
        deinit { if !finished { try? out.close() } }

        func add(_ name: String, data: Data) throws {
            try header(name, crc: ZipArchive.crc32(data), size: UInt64(data.count))
            try write(data)
        }

        func add(_ name: String, file: URL) throws {
            let input = try FileHandle(forReadingFrom: file)
            defer { try? input.close() }
            var crc: UInt32 = 0, size: UInt64 = 0
            while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty {
                crc = ZipArchive.crc32(chunk, start: crc); size += UInt64(chunk.count)
            }
            try header(name, crc: crc, size: size)
            try input.seek(toOffset: 0)
            while let chunk = try input.read(upToCount: 1 << 20), !chunk.isEmpty { try write(chunk) }
        }

        func finish() throws {
            let cdOffset = offset
            try write(central)
            guard offset <= UInt64(UInt32.max), count <= Int(UInt16.max) else { throw Failure.tooLarge }
            var end = Data()
            end.u32(0x0605_4B50); end.u16(0); end.u16(0); end.u16(UInt16(count)); end.u16(UInt16(count))
            end.u32(UInt32(central.count)); end.u32(UInt32(cdOffset)); end.u16(0)
            try write(end)
            try out.synchronize(); try out.close(); finished = true
        }

        private func write(_ d: Data) throws { try out.write(contentsOf: d); offset += UInt64(d.count) }

        private func header(_ name: String, crc: UInt32, size: UInt64) throws {
            guard size < UInt64(UInt32.max), offset < UInt64(UInt32.max) else { throw Failure.tooLarge }
            let n = Data(name.utf8)
            let (time, date) = Writer.dosStamp(Date())
            var h = Data()
            h.u32(0x0403_4B50); h.u16(20); h.u16(0x0800); h.u16(0); h.u16(time); h.u16(date)
            h.u32(crc); h.u32(UInt32(size)); h.u32(UInt32(size)); h.u16(UInt16(n.count)); h.u16(0); h.append(n)
            var c = Data()
            c.u32(0x0201_4B50); c.u16(20); c.u16(20); c.u16(0x0800); c.u16(0); c.u16(time); c.u16(date)
            c.u32(crc); c.u32(UInt32(size)); c.u32(UInt32(size)); c.u16(UInt16(n.count)); c.u16(0); c.u16(0)
            c.u16(0); c.u16(0); c.u32(0); c.u32(UInt32(offset)); c.append(n)
            central.append(c); count += 1
            try write(h)
        }

        static func dosStamp(_ d: Date) -> (UInt16, UInt16) {
            let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute, .second], from: d)
            let time = UInt16((c.hour ?? 0) << 11 | (c.minute ?? 0) << 5 | (c.second ?? 0) / 2)
            let date = UInt16(max(0, (c.year ?? 1980) - 1980) << 9 | (c.month ?? 1) << 5 | (c.day ?? 1))
            return (time, date)
        }
    }

    struct Entry: Equatable { var name: String; var size: UInt64; var dataOffset: UInt64; var crc: UInt32 }

    /// Lists stored entries (from the central directory).
    static func entries(of url: URL) throws -> [Entry] {
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        let length = try h.seekToEnd()
        guard length >= 22 else { throw Failure.notAZip }
        let tailLength = min(length, 22 + 65_535)
        try h.seek(toOffset: length - tailLength)
        let tail = try h.read(upToCount: Int(tailLength)) ?? Data()
        guard let eocd = (0...(tail.count - 22)).reversed().first(where: { tail.le32($0) == 0x0605_4B50 }) else { throw Failure.notAZip }
        let total = Int(tail.le16(eocd + 10)), cdSize = UInt64(tail.le32(eocd + 12)), cdOffset = UInt64(tail.le32(eocd + 16))
        guard cdOffset + cdSize <= length else { throw Failure.notAZip }
        try h.seek(toOffset: cdOffset)
        let cd = try h.read(upToCount: Int(cdSize)) ?? Data()
        var out: [Entry] = []
        var i = 0
        for _ in 0..<total {
            guard i + 46 <= cd.count, cd.le32(i) == 0x0201_4B50 else { throw Failure.notAZip }
            let method = cd.le16(i + 10), crc = cd.le32(i + 16), csize = UInt64(cd.le32(i + 20)), usize = UInt64(cd.le32(i + 24))
            let nl = Int(cd.le16(i + 28)), el = Int(cd.le16(i + 30)), cl = Int(cd.le16(i + 32)), local = UInt64(cd.le32(i + 42))
            guard i + 46 + nl <= cd.count else { throw Failure.notAZip }
            let name = String(decoding: cd[(cd.startIndex + i + 46)..<(cd.startIndex + i + 46 + nl)], as: UTF8.self)
            i += 46 + nl + el + cl
            if name.hasSuffix("/") { continue }
            guard method == 0, csize == usize else { throw Failure.unsupported }
            try h.seek(toOffset: local)
            let lh = try h.read(upToCount: 30) ?? Data()
            guard lh.count == 30, lh.le32(0) == 0x0403_4B50 else { throw Failure.notAZip }
            let dataOffset = local + 30 + UInt64(lh.le16(26)) + UInt64(lh.le16(28))
            guard dataOffset + usize <= length else { throw Failure.notAZip }
            out.append(Entry(name: name, size: usize, dataOffset: dataOffset, crc: crc))
        }
        return out
    }

    /// Extracts every entry below `folder` (paths are checked so nothing escapes it).
    static func extract(_ url: URL, to folder: URL) throws {
        let list = try entries(of: url)
        let h = try FileHandle(forReadingFrom: url)
        defer { try? h.close() }
        let fm = FileManager.default
        for e in list {
            let parts = e.name.split(separator: "/")
            guard !parts.isEmpty, !e.name.hasPrefix("/"), !parts.contains(where: { $0 == ".." || $0 == "." || $0.contains("\\") }) else { throw Failure.unsafePath }
            let dest = parts.reduce(folder) { $0.appendingPathComponent(String($1)) }
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard fm.createFile(atPath: dest.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
            let out = try FileHandle(forWritingTo: dest)
            defer { try? out.close() }
            try h.seek(toOffset: e.dataOffset)
            var remaining = e.size, crc: UInt32 = 0
            while remaining > 0 {
                let chunk = try h.read(upToCount: Int(min(remaining, 1 << 20))) ?? Data()
                guard !chunk.isEmpty else { throw Failure.notAZip }
                crc = crc32(chunk, start: crc)
                try out.write(contentsOf: chunk); remaining -= UInt64(chunk.count)
            }
            guard crc == e.crc else { throw Failure.notAZip }
        }
    }
}

private extension Data {
    mutating func u16(_ v: UInt16) { var x = v.littleEndian; append(Data(bytes: &x, count: 2)) }
    mutating func u32(_ v: UInt32) { var x = v.littleEndian; append(Data(bytes: &x, count: 4)) }
    func le16(_ i: Int) -> UInt16 {
        let s = startIndex + i
        return UInt16(self[s]) | UInt16(self[s + 1]) << 8
    }
    func le32(_ i: Int) -> UInt32 {
        let s = startIndex + i
        return UInt32(self[s]) | UInt32(self[s + 1]) << 8 | UInt32(self[s + 2]) << 16 | UInt32(self[s + 3]) << 24
    }
}
