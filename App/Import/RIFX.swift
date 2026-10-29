import Foundation

/// One chunk of an After Effects RIFX (.aep) file. Big-endian RIFF.
/// Layouts follow the reverse-engineered format documented by lottie-docs and py-aep (MIT).
final class RIFXChunk {
    let id: String
    /// For LIST chunks, the 4-char list type (e.g. "Layr", "tdgp").
    let listType: String?
    /// Raw payload (for LIST: bytes after the list type).
    let data: Data
    var children: [RIFXChunk]

    init(id: String, listType: String?, data: Data, children: [RIFXChunk]) {
        self.id = id
        self.listType = listType
        self.data = data
        self.children = children
    }

    var isList: Bool { id == "LIST" }
    /// Name used for lookups: list type for LISTs, id otherwise.
    var key: String { listType ?? id }

    func child(_ key: String) -> RIFXChunk? { children.first { $0.key == key } }
    func children(_ key: String) -> [RIFXChunk] { children.filter { $0.key == key } }

    /// NUL-terminated ASCII/UTF-8 string payload (tdmn, Utf8...).
    var string: String {
        let trimmed = data.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self)
    }

    func u8(_ o: Int) -> UInt8 { o < data.count ? data[data.startIndex + o] : 0 }
    func u16(_ o: Int) -> UInt16 { o + 2 <= data.count ? data.withUnsafeBytes { UInt16(bigEndian: $0.loadUnaligned(fromByteOffset: o, as: UInt16.self)) } : 0 }
    func u32(_ o: Int) -> UInt32 { o + 4 <= data.count ? data.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(fromByteOffset: o, as: UInt32.self)) } : 0 }
    func s32(_ o: Int) -> Int32 { Int32(bitPattern: u32(o)) }
    func f32(_ o: Int) -> Float { Float(bitPattern: u32(o)) }
    func f64(_ o: Int) -> Double {
        guard o + 8 <= data.count else { return 0 }
        return data.withUnsafeBytes { Double(bitPattern: UInt64(bigEndian: $0.loadUnaligned(fromByteOffset: o, as: UInt64.self))) }
    }
    /// Rational time stored as dividend/divisor.
    func ratio(_ o: Int, signed: Bool = true) -> Double {
        let num = signed ? Double(s32(o)) : Double(u32(o))
        let den = Double(u32(o + 4))
        return den == 0 ? 0 : num / den
    }
}

enum RIFXError: LocalizedError {
    case notAEP, truncated
    var errorDescription: String? {
        switch self {
        case .notAEP: return "This isn't an After Effects project (.aep)."
        case .truncated: return "The project file is incomplete or damaged."
        }
    }
}

enum RIFXParser {
    /// Chunks that contain sub-chunks even though they are not LISTs.
    private static let containerIDs: Set<String> = ["tdsn", "fnam", "pdnm"]
    /// LIST types that are NOT real RIFF and must be kept raw.
    private static let rawLists: Set<String> = ["btdk"]

    static func parse(_ data: Data) throws -> RIFXChunk {
        guard data.count >= 12, String(decoding: data.prefix(4), as: UTF8.self) == "RIFX" else { throw RIFXError.notAEP }
        let form = String(decoding: data[data.startIndex + 8 ..< data.startIndex + 12], as: UTF8.self)
        guard form == "Egg!" else { throw RIFXError.notAEP }
        let size = Int(data.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self)) })
        let end = min(data.count, 8 + size)
        let kids = parseChunks(data, from: 12, to: end, depth: 0)
        return RIFXChunk(id: "RIFX", listType: "Egg!", data: Data(), children: kids)
    }

    private static func parseChunks(_ data: Data, from start: Int, to end: Int, depth: Int) -> [RIFXChunk] {
        var out: [RIFXChunk] = []
        var o = start
        let base = data.startIndex
        while o + 8 <= end {
            let id = String(decoding: data[base + o ..< base + o + 4], as: UTF8.self)
            let size = Int(data.withUnsafeBytes { UInt32(bigEndian: $0.loadUnaligned(fromByteOffset: o + 4, as: UInt32.self)) })
            let bodyStart = o + 8
            let bodyEnd = min(end, bodyStart + size)
            guard bodyEnd >= bodyStart else { break }
            if id == "LIST", bodyEnd - bodyStart >= 4 {
                let type = String(decoding: data[base + bodyStart ..< base + bodyStart + 4], as: UTF8.self)
                let payload = data.subdata(in: base + bodyStart + 4 ..< base + bodyEnd)
                let kids = (rawLists.contains(type) || depth > 64) ? [] : parseChunks(data, from: bodyStart + 4, to: bodyEnd, depth: depth + 1)
                out.append(RIFXChunk(id: id, listType: type, data: payload, children: kids))
            } else {
                let payload = data.subdata(in: base + bodyStart ..< base + bodyEnd)
                let kids = containerIDs.contains(id) ? parseChunks(data, from: bodyStart, to: bodyEnd, depth: depth + 1) : []
                out.append(RIFXChunk(id: id, listType: nil, data: payload, children: kids))
            }
            // Chunks are padded to even sizes.
            o = bodyStart + size + (size & 1)
        }
        return out
    }
}
