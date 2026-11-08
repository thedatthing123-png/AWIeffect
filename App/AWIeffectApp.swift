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
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-cutoutInline") {
            var p = Project.new(name: "Inline Cutout Test", width: 256, height: 256, fps: 30, duration: 3)
            p.layers = [p.makeLayer(name: "Picture", content: .image(fileName: "cutout-fixture.png", pixelWidth: 256, pixelHeight: 256), size: Vec2(256,256))]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-shapeContents") {
            var p = Project.new(name: "Shape Contents Test", width: 256, height: 256, fps: 30, duration: 3)
            var l = p.makeLayer(name: "Logo", content: .shape(.ellipse), size: Vec2(160,160))
            var a = ShapeComponent(); a.kind = .ellipse; a.fillGradient = ShapeGradient()
            var b = ShapeComponent(); b.kind = .rectangle; b.size = Animated(Vec2(80,80)); b.position = Animated(Vec2(40,0))
            l.shapeContents = [ShapeContent(name: "Ring", component: a), ShapeContent(name: "Accent", component: b)]
            p.layers = [l]; _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-stability") {
            var p = Project.new(name: "Timeline Stability", width: 128, height: 128, fps: 30, duration: 6)
            var short = p.makeLayer(name: "Short Clip", content: .solid, size: Vec2(24,24))
            short.inPoint = 1; short.outPoint = 1.3
            short.transform.rotation.insertKeyframe(Keyframe(time: 1,value: 0))
            short.transform.rotation.insertKeyframe(Keyframe(time: 1.3,value: 45))
            p.layers.append(short)
            var many = p.makeLayer(name: "Many Keys", content: .solid, size: Vec2(24,24))
            for frame in 0...60 {
                let t = Double(frame) / 10
                many.transform.position.insertKeyframe(Keyframe(time: t,value: Vec2(32+t*5,64)))
                many.transform.rotation.insertKeyframe(Keyframe(time: t,value: t*10))
                many.transform.opacity.insertKeyframe(Keyframe(time: t,value: 1))
            }
            p.layers.append(many)
            for n in 3...24 { p.layers.append(p.makeLayer(name: "Layer \(n)", content: .solid, size: Vec2(12,12))) }
            _openProject = State(initialValue: p)
        }
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
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-letterAuthoring") {
            var p = Project.new(name: "Letter Authoring Test", width: 600, height: 600, fps: 30, duration: 4)
            var layer = p.makeLayer(name: "HELLO", content: .text, size: Vec2(500, 160))
            var text = TextData(string: "HELLO")
            text.fontSize = 110; text.ensureCharIDs()
            layer.text = text
            p.layers = [layer]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-rigAuthoring") {
            var p = Project.new(name: "Rig Authoring Test", width: 600, height: 600, fps: 30, duration: 4)
            var lower = p.makeLayer(name: "Forearm", content: .solid, size: Vec2(140, 38))
            lower.transform.position = Animated(Vec2(300, 280))
            var upper = p.makeLayer(name: "Upper Arm", content: .solid, size: Vec2(140, 38))
            upper.transform.position = Animated(Vec2(170, 280))
            p.layers = [lower, upper]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-animationTiming") {
            var p = Project.new(name: "Timing Interaction Test", width: 128, height: 128, fps: 30, duration: 4)
            var nested = Project.new(name: "Source", width: 128, height: 128, fps: 30, duration: 4, background: RGBA(0,0,0,0))
            nested.layers = [nested.makeLayer(name: "shape", content: .solid, size: Vec2(20,20))]
            p.precomps = [nested]
            var layer = p.makeLayer(name: "Timing Clip", content: .precomp(id: nested.id), size: Vec2(128,128))
            layer.transform.position.insertKeyframe(Keyframe(time: 0,value: Vec2(64,64)))
            layer.transform.position.insertKeyframe(Keyframe(time: 2,value: Vec2(80,64)))
            p.layers = [layer]; _openProject = State(initialValue: p)
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
