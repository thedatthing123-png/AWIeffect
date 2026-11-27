import SwiftUI

extension EditorState {
    func addCamera(spatial: Bool = false) {
        mutate("Add Camera") { p in
            var l = p.makeLayer(name: "Camera \(p.layers.filter { $0.content == .camera }.count + 1)", content: .camera, size: Vec2(1, 1))
            let zoom = CameraState.defaultZoom(p)
            l.transform.positionZ = Animated(-zoom)
            l.camera = CameraOptions(zoom: Animated(zoom), focusDistance: Animated(zoom))
            // Alight Motion-style: a new camera is a 2D camera that films the whole scene. In a 3D scene it can be
            // switched to a 3D camera (Lens & 3D).
            l.camera?.affects2D = !spatial && !p.layers.contains { $0.is3D }
            l.tag = .amber
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
        }
        cameraView = true
        panel = .transform
    }
}

extension EditorState {
    static func isLightingArtwork(_ layer: Layer) -> Bool {
        !layer.isAudioOnly && !layer.isNull && layer.content != .camera && layer.content != .light
            && layer.content != .adjustment
    }

    /// Adds a light without changing the composition geometry.
    func addLight(_ type: LightType = .spot) {
        mutate("Add Light") { p in
            var l = p.makeLayer(name: "\(type.title) Light", content: .light, size: Vec2(1, 1))
            l.transform.position = Animated(Vec2(Double(p.width) * 0.5, Double(p.height) * 0.5))
            l.transform.positionZ = Animated(-CameraState.defaultZoom(p) * 0.6)
            l.light = LightOptions(type: type)
            l.tag = .amber
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
            for i in p.layers.indices where Self.isLightingArtwork(p.layers[i]) {
                if !p.layers[i].is3D && p.layers[i].receivesLightOverride == nil {
                    p.layers[i].receivesLightOverride = true
                }
            }
        }
        panel = .threeD
    }
}

extension EditorState {
    nonisolated static func zoom(forFocalLength mm: Double, compWidth: Int) -> Double { Double(compWidth) * mm / 36 }
    nonisolated static func focalLength(zoom: Double, compWidth: Int) -> Double { zoom * 36 / Double(max(1, compWidth)) }

    /// Sets the selected camera's focus distance to how far the layer is from it right now.
    func focusCamera(on id: UUID) {
        guard let ci = selectedIndex, project.layers[ci].content == .camera, let target = project.layers.first(where: { $0.id == id }) else { return }
        let t = currentTime
        let resolved = Renderer.resolveParenting(project, time: t)
        let camera = Renderer.activeCamera(resolved, time: t)
        let at = resolved.layers.first { $0.id == id } ?? target
        let d = Renderer.layerDepth(at, camera: camera, time: t)
        guard d.isFinite, d > 1 else { return }
        mutate("Focus on \(target.name)") { p in
            p.layers[ci].camera?.depthOfField = true
            p.layers[ci].camera?.focusDistance.set(d, at: t)
        }
    }
}

