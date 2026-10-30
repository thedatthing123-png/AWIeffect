import Foundation
import CoreText
import UIKit

/// Downloadable fonts (Google Fonts, all under the SIL Open Font License / Apache) registered on-device.
final class FontLibrary: ObservableObject {
    static let shared = FontLibrary()

    struct Family: Identifiable, Hashable {
        let name: String
        let style: String
        var id: String { name }
    }

    /// Popular edit / motion-design families.
    static let catalog: [Family] = [
        ("Bebas Neue", "Display"), ("Anton", "Display"), ("Montserrat", "Sans"), ("Poppins", "Sans"), ("Oswald", "Display"),
        ("Bangers", "Comic"), ("Permanent Marker", "Hand"), ("Russo One", "Display"), ("Black Ops One", "Stencil"),
        ("Orbitron", "Tech"), ("Audiowide", "Tech"), ("Bungee", "Display"), ("Righteous", "Display"), ("Teko", "Display"),
        ("Archivo Black", "Sans"), ("Rubik Glitch", "Glitch"), ("Press Start 2P", "Pixel"), ("Monoton", "Neon"),
        ("Pacifico", "Script"), ("Lobster", "Script"), ("Dancing Script", "Script"), ("Caveat", "Hand"),
        ("Creepster", "Horror"), ("Rubik Mono One", "Display"), ("Staatliches", "Display"), ("Kanit", "Sans"),
        ("Space Grotesk", "Sans"), ("Syne", "Display"), ("Unbounded", "Display"), ("Exo 2", "Tech"),
        ("Saira Stencil One", "Stencil"), ("Zen Dots", "Tech"), ("Michroma", "Tech"), ("Rajdhani", "Tech"),
        ("Shadows Into Light", "Hand"), ("Rubik Wet Paint", "Grunge"), ("Nosifer", "Horror"), ("Bowlby One SC", "Display"),
        ("Dela Gothic One", "Display"), ("Reggae One", "Japanese"), ("Mochiy Pop One", "Japanese"), ("DotGothic16", "Pixel"),
        ("Rampart One", "Japanese"), ("Train One", "Japanese"), ("Yuji Syuku", "Japanese"), ("Zen Tokyo Zoo", "Japanese"),
    ].map { Family(name: $0.0, style: $0.1) }

    @Published private(set) var installed: [String: [String]] = [:]   // family -> PostScript names
    @Published var downloading: Set<String> = []

    private var folder: URL {
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    /// Registers every downloaded or imported font (call at launch).
    func registerAll() {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var map: [String: [String]] = [:]
        for f in files where ["ttf", "otf"].contains(f.pathExtension.lowercased()) {
            let names = register(f)
            let family = f.deletingPathExtension().lastPathComponent.components(separatedBy: "__").first ?? f.lastPathComponent
            map[family, default: []] += names
        }
        DispatchQueue.main.async { self.installed = map }
    }

    @discardableResult
    private func register(_ url: URL) -> [String] {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        guard let descs = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
        return descs.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
    }

    /// Downloads a family (regular + bold when available) from Google Fonts and registers it.
    func download(_ family: String, completion: ((Bool) -> Void)? = nil) {
        guard !downloading.contains(family) else { return }
        downloading.insert(family)
        let q = family.replacingOccurrences(of: " ", with: "+")
        guard let css = URL(string: "https://fonts.googleapis.com/css2?family=\(q):wght@400;700&display=swap") else { return }
        var req = URLRequest(url: css)
        // An old user agent makes the API answer with TrueType files, which Core Text registers directly.
        req.setValue("Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            let urls = Self.fontURLs(inCSS: text)
            guard !urls.isEmpty else { self.finish(family, ok: false, completion); return }
            let group = DispatchGroup()
            var names: [String] = []
            let lock = NSLock()
            for (i, u) in urls.enumerated() {
                group.enter()
                URLSession.shared.downloadTask(with: u) { tmp, _, _ in
                    defer { group.leave() }
                    guard let tmp else { return }
                    let ext = u.pathExtension.isEmpty ? "ttf" : u.pathExtension
                    let dst = self.folder.appendingPathComponent("\(family)__\(i).\(ext)")
                    try? FileManager.default.removeItem(at: dst)
                    guard (try? FileManager.default.moveItem(at: tmp, to: dst)) != nil else { return }
                    let n = self.register(dst)
                    lock.lock(); names += n; lock.unlock()
                }.resume()
            }
            group.notify(queue: .main) {
                if !names.isEmpty { self.installed[family] = names }
                self.finish(family, ok: !names.isEmpty, completion)
            }
        }.resume()
    }

    private func finish(_ family: String, ok: Bool, _ completion: ((Bool) -> Void)?) {
        DispatchQueue.main.async {
            self.downloading.remove(family)
            completion?(ok)
        }
    }

    /// Extracts font file URLs from a Google Fonts CSS response.
    static func fontURLs(inCSS css: String) -> [URL] {
        var out: [URL] = []
        var rest = css[...]
        while let r = rest.range(of: "url(") {
            rest = rest[r.upperBound...]
            guard let end = rest.firstIndex(of: ")") else { break }
            let s = rest[..<end].trimmingCharacters(in: CharacterSet(charactersIn: "'\" "))
            if let u = URL(string: s), !out.contains(u) { out.append(u) }
            rest = rest[end...]
        }
        return out
    }

    /// Imports a user font file (.ttf/.otf from Files).
    func importFont(from url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let dst = folder.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent)__0.\(url.pathExtension)")
        try? FileManager.default.removeItem(at: dst)
        guard (try? FileManager.default.copyItem(at: url, to: dst)) != nil else { return false }
        let names = register(dst)
        if !names.isEmpty { installed[url.deletingPathExtension().lastPathComponent] = names }
        return !names.isEmpty
    }
}
