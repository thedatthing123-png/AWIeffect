import SwiftUI

/// True under UI tests: looping preview animations stay still so the app can go idle.
let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

@main
struct AWIeffectApp: App {
    init() {
        CrashReporter.install()
        FontLibrary.shared.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @State private var openProject: Project? {
        didSet { UserDefaults.standard.set(openProject?.id.uuidString, forKey: CrashReporter.openProjectKey) }
    }
    @State private var crashReport = CrashReporter.previousReport

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            if Renderer.shared == nil {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(Theme.warning)
                    Text("Metal is unavailable on this device.").foregroundStyle(Theme.text)
                }
            } else if let p = openProject {
                EditorView(state: EditorState(project: p)) { openProject = nil }
                    .transition(.move(edge: .trailing))
            } else {
                HomeView { openProject = $0 }
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: openProject?.id)
        .sheet(isPresented: Binding(get: { crashReport != nil }, set: { if !$0 { crashReport = nil; CrashReporter.clear() } })) {
            CrashReportSheet(report: crashReport ?? "", reopen: lastProject.map { p in { crashReport = nil; openProject = p } }) {
                crashReport = nil
            }
        }
    }

    /// The project that was open when the app crashed.
    private var lastProject: Project? {
        guard let s = UserDefaults.standard.string(forKey: CrashReporter.openProjectKey), let id = UUID(uuidString: s) else { return nil }
        return try? ProjectStore.shared.load(id)
    }
}
