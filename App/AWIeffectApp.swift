import SwiftUI

/// True under UI tests: looping preview animations stay still so the app can go idle.
let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

@main
struct AWIeffectApp: App {
    init() {
        CrashReporter.install()
        FontLibrary.shared.registerAll()
        // Built-in LUT looks for CC Studio (written once, in the background).
        DispatchQueue.global(qos: .utility).async { LUTLibrary.shared.installBuiltIns() }
        // Number fields select their whole value when you start typing, so a new number replaces the old one
        // (no deleting digits first).
        NotificationCenter.default.addObserver(forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main) { n in
            guard let tf = n.object as? UITextField else { return }
            switch tf.keyboardType {
            case .numbersAndPunctuation, .decimalPad, .numberPad:
                DispatchQueue.main.async { tf.selectAll(nil) }
            default:
                if tf.tag == AutoSelectField.tag { DispatchQueue.main.async { tf.selectAll(nil) } }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

/// Marker for text fields that should select everything when focused.
enum AutoSelectField { static let tag = 7_331 }

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
