import Foundation
import Network
import SwiftUI
import UIKit

/// AI Link backend: a small HTTP server on the local Wi-Fi (off by default) that lets a paired assistant read and
/// edit the open project, see the effect catalog, render frames to check its work, upload media and run actions.
/// Every request needs the pairing code shown in Settings (header `X-AWI-Code`).
///
/// Endpoints (JSON unless noted):
///   GET  /info                       app + open project summary
///   GET  /catalog                    effects (params, ranges), blend modes, presets, title styles, text animations
///   GET  /project                    the open project (full JSON)
///   PUT  /project                    replace the open project (one undo step)
///   POST /render?t=1.5&size=720      PNG of the frame at t seconds (max side `size`)
///   POST /media?ext=png              upload a file (body = bytes) -> {"file": name}
///   POST /action                     {"name": "...", ...} undo / redo / seek / select / play / pause / cutoutSubject
@MainActor
final class AILink: ObservableObject {
    static let shared = AILink()
    @Published private(set) var running = false
    @Published private(set) var address = ""
    @Published private(set) var code = String(format: "%06d", Int.random(in: 0...999_999))
    @Published private(set) var lastRequest = ""
    static let port: UInt16 = 8765

    /// The editor that's open right now (set by EditorView).
    weak var editor: EditorState? {
        didSet { if editor != nil { AILinkRelay.shared.resume() } }
    }
    private var listener: NWListener?

    func setEnabled(_ on: Bool) { on ? start() : stop() }

    func newCode() { code = String(format: "%06d", Int.random(in: 0...999_999)) }

    private func start() {
        guard listener == nil, let port = NWEndpoint.Port(rawValue: Self.port), let l = try? NWListener(using: .tcp, on: port) else { return }
        l.newConnectionHandler = { [weak self] conn in Task { @MainActor in self?.serve(conn) } }
        l.stateUpdateHandler = { [weak self] st in
            Task { @MainActor in
                guard let self else { return }
                if case .ready = st { self.running = true; self.address = "\(Self.wifiAddress() ?? "?"):\(Self.port)" }
                if case .failed = st { self.stop() }
            }
        }
        l.start(queue: .main)
        listener = l
    }

    private func stop() {
        listener?.cancel(); listener = nil
        running = false; address = ""
    }

    // MARK: HTTP

