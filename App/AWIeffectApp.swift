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
            BoneMeshGPU.clearCache()
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

#if DEBUG
/// UI tests lay Home out at the narrowest supported iPhone width (375 pt) on the big simulator.
private let homeTestWidth: CGFloat? = ProcessInfo.processInfo.arguments.contains("-uiTesting-homeNarrow") ? 375 : nil
#else
private let homeTestWidth: CGFloat? = nil
#endif

/// Marker for text fields that should select everything when focused.
enum AutoSelectField { static let tag = 7_331 }

struct RootView: View {
    @State private var openProject: Project?
    @Environment(\.scenePhase) private var scenePhase
    @State private var crashReport = CrashReporter.previousReport

    init() {
        #if DEBUG
        HomeLibrarySeed.runIfRequested()
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-ccLUTGrid") {
            var p = Project.new(name: "LUT Preview", width: 480, height: 320, fps: 30, duration: 3, background: RGBA(0.23, 0.32, 0.45))
            var grade = p.makeLayer(name: "Grade", content: .adjustment, size: Vec2(480, 320))
            grade.effects = [EffectRegistry.grade.makeInstance()]
            var shape = p.makeLayer(name: "Artwork", content: .shape(.star), size: Vec2(235, 225))
            shape.fill = Animated(RGBA(0.84, 0.37, 0.19))
            p.layers = [grade, shape]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-referenceEffect") {
            var p = Project.new(name: "Reviewed Effect Controls", width: 320, height: 240, fps: 30, duration: 3)
            var layer = p.makeLayer(name: "Artwork", content: .shape(.star), size: Vec2(180, 160))
            layer.fill = Animated(RGBA(0.8, 0.5, 0.2))
            let arguments=ProcessInfo.processInfo.arguments
            if let index=arguments.firstIndex(of:"-uiTesting-referenceID"), arguments.indices.contains(index+1),
               let definition=EffectRegistry.definition(arguments[index+1]) {
                layer.effects=[definition.makeInstance()]
            } else if ProcessInfo.processInfo.arguments.contains("-uiTesting-referencePalette") {
                var effect = ReferenceFragmentCatalog.e658cad5dcbff.definition.makeInstance()
                effect.params["palette"] = .choice(10)
                layer.effects = [effect]
            } else { layer.effects = [ReferenceFragmentCatalog.eeab7e403ece5.definition.makeInstance()] }
            p.layers = [layer]; _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-sceneWorkspace") {
            var p = Project.new(name: "Scene Workspace", width: 360, height: 240, fps: 30, duration: 3)
            var foreground = p.makeLayer(name: "Foreground", content: .solid, size: Vec2(100, 140))
            foreground.fill = Animated(RGBA(0.8, 0.35, 0.2))
            var background = p.makeLayer(name: "Background", content: .solid, size: Vec2(360, 240))
            background.fill = Animated(RGBA(0.28, 0.33, 0.45))
            p.layers = [foreground, background]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-lightingStudio") {
            var p = Project.new(name: "Lighting Studio Preview", width: 360, height: 240, fps: 30, duration: 3)
            var light = p.makeLayer(name: "Spot Light", content: .light, size: Vec2(1, 1))
            light.transform.positionZ = Animated(-320)
            light.light = LightOptions(type: .spot)
            light.light?.castsShadows = true
            var artwork = p.makeLayer(name: "Artwork", content: .solid, size: Vec2(360, 240))
            artwork.fill = Animated(RGBA(0.58, 0.66, 0.76))
            artwork.receivesLightOverride = true
            p.layers = [light, artwork]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-sourceImport") {
            let xml = """
            <scene title="Source Import" width="320" height="240" fps="30" totalTime="2000">
              <shape label="Missing footage" fillType="media" fillVideo="placeholder.mov" startTime="0" endTime="2000">
                <effect id="com.customfx.effects.sourceExample"><property name="amount" value="0.4"/></effect>
              </shape>
            </scene>
            """
            if let result = try? AMImporter.load(data: Data(xml.utf8), fallbackName: "Source Import") {
                _openProject = State(initialValue: result.project)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-relight") {
            var project = Project.new(name: "Relight UI", width: 320, height: 240, fps: 30, duration: 2)
            var artwork = project.makeLayer(name: "Artwork", content: .image(fileName: "relight-test.png", pixelWidth: 720, pixelHeight: 720),
                                            size: Vec2(210, 210))
            var material = RelightSurface()
            material.maps[.depth] = RelightMedia(file: "relight-test.png", name: "depth.png", isVideo: false)
            material.maps[.normal] = RelightMedia(file: "relight-test.png", name: "normals.png", isVideo: false)
            artwork.relight = material
            project.layers = [artwork]
            _openProject = State(initialValue: project)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-smoothScene") {
            var project = Project.new(name: "Smooth Scene", width: 160, height: 120, fps: 30, duration: 2)
            var camera = project.makeLayer(name: "Camera", content: .camera, size: Vec2(160, 120))
            camera.camera = CameraOptions()
            let adjustment = project.makeLayer(name: "Adjustment", content: .adjustment, size: Vec2(160, 120))
            let artwork = project.makeLayer(name: "Artwork", content: .shape(.star), size: Vec2(48, 48))
            project.layers = [camera, adjustment, artwork]
            _openProject = State(initialValue: project)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-motionBlur") {
            var p = Project.new(name: "Motion Blur Controls", width: 160, height: 120, fps: 30, duration: 2)
            var camera = p.makeLayer(name: "Camera", content: .camera, size: Vec2(160,120))
            camera.camera = CameraOptions(); camera.camera?.affects2D = true
            var bar = p.makeLayer(name: "Moving bar", content: .solid, size: Vec2(12,60))
            bar.transform.position.insertKeyframe(Keyframe(time: 0, value: Vec2(20,60)))
            bar.transform.position.insertKeyframe(Keyframe(time: 2, value: Vec2(140,60)))
            p.layers = [camera, bar]; _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-cutoutInline") {
            var p = Project.new(name: "Inline Cutout Test", width: 256, height: 256, fps: 30, duration: 3)
            p.layers = [p.makeLayer(name: "Picture", content: .image(fileName: "cutout-fixture.png", pixelWidth: 256, pixelHeight: 256), size: Vec2(256,256))]
            _openProject = State(initialValue: p)
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-artworkRigStudio") {
            var p = Project.new(name: "Artwork Rig Test", width: 256, height: 256, fps: 30, duration: 3)
            var artwork = p.makeLayer(name: "Artwork", content: .image(fileName: "rig-fixture.png", pixelWidth: 256, pixelHeight: 256), size: Vec2(220, 220))
            let shoulder = ArtworkBone(name: "Upper Arm", start: Vec2(-70, -52), end: Vec2(-10, -4))
            let wrist = ArtworkBone(name: "Forearm", start: shoulder.end, end: Vec2(56, -4), parentID: shoulder.id)
            var rig = ArtworkRig(bones: [wrist, shoulder])
            rig.bind(halfSize: Vec2(110, 110), artworkID: artwork.id, detail: 32, radius: 55, amount: 1)
            _ = rig.enableIK(on: wrist.id, time: 0)
            artwork.artworkRig = rig
            p.layers = [artwork]
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
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-boneWeights") {
            var p = Project.new(name: "Weight brush interaction",width: 600,height: 600,fps: 30,duration: 4)
            p.layers = [p.makeLayer(name: "Artwork",content: .solid,size: Vec2(400,400))]
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
                EditorView(state: EditorState(project: p), close: closeEditor)
                    .id(p.id)
                    .transition(.move(edge: .trailing))
            } else {
                HomeView(open: openEditor)
                    .frame(maxWidth: homeTestWidth)
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: openProject?.id)
        // AI Link can create / open projects.
        .onAppear { AILink.openProject = openEditor }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { CrashReporter.endEditorOpening() }
        }
        .sheet(isPresented: Binding(get: { crashReport != nil }, set: { if !$0 { crashReport = nil; CrashReporter.clear() } })) {
            CrashReportSheet(report: crashReport ?? "", reopen: lastProject.map { p in { crashReport = nil; openEditor(p) } }) {
                crashReport = nil
            }
        }
    }

    private func openEditor(_ project: Project) {
        CrashReporter.beginEditorOpening(project.id)
        openProject = project
    }

    private func closeEditor() {
        CrashReporter.endEditorOpening()
        UserDefaults.standard.removeObject(forKey: CrashReporter.openProjectKey)
        openProject = nil
    }

    /// The project that was open when the previous session ended.
    private var lastProject: Project? {
        guard crashReport != nil, let id = CrashReporter.previousProjectID else { return nil }
        return try? ProjectStore.shared.load(id)
    }
}
