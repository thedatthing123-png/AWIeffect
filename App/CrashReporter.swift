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

    static func install() {
        let fm = FileManager.default
        let crash = (try? String(contentsOf: crashURL, encoding: .utf8)) ?? ""
        if !crash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var report = crash
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
                Text("AWIeffect crashed last time").font(.headline).foregroundStyle(Theme.text)
                Spacer()
            }
            Text("Your project was autosaved. Send this report so the cause can be fixed.")
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