    private func serve(_ conn: NWConnection) {
        conn.start(queue: .main)
        var buffer = Data()
        func receive() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let data { buffer.append(data) }
                    if let req = HTTPRequest(buffer) {
                        let res = self.handle(req)
                        conn.send(content: res.bytes, completion: .contentProcessed { _ in conn.cancel() })
                    } else if done || err != nil || buffer.count > 400 << 20 {
                        conn.cancel()
                    } else {
                        receive()
                    }
                }
            }
        }
        receive()
    }

    /// Same handler for the online relay.
    func respond(_ r: HTTPRequest) -> HTTPResponse { handle(r) }

    private func handle(_ r: HTTPRequest) -> HTTPResponse {
        lastRequest = "\(r.method) \(r.path)"
        guard r.headers["x-awi-code"] == code else { return .json(["error": "wrong or missing pairing code (X-AWI-Code)"], status: 401) }
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        switch (r.method, r.path) {
        case ("GET", "/info"):
            var info: [String: Any] = ["app": "AWIeffect", "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "?",
                                       "effects": EffectRegistry.all.count, "projectOpen": editor != nil]
            if let e = editor {
                info["project"] = ["name": e.project.name, "width": e.project.width, "height": e.project.height, "fps": e.project.fps,
                                   "duration": e.project.duration, "layers": e.project.layers.count, "time": e.currentTime,
                                   "selected": e.selectedLayerID?.uuidString ?? ""]
            }
            return .json(info)
        case ("GET", "/catalog"):
            return .json(Self.catalog())
        case ("GET", "/project"):
            guard let e = editor, let d = try? enc.encode(e.project) else { return .noProject }
            return HTTPResponse(status: 200, type: "application/json", body: d)
        case ("PUT", "/project"):
            guard let e = editor else { return .noProject }
            do {
                var p = try dec.decode(Project.self, from: r.body)
                p.id = e.project.id     // edits stay in the open project (and its media folder)
                e.mutate("AI Link Edit") { $0 = p }
                e.redrawToken += 1
                return .json(["ok": true, "layers": p.layers.count])
            } catch {
                return .json(["error": "project JSON didn't decode: \(error)"], status: 400)
            }
        case ("POST", "/render"):
            guard let e = editor, let rr = Renderer.shared else { return .noProject }
            if UIApplication.shared.applicationState == .background {
                return .json(["error": "AWIeffect is in the background: iPhone blocks the graphics chip there. Edits still work; come back to the app to preview frames."], status: 409)
            }
            let t = Double(r.query["t"] ?? "") ?? e.currentTime
            let size = Double(r.query["size"] ?? "") ?? 720
            let pid = e.project.id, store = e.store
            guard let img = rr.renderImage(project: e.project, time: t, maxDimension: size, mediaURL: { store.mediaURL($0, projectID: pid) }),
                  let png = img.pngData() else { return .json(["error": "render failed"], status: 500) }
            return HTTPResponse(status: 200, type: "image/png", body: png)
        case ("POST", "/media"):
            guard let e = editor else { return .noProject }
            let ext = (r.query["ext"] ?? "png").filter { $0.isLetter || $0.isNumber }
            guard !r.body.isEmpty, let name = try? e.store.importMedia(data: r.body, ext: ext, into: e.project.id) else {
                return .json(["error": "upload failed"], status: 400)
            }
            return .json(["file": name])
        case ("POST", "/action"):
            guard let e = editor else { return .noProject }
            guard let obj = (try? JSONSerialization.jsonObject(with: r.body)) as? [String: Any], let name = obj["name"] as? String else {
                return .json(["error": "body must be {\"name\": ...}"], status: 400)
            }
            return action(name, obj, e)
        default:
            if let res = handleEditor(r) { return res }
            return .json(["error": "unknown endpoint \(r.method) \(r.path)"], status: 404)
        }
    }

    private func action(_ name: String, _ a: [String: Any], _ e: EditorState) -> HTTPResponse {
        switch name {
        case "undo": e.undo()
        case "redo": e.redo()
        case "seek": e.seek(a["time"] as? Double ?? 0)
        case "select": e.select((a["layer"] as? String).flatMap(UUID.init(uuidString:)))
        case "play": if !e.isPlaying { e.togglePlay() }
        case "pause": e.pause()
        case "cutoutSubject":
            // AI subject cutout on an image / video layer (same as Remove BG → Object).
            guard let id = (a["layer"] as? String).flatMap(UUID.init(uuidString:)) else { return .json(["error": "needs layer"], status: 400) }
            e.select(id)
            var s = e.selectedLayer?.cutout ?? CutoutSettings()
            s.mode = CutoutMode(rawValue: a["mode"] as? String ?? "object") ?? .object
            e.setCutout(s)
        case "precompose":
            // Groups layers (ids in "layers", or all of them) into one pre-comp.
            let ids = (a["layers"] as? [String])?.compactMap(UUID.init(uuidString:)) ?? e.project.layers.map(\.id)
            e.multiSelection = Set(ids)
            e.precomposeMulti(name: a["name"] as? String)
            e.multiSelection = nil
        default:
            return .json(["error": "unknown action \(name)",
                          "actions": ["undo", "redo", "seek", "select", "play", "pause", "cutoutSubject", "precompose"]], status: 404)
        }
        return .json(["ok": true])
    }

    /// Everything the app can do, described as data.
    static func catalog() -> [String: Any] {
        let effects: [[String: Any]] = EffectRegistry.all.map { d in
            ["id": d.id, "name": d.name, "category": d.category.rawValue, "summary": d.summary, "transform": d.isTransformEffect,
             "params": d.params.map { p -> [String: Any] in
                var o: [String: Any] = ["id": p.id, "name": p.name]
                switch p.kind {
                case .number(let lo, let hi, let step, let unit): o["kind"] = "number"; o["min"] = lo; o["max"] = hi; o["step"] = step; o["unit"] = unit
                case .angle: o["kind"] = "angle"
                case .point: o["kind"] = "point"
                case .color: o["kind"] = "color"
                case .toggle: o["kind"] = "toggle"
                case .choice(let opts): o["kind"] = "choice"; o["options"] = opts
                default: o["kind"] = "\(p.kind)"
                }
                return o
             }]
        }
        return [
            "effects": effects,
            "blendModes": BlendMode.allCases.map(\.rawValue),
            "maskModes": MaskMode.allCases.map(\.rawValue),
            "trackMattes": TrackMatte.allCases.map(\.rawValue),
            "shapeKinds": ShapeKind.allCases.map(\.rawValue),
            "presets": PresetLibrary.all.map { ["id": $0.id, "name": $0.name, "kind": $0.kind.rawValue] },
            "titleStyles": TitleStyles.all.map { ["id": $0.id, "name": $0.name, "category": $0.category] },
            "textAnimations": TextPreset.library.map { ["id": $0.id, "name": $0.name] },
            "notes": "Edit by GET /project, change the JSON, PUT /project. Effects are {typeID, params}; params follow the catalog ranges.",
        ]
    }

    /// The phone's Wi-Fi IPv4 address.
    static func wifiAddress() -> String? {
        var ptr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ptr) == 0, let first = ptr else { return nil }
        defer { freeifaddrs(ptr) }
        var found: String?
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = p.pointee
            guard ifa.ifa_addr.pointee.sa_family == UInt8(AF_INET), String(cString: ifa.ifa_name) == "en0" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            found = String(cString: host)
        }
        return found
    }
}

