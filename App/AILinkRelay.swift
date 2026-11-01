import Foundation
import SwiftUI
import AVFoundation

/// AI Link over the internet: the app keeps one secure WebSocket open to your own relay server (a Cloudflare
/// Worker), so Claude can reach the open project from anywhere, with no PC and nothing to start by hand. Requests
/// arrive as JSON, run through the same handler as the local Wi-Fi API, and the answer goes back on the socket.
///
/// Wire format (relay → app): {"id": "...", "method": "GET", "path": "/info", "query": {...}, "body": "<base64>"}
///             (app → relay): {"id": "...", "status": 200, "type": "application/json", "body": "<base64>"}
@MainActor
final class AILinkRelay: ObservableObject {
    static let shared = AILinkRelay()
    enum Status: Equatable { case off, connecting, connected, failed(String) }

    @Published private(set) var status: Status = .off
    @Published var relayURL = UserDefaults.standard.string(forKey: "awi.relay.url") ?? "" {
        didSet { UserDefaults.standard.set(relayURL, forKey: "awi.relay.url") }
    }
    /// Secret shared by this phone and the connector (generated on the phone; never leaves it except to the relay).
    @Published var key = UserDefaults.standard.string(forKey: "awi.relay.key") ?? "" {
        didSet { UserDefaults.standard.set(key, forKey: "awi.relay.key") }
    }
    @Published var enabled = UserDefaults.standard.bool(forKey: "awi.relay.on") {
        didSet { UserDefaults.standard.set(enabled, forKey: "awi.relay.on") }
    }

    private var task: URLSessionWebSocketTask?
    private var keepAlive: AVAudioPlayer?
    private var observers: [NSObjectProtocol] = []

