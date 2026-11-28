import Foundation
import SwiftUI
import Darwin

/// Built-in crash reporter. On a crash it writes the signal, the last few things the user did and a backtrace
/// (only async-signal-safe calls inside the handler); Swift's own "Fatal error: …" line is captured too because
/// stderr is redirected to a log. The next launch shows the report so it can be copied or shared in one tap.
enum CrashReporter {
    private static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Crash", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private static var crashURL: URL { dir.appendingPathComponent("crash.log") }
    private static var stderrURL: URL { dir.appendingPathComponent("stderr.log") }
    private static var previousStderrURL: URL { dir.appendingPathComponent("stderr.prev.log") }

    /// Report left by the previous run (nil when it ended normally).
    private(set) static var previousReport: String?

    // Signal-handler state: plain C memory, written without locks or allocation.
    private static var crashFD: Int32 = -1
    private static let crumbSize = 2048
    private static let crumbs = UnsafeMutablePointer<CChar>.allocate(capacity: crumbSize)
    private static var crumbLen = 0
    private static let lockQ = DispatchQueue(label: "awi.crumbs")
    private static var recent: [String] = []

    static let openProjectKey = "awi.crash.openProject"
    private static var openingURL: URL { dir.appendingPathComponent("editor-opening.json") }

    private struct EditorOpening: Codable {
        var projectID: UUID
        var started = Date()
        var stages: [String] = []
    }

    private static var opening: EditorOpening?
    private static var openingCleanup: DispatchWorkItem?
    private(set) static var previousProjectID: UUID?

    /// Called on the main thread. Atomic replacement keeps the last complete
    /// checkpoint readable even if iOS kills the process without a signal handler.
    static func beginEditorOpening(_ id: UUID) {
        endEditorOpening()
        UserDefaults.standard.set(id.uuidString, forKey: openProjectKey)
        guard !isUITesting else { return } // XCTest deliberately ends and relaunches the process.
        opening = EditorOpening(projectID: id)
        editorStage("Open requested", projectID: id)
    }

    static func editorStage(_ stage: String, projectID: UUID) {
        guard var entry = opening, entry.projectID == projectID, !entry.stages.contains(stage),
              entry.stages.count < 32 else { return }
        entry.stages.append(stage)
        opening = entry
        if let data = try? JSONEncoder().encode(entry) { try? data.write(to: openingURL, options: .atomic) }
    }