// MARK: - Minimal HTTP

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let headers: [String: String]
    let body: Data

    init(method: String, path: String, query: [String: String], headers: [String: String], body: Data) {
        self.method = method; self.path = path; self.query = query; self.headers = headers; self.body = body
    }

    /// Parses a complete request (nil until all headers + Content-Length bytes have arrived).
    init?(_ data: Data) {
        guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        guard let head = String(data: data[..<end.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ") ?? []
        guard parts.count >= 2 else { return nil }
        var h: [String: String] = [:]
        for l in lines.dropFirst() {
            if let i = l.firstIndex(of: ":") { h[l[..<i].lowercased()] = l[l.index(after: i)...].trimmingCharacters(in: .whitespaces) }
        }
        let length = Int(h["content-length"] ?? "0") ?? 0
        let bodyStart = end.upperBound
        guard data.count - bodyStart >= length else { return nil }
        method = String(parts[0])
        let target = String(parts[1])
        let comps = URLComponents(string: target)
        path = comps?.path ?? target
        var q: [String: String] = [:]
        for item in comps?.queryItems ?? [] { q[item.name] = item.value ?? "" }
        query = q
        headers = h
        body = data[bodyStart..<(bodyStart + length)]
    }
}

struct HTTPResponse {
    let status: Int
    let type: String
    let body: Data

    static func json(_ obj: Any, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status, type: "application/json", body: (try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys])) ?? Data())
    }
    static var noProject: HTTPResponse { .json(["error": "open a project in AWIeffect first"], status: 409) }

    var bytes: Data {
        var head = "HTTP/1.1 \(status) OK\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        if status != 200 { head = head.replacingOccurrences(of: " OK", with: " ERR") }
        var d = Data(head.utf8)
        d.append(body)
        return d
    }
}

/// Settings section: switch, address and pairing code.
struct AILinkSettings: View {
    @ObservedObject var link = AILink.shared
    @AppStorage("awi.ailink.on") private var on = false

    var body: some View {
        Section {
            Toggle("AI Link", isOn: Binding(get: { on }, set: { b in on = b; link.setEnabled(b) }))
            if link.running {
                LabeledContent("Address", value: link.address)
                LabeledContent("Pairing code", value: link.code)
                Button("New Pairing Code") { link.newCode() }
                if !link.lastRequest.isEmpty { LabeledContent("Last request", value: link.lastRequest) }
            }
        } header: { Text("AI Link") } footer: {
            Text("Lets your paired assistant on the same Wi-Fi read and edit the open project, render frames and upload media. Off by default; only works with the pairing code.")
        }
        .onAppear { if on && !link.running { link.setEnabled(true) } }
    }
}
