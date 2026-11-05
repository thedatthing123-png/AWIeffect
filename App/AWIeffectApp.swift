import SwiftUI

/// True under UI tests: looping preview animations stay still so the app can go idle.
let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

@main
struct AWIeffectApp: App {
    init() {
        CrashReporter.install()
        FontLibrary.shared.registerAll()
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            Renderer.shared?.clearImageCache()
            VideoSources.shared.purgeCache()
            ModelRenderer.shared?.clear()
            CutoutEngine.shared.clear()
            EffectThumbnails.shared.clear()
        }
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

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-manyLayers") {
            var project = Project.new(name: "Timeline Scroll Test", width: 128, height: 128, fps: 30, duration: 8, background: .black)
            for n in 1...40 {
                let layer = project.makeLayer(name: "Layer \(n)", content: .solid, size: Vec2(20, 20))
                project.layers.append(layer)
            }
            _openProject = State(initialValue: project)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-containerInteractions") {
            var p = Project.new(name: "Container Interaction Test", width: 128, height: 128, fps: 30, duration: 3)
            var group = p.makeLayer(name: "Group Test", content: .solid, size: Vec2(128, 128))
            group.isGroup = true; group.tag = .teal
            var child = p.makeLayer(name: "Inside", content: .solid, size: Vec2(30, 30))
            child.groupID = group.id
            let outside = p.makeLayer(name: "Outside", content: .solid, size: Vec2(20, 20))
            p.layers = [group, child, outside]
            _openProject = State(initialValue: p)
        }
        #endif
    }

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
                    .id(p.id)
                    .transition(.move(edge: .trailing))
            } else {
                HomeView { openProject = $0 }
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: openProject?.id)
        // AI Link can create / open projects.
        .onAppear { AILink.openProject = { p in openProject = p } }
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