    static func editorFirstFrame(projectID: UUID) {
        guard opening?.projectID == projectID, openingCleanup == nil else { return }
        editorStage("First preview frame completed on GPU", projectID: projectID)
        let complete = DispatchWorkItem { endEditorOpening() }
        openingCleanup = complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: complete)
    }

    static func endEditorOpening() {
        openingCleanup?.cancel()
        openingCleanup = nil
        guard opening != nil else { return }
        opening = nil
        try? FileManager.default.removeItem(at: openingURL)
    }

    static func install() {
        let fm = FileManager.default
        let crash = (try? String(contentsOf: crashURL, encoding: .utf8)) ?? ""
        let savedOpening = (try? Data(contentsOf: openingURL)).flatMap { try? JSONDecoder().decode(EditorOpening.self, from: $0) }
        // Consume once. A normal close, completed startup or background exit clears this file.
        try? fm.removeItem(at: openingURL)
        let hasSignal = !crash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasSignal || savedOpening != nil {
            previousProjectID = savedOpening?.projectID
                ?? UserDefaults.standard.string(forKey: openProjectKey).flatMap(UUID.init(uuidString:))
            var report = hasSignal ? crash : "Previous session ended while the editor was opening. No crash signal was recorded."
            if let savedOpening {
                let stages = savedOpening.stages.map { "  • " + $0 }.joined(separator: "\n")
                report += "\n\nEditor startup (\(savedOpening.started.ISO8601Format())):\n" + stages
            }
            if let err = try? String(contentsOf: stderrURL, encoding: .utf8) {
                let fatal = err.split(separator: "\n").filter { $0.contains("Fatal error") || $0.contains("fatal") || $0.contains("Terminating") || $0.contains("assert") }
                if !fatal.isEmpty { report = "Swift says:\n" + fatal.suffix(5).joined(separator: "\n") + "\n\n" + report }
            }
            let info = Bundle.main.infoDictionary
            report = "AWIeffect \(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?")) · iOS \(UIDevice.current.systemVersion)\n" + report
            previousReport = report
        }
        try? fm.removeItem(at: previousStderrURL)
        try? fm.moveItem(at: stderrURL, to: previousStderrURL)
        // Swift runtime errors print to stderr just before trapping.
        freopen(stderrURL.path, "w", stderr)
        setvbuf(stderr, nil, _IONBF, 0)

        crashFD = open(crashURL.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        crumbs.initialize(repeating: 0, count: crumbSize)
        for sig in [SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGFPE] { signal(sig, crashHandler) }
        NSSetUncaughtExceptionHandler { e in
            CrashReporter.note("ObjC exception: \(e.name.rawValue): \(e.reason ?? "")")
        }
    }

    /// Records what the user just did (undo labels, panels, playback) for the report.
    static func note(_ s: String) {
        lockQ.sync {
            recent.append(s)
            if recent.count > 12 { recent.removeFirst(recent.count - 12) }
            let text = "Last actions:\n" + recent.map { "  · " + $0 }.joined(separator: "\n") + "\n"
            let bytes = Array(text.utf8.prefix(crumbSize - 1))
            bytes.withUnsafeBufferPointer { b in
                b.baseAddress!.withMemoryRebound(to: CChar.self, capacity: b.count) { crumbs.update(from: $0, count: b.count) }
            }
            crumbLen = bytes.count
        }
    }

    static func clear() {
        previousReport = nil
        try? FileManager.default.removeItem(at: crashURL)
    }

    fileprivate static func write(_ s: StaticString) {
        _ = s.withUTF8Buffer { Darwin.write(crashFD, $0.baseAddress, $0.count) }
    }

    fileprivate static func writeCrumbs() { _ = Darwin.write(crashFD, crumbs, crumbLen) }
    fileprivate static var fd: Int32 { crashFD }
}

private func crashHandler(_ sig: Int32) {
    guard CrashReporter.fd >= 0 else { return }
    switch sig {
    case SIGABRT: CrashReporter.write("Crash: SIGABRT (abort)\n")
    case SIGSEGV: CrashReporter.write("Crash: SIGSEGV (bad memory access)\n")
    case SIGBUS: CrashReporter.write("Crash: SIGBUS (bad memory access)\n")
    case SIGILL: CrashReporter.write("Crash: SIGILL (illegal instruction)\n")
    case SIGTRAP: CrashReporter.write("Crash: SIGTRAP (Swift runtime check failed)\n")
    case SIGFPE: CrashReporter.write("Crash: SIGFPE (math error)\n")
    default: CrashReporter.write("Crash: signal\n")
    }
    CrashReporter.writeCrumbs()
    CrashReporter.write("Backtrace:\n")
    var frames = [UnsafeMutableRawPointer?](repeating: nil, count: 64)
    let n = backtrace(&frames, 64)
    backtrace_symbols_fd(&frames, n, CrashReporter.fd)
    fsync(CrashReporter.fd)
    signal(sig, SIG_DFL)
    raise(sig)
}

/// Shown on launch after a crash.
struct CrashReportSheet: View {
    let report: String
    var reopen: (() -> Void)?
    let done: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warning)
                Text("Previous session interrupted").font(.headline).foregroundStyle(Theme.text)
                Spacer()
            }
            Text("Copy or share this report to help diagnose the interruption.")
                .font(.subheadline).foregroundStyle(Theme.textDim)
            ScrollView {
                Text(report).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
            .padding(10).glass(radius: 12)
            HStack {
                Button(copied ? "Copied" : "Copy Report") { UIPasteboard.general.string = report; copied = true }
                    .buttonStyle(PrimaryButtonStyle())
                ShareLink(item: report) { Label("Share", systemImage: "square.and.arrow.up") }
                Spacer()
            }
            HStack {
                if let reopen { Button("Reopen Project") { CrashReporter.clear(); reopen() }.font(.system(size: 15, weight: .semibold)) }
                Spacer()
                Button("Close") { CrashReporter.clear(); done() }.font(.system(size: 15, weight: .semibold))
            }
        }
        .padding(18)
        .background(Theme.background.ignoresSafeArea())
    }
}