/// 3D layer switch + Z / X / Y controls, and camera options for camera layers.
struct ThreeDPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        if let layer = state.selectedLayer, layer.content == .light, let light = layer.light {
            LightingStudio(state: state, layer: layer, light: light).id(layer.id)
        } else {
            geometryPanel
        }
    }

    private var geometryPanel: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.content == .camera ? "Camera" : "3D")
            if let l = state.selectedLayer {
                let t = state.currentTime
                ScrollView {
                    VStack(spacing: 8) {
                        if l.content == .camera {
                            SmoothSceneControls(state: state, layer: l)
                        }
                        if l.content == .adjustment {
                            Text("Adjustment layers apply their effects in 2D to everything below them.").font(.caption).foregroundStyle(Theme.textDim)
                        }
                        if l.content != .camera && l.content != .light && l.content != .adjustment {
                            Toggle("3D Layer", isOn: Binding(get: { l.is3D }, set: { b in
                                state.mutate("3D Layer") { p in if let i = state.selectedIndex { p.layers[i].is3D = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                        }
                        if l.content != .camera && l.content != .model && l.content != .light && l.content != .adjustment {
                            Button { state.makeSelected3DObject() } label: {
                                Label(Self.convertTitle(l), systemImage: "cube.transparent.fill").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent).tint(Theme.accent)
                            .accessibilityLabel("Make 3D Object")
                        }
                        if l.is3D && l.content != .camera && l.content != .light {
                            HStack {
                                Toggle("Casts Shadows", isOn: Binding(get: { l.castsShadows }, set: { b in
                                    state.mutate("Casts Shadows") { p in if let i = state.selectedIndex { p.layers[i].castsShadows = b } }
                                })).tint(Theme.accent)
                                Toggle("Accepts Shadows", isOn: Binding(get: { l.acceptsShadows }, set: { b in
                                    state.mutate("Accepts Shadows") { p in if let i = state.selectedIndex { p.layers[i].acceptsShadows = b } }
                                })).tint(Theme.accent)
                            }
                            .font(.system(size: 13)).foregroundStyle(Theme.text)
                        }
                        if l.is3D && l.content != .camera && l.content != .model && l.content != .light {
                            row("Extrude", l.extrude.value(at: t), 0...600, anim: l.extrude,
                                set: { v in state.mutateLayer { $0.extrude.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.extrude.toggleKeyframe(at: t) } })
                        }
                        if l.is3D || l.content == .camera || l.content == .light {
                            row("Position Z", l.transform.positionZ.value(at: t), -6000...6000, anim: l.transform.positionZ, precisionTravel: 240,
                                set: { v in state.mutateLayer { $0.transform.positionZ.set(v, at: t) } },
                                keyed: { state.toggleKeyframe(.positionZ) })
                            row("X Rotation", l.transform.rotationX.value(at: t), -360...360, anim: l.transform.rotationX,
                                set: { v in state.mutateLayer { $0.transform.rotationX.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.rotationX.toggleKeyframe(at: t) } })
                            row("Y Rotation", l.transform.rotationY.value(at: t), -360...360, anim: l.transform.rotationY,
                                set: { v in state.mutateLayer { $0.transform.rotationY.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.rotationY.toggleKeyframe(at: t) } })
                        }
                        if l.content == .camera, let c = l.camera {
                            CameraModeSwitch(state: state, layer: l)
                            if c.affects2D {
                                // 2D lens: zoom = how close the shot is (100% = the whole frame).
                                row("Zoom %", l.transform.scale.value(at: t).x, 10...1000, anim: { var a = Animated(l.transform.scale.staticValue.x); a.keyframes = l.transform.scale.keyframes.map { Keyframe(time: $0.time, value: $0.value.x) }; return a }(),
                                    set: { v in state.mutateLayer { $0.transform.scale.set(Vec2(v, v), at: t) } },
                                    keyed: { state.mutateLayer { $0.transform.scale.toggleKeyframe(at: t) } })
                                Text("Depth of field needs the 3D camera (it blurs layers by their distance).").font(.caption).foregroundStyle(Theme.textDim)
                            } else {
                                // 3D lens: focal length. Low = wide angle (strong depth), high = telephoto.
                                row("Lens (focal)", c.zoom.value(at: t), 100...8000, anim: c.zoom,
                                    set: { v in state.mutateLayer { $0.camera?.zoom.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.zoom.toggleKeyframe(at: t) } })
                                Text("Low = wide angle, high = telephoto (zoomed in, flatter depth).").font(.caption).foregroundStyle(Theme.textDim)
                        // Like a real lens on a full-frame camera (AE uses the same 36 mm film width).
                        // Three per row, 44 pt each.
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            ForEach([18.0, 24, 35, 50, 85, 135], id: \.self) { mm in
                                Button {
                                    state.mutate("Lens \(Int(mm)) mm") { p in
                                        if let i = state.selectedIndex { p.layers[i].camera?.zoom.set(EditorState.zoom(forFocalLength: mm, compWidth: p.width), at: t) }
                                    }
                                } label: {
                                    Text("\(Int(mm)) mm").font(.system(size: 12, weight: .bold)).frame(maxWidth: .infinity, minHeight: 44)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(abs(EditorState.focalLength(zoom: c.zoom.value(at: t), compWidth: state.project.width) - mm) < 0.5 ? Theme.accent : Theme.raised))
                                        .foregroundStyle(Theme.text)
                                }
                            }
                        }
                        Text(String(format: "%.0f mm lens", EditorState.focalLength(zoom: c.zoom.value(at: t), compWidth: state.project.width)))
                            .font(.caption).foregroundStyle(Theme.textDim)
                            }
                            Text("Effects on this camera (shake, glitch, grade…) apply to the whole shot.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                            Toggle("Depth of Field", isOn: Binding(get: { c.depthOfField }, set: { b in
                                state.mutate("Depth of Field") { p in if let i = state.selectedIndex { p.layers[i].camera?.depthOfField = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                            if c.depthOfField {
                                row("Focus Distance", c.focusDistance.value(at: t), 10...10000, anim: c.focusDistance,
                                    set: { v in state.mutateLayer { $0.camera?.focusDistance.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.focusDistance.toggleKeyframe(at: t) } })
                                // Tap the layer on the canvas (like Link) instead of hunting for its name.
                                Button { state.pickCameraFocus() } label: {
                                    Label("Focus on a Layer (tap it)", systemImage: "hand.tap").font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 9).fill(Theme.raised)).foregroundStyle(Theme.text)
                                }
                                .buttonStyle(.plain)
                        row("Aperture", c.aperture.value(at: t), 0...400, anim: c.aperture,
                                    set: { v in state.mutateLayer { $0.camera?.aperture.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.aperture.toggleKeyframe(at: t) } })
                                row("Blur Level", c.blurLevel.value(at: t), 0...300, anim: c.blurLevel,
                                    set: { v in state.mutateLayer { $0.camera?.blurLevel.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.blurLevel.toggleKeyframe(at: t) } })
                            }
                            Text("Move the camera with Position (X/Y) and Z, turn it with the rotations. 3D layers sort by depth automatically.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 14)
                }
            }
        }
    }

    static func convertTitle(_ l: Layer) -> String {
        switch l.content {
        case .shape: return "Make 3D Object (extrude shape)"
        case .text: return "Make 3D Text Object"
        case .image: return l.drawingID != nil ? "Make Drawing 3D (extrude)" : "Make Image 3D (cut-out extrude)"
        default: return "Make 3D (thick card)"
        }
    }

    private func row(_ title: String, _ v: Double, _ r: ClosedRange<Double>, anim: Animated<Double>? = nil, precisionTravel: Double? = nil, set: @escaping (Double) -> Void,
                     keyed: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            let t = state.currentTime
            KeyframeDiamond(filled: anim?.keyframes.contains { abs($0.time - t) < 1e-4 } ?? false, animated: anim?.isAnimated ?? false) {
                state.beginEdit("Keyframe \(title)"); keyed(); state.endEdit()
            }
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 92, alignment: .leading)
            ValueScrubber(value: v, range: r, step: precisionTravel == nil ? 0 : 0.1, onBegin: { state.beginEdit(title) }, onChange: set, onEnd: { state.endEdit() }, allowBeyond: true, precisionTravel: precisionTravel)
        }
    }
}