    private init() {
        // Coming back to the app: the old socket may be dead without knowing it — always reconnect fresh.
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in
                let r = AILinkRelay.shared
                if r.enabled { r.reconnect() }
                UIApplication.shared.isIdleTimerDisabled = r.enabled
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            Task { @MainActor in UIApplication.shared.isIdleTimerDisabled = false }
        })
    }

    /// Silent audio keeps the app running in the background while connected (sideloaded app, so this is allowed
    /// for us), so Claude can still read and edit while you're in another app.
    private func setKeepAlive(_ on: Bool) {
        if !on { keepAlive?.stop(); keepAlive = nil; return }
        guard keepAlive == nil else { return }
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? s.setActive(true)
        // 1 s of silence, looped.
        let rate = 8000, n = rate
        var wav = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 4)) }
        func u16(_ v: UInt16) { var x = v.littleEndian; wav.append(Data(bytes: &x, count: 2)) }
        wav.append(Data("RIFF".utf8)); u32(UInt32(36 + n * 2)); wav.append(Data("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        wav.append(Data("data".utf8)); u32(UInt32(n * 2)); wav.append(Data(count: n * 2))
        guard let p = try? AVAudioPlayer(data: wav) else { return }
        p.numberOfLoops = -1
        p.volume = 0
        p.play()
        keepAlive = p
    }
    private var retry = 0
    private var retryWork: DispatchWorkItem?

    func ensureKey() {
        if key.isEmpty {
            var bytes = [UInt8](repeating: 0, count: 24)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            key = bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    func newKey() { key = ""; ensureKey(); if enabled { reconnect() } }

    func setEnabled(_ on: Bool) {
        enabled = on
        on ? connect() : disconnect()
        setKeepAlive(on)
        UIApplication.shared.isIdleTimerDisabled = on
    }

    /// Called when the editor opens: stay connected while a project is open.
    func resume() {
        guard enabled else { return }
        setKeepAlive(true)
        if task == nil || status != .connected { reconnect() }
    }

    private func connect() {
        ensureKey()
        retryWork?.cancel()
        let base = relayURL.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard !base.isEmpty, var comps = URLComponents(string: base + (base.hasSuffix("/") ? "" : "/") + "phone") else {
            status = .failed("Add your relay address first"); return
        }
        comps.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = comps.url else { status = .failed("Relay address looks wrong"); return }
        status = .connecting
        let t = URLSession.shared.webSocketTask(with: url)
        t.maximumMessageSize = 64 << 20
        task = t
        t.resume()
        listen(t)
        ping(t)
    }

    private func disconnect() {
        retryWork?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        status = .off
    }

    func reconnect() { disconnect(); connect() }

    private func scheduleRetry(_ why: String) {
        task = nil
        guard enabled else { status = .off; return }
        status = .failed(why)
        retry = min(retry + 1, 3)   // waits 2, 4, 8 s at most
        let w = DispatchWorkItem { [weak self] in self?.connect() }
        retryWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + pow(2, Double(retry)), execute: w)
    }

    /// Keeps the socket alive (and notices when it dropped).
    private func ping(_ t: URLSessionWebSocketTask) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            guard let self, self.task === t else { return }
            t.sendPing { err in
                Task { @MainActor in
                    guard self.task === t else { return }
                    if let err { self.scheduleRetry(err.localizedDescription) } else { self.ping(t) }
                }
            }
        }
    }

    private func listen(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            Task { @MainActor in
                guard let self, self.task === t else { return }
                switch result {
                case .failure(let e):
                    self.scheduleRetry(e.localizedDescription)
                case .success(let msg):
                    self.status = .connected
                    self.retry = 0
                    var data: Data?
                    switch msg {
                    case .string(let s): data = Data(s.utf8)
                    case .data(let d): data = d
                    @unknown default: break
                    }
                    if let data { self.answer(data, on: t) }
                    self.listen(t)
                }
            }
        }
    }

    private func answer(_ data: Data, on t: URLSessionWebSocketTask) {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let id = obj["id"] as? String else { return }
        if obj["hello"] != nil { return }   // relay greeting
        let req = HTTPRequest(method: (obj["method"] as? String) ?? "GET", path: (obj["path"] as? String) ?? "/",
                              query: (obj["query"] as? [String: String]) ?? [:],
                              headers: ["x-awi-code": AILink.shared.code],
                              body: (obj["body"] as? String).flatMap { Data(base64Encoded: $0) } ?? Data())
        let res = AILink.shared.respond(req)
        let out: [String: Any] = ["id": id, "status": res.status, "type": res.type, "body": res.body.base64EncodedString()]
        guard let d = try? JSONSerialization.data(withJSONObject: out), let s = String(data: d, encoding: .utf8) else { return }
        t.send(.string(s)) { _ in }
    }
}

/// Settings: connect to your online relay (Claude can then edit from any chat, anywhere).
struct AILinkRelaySettings: View {
    @ObservedObject var relay = AILinkRelay.shared

    var body: some View {
        Section {
            Toggle("Connect to Claude (online)", isOn: Binding(get: { relay.enabled }, set: { relay.setEnabled($0) }))
            TextField("Relay address (https://…workers.dev)", text: $relay.relayURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
            LabeledContent("Status") {
                switch relay.status {
                case .off: Text("Off").foregroundStyle(Theme.textDim)
                case .connecting: Text("Connecting…").foregroundStyle(Theme.warning)
                case .connected: Text("Connected").foregroundStyle(Theme.ok)
                case .failed(let why): Text(why).foregroundStyle(Theme.danger).lineLimit(2)
                }
            }
            HStack {
                Text("Secret key").foregroundStyle(Theme.text)
                Spacer()
                Text(relay.key.isEmpty ? "—" : String(relay.key.prefix(8)) + "…").font(.system(.body, design: .monospaced)).foregroundStyle(Theme.textDim)
            }
            Button("Copy Secret Key") { relay.ensureKey(); UIPasteboard.general.string = relay.key }
            Button("Make a New Key", role: .destructive) { relay.newKey() }
        } header: { Text("AI Link · Online") } footer: {
            Text("Keeps a secure connection to your own relay while a project is open, so Claude can read and edit it from any chat. Only someone with your secret key can reach it.")
        }
        .onAppear { relay.ensureKey() }
    }
}
