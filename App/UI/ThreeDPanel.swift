import SwiftUI

extension EditorState {
    func addCamera() {
        mutate("Add Camera") { p in
            var l = p.makeLayer(name: "Camera \(p.layers.filter { $0.content == .camera }.count + 1)", content: .camera, size: Vec2(1, 1))
            let zoom = CameraState.defaultZoom(p)
            l.transform.positionZ = Animated(-zoom)
            l.camera = CameraOptions(zoom: Animated(zoom), focusDistance: Animated(zoom))
            l.tag = .amber
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
            // Make every visual layer 3D so the camera affects it (what AE users usually do next).
            for i in p.layers.indices where p.layers[i].content != .camera && p.layers[i].content != .adjustment {
                if case .audio = p.layers[i].content { continue }
                p.layers[i].is3D = true
            }
        }
        panel = .threeD
    }
}

extension EditorState {
    /// Adds an AE-style light above the comp, aimed into the scene, and makes visual layers 3D so it lights them.
    func addLight(_ type: LightType = .spot) {
        mutate("Add Light") { p in
            var l = p.makeLayer(name: "\(type.title) Light", content: .light, size: Vec2(1, 1))
            l.transform.position = Animated(Vec2(Double(p.width) * 0.35, Double(p.height) * 0.3))
            l.transform.positionZ = Animated(-CameraState.defaultZoom(p) * 0.6)
            l.transform.rotationX = Animated(-15)
            l.transform.rotationY = Animated(15)
            l.light = LightOptions(type: type)
            l.tag = .amber
            p.layers.insert(l, at: 0)
            selectedLayerID = l.id
            for i in p.layers.indices where p.layers[i].content != .camera && p.layers[i].content != .light && p.layers[i].content != .adjustment {
                if case .audio = p.layers[i].content { continue }
                p.layers[i].is3D = true
            }
        }
        panel = .threeD
    }
}

/// 3D layer switch + Z / X / Y controls, and camera options for camera layers.
struct ThreeDPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.content == .camera ? "Camera" : (state.selectedLayer?.content == .light ? "Light" : "3D"))
            if let l = state.selectedLayer {
                let t = state.currentTime
                ScrollView {
                    VStack(spacing: 8) {
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
                        if l.is3D && l.content != .camera && l.content != .model && l.content != .light {
                            row("Extrude", l.extrude.value(at: t), 0...600, anim: l.extrude,
                                set: { v in state.mutateLayer { $0.extrude.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.extrude.toggleKeyframe(at: t) } })
                        }
                        if l.is3D || l.content == .camera || l.content == .light {
                            row("Position Z", l.transform.positionZ.value(at: t), -6000...6000, anim: l.transform.positionZ,
                                set: { v in state.mutateLayer { $0.transform.positionZ.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.positionZ.toggleKeyframe(at: t) } })
                            row("X Rotation", l.transform.rotationX.value(at: t), -360...360, anim: l.transform.rotationX,
                                set: { v in state.mutateLayer { $0.transform.rotationX.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.rotationX.toggleKeyframe(at: t) } })
                            row("Y Rotation", l.transform.rotationY.value(at: t), -360...360, anim: l.transform.rotationY,
                                set: { v in state.mutateLayer { $0.transform.rotationY.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.rotationY.toggleKeyframe(at: t) } })
                        }
                        if l.content == .light, let o = l.light {
                            Picker("Type", selection: Binding(get: { o.type }, set: { v in
                                state.mutate("Light Type") { p in if let i = state.selectedIndex { p.layers[i].light?.type = v } }
                            })) { ForEach(LightType.allCases) { Text($0.title).tag($0) } }
                            .pickerStyle(.segmented)
                            ColorPicker("Color", selection: Binding(get: { Color(o.color.value(at: t)) }, set: { c in
                                state.coalescedEdit("Light Color") { $0.light?.color.set(c.rgba, at: t) }
                            })).foregroundStyle(Theme.text)
                            row("Intensity", o.intensity.value(at: t), 0...400, anim: o.intensity,
                                set: { v in state.mutateLayer { $0.light?.intensity.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.light?.intensity.toggleKeyframe(at: t) } })
                            if o.type == .spot {
                                row("Cone Angle", o.coneAngle.value(at: t), 1...180, anim: o.coneAngle,
                                    set: { v in state.mutateLayer { $0.light?.coneAngle.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.light?.coneAngle.toggleKeyframe(at: t) } })
                                row("Cone Feather", o.coneFeather.value(at: t), 0...100, anim: o.coneFeather,
                                    set: { v in state.mutateLayer { $0.light?.coneFeather.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.light?.coneFeather.toggleKeyframe(at: t) } })
                            }
                            if o.type == .point || o.type == .spot {
                                row("Falloff Radius", o.falloffRadius.value(at: t), 0...6000, anim: o.falloffRadius,
                                    set: { v in state.mutateLayer { $0.light?.falloffRadius.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.light?.falloffRadius.toggleKeyframe(at: t) } })
                            }
                            Text("Move the light with Position + Position Z; aim spot/parallel lights with X/Y Rotation. Every 3D layer is lit once a comp has a light.")
                                .font(.caption).foregroundStyle(Theme.textDim)
                        }
                        if l.content == .camera, let c = l.camera {
                            row("Zoom", c.zoom.value(at: t), 100...8000, anim: c.zoom,
                                set: { v in state.mutateLayer { $0.camera?.zoom.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.camera?.zoom.toggleKeyframe(at: t) } })
                            Toggle("Depth of Field", isOn: Binding(get: { c.depthOfField }, set: { b in
                                state.mutate("Depth of Field") { p in if let i = state.selectedIndex { p.layers[i].camera?.depthOfField = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                            if c.depthOfField {
                                row("Focus Distance", c.focusDistance.value(at: t), 10...10000, anim: c.focusDistance,
                                    set: { v in state.mutateLayer { $0.camera?.focusDistance.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.focusDistance.toggleKeyframe(at: t) } })
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

    private func row(_ title: String, _ v: Double, _ r: ClosedRange<Double>, anim: Animated<Double>? = nil, set: @escaping (Double) -> Void,
                     keyed: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            let t = state.currentTime
            KeyframeDiamond(filled: anim?.keyframes.contains { abs($0.time - t) < 1e-4 } ?? false, animated: anim?.isAnimated ?? false) {
                state.beginEdit("Keyframe \(title)"); keyed(); state.endEdit()
            }
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 92, alignment: .leading)
            Slider(value: Binding(get: { min(max(v, r.lowerBound), r.upperBound) }, set: { x in state.beginEdit(title); set(x) }), in: r) { e in
                if !e { state.endEdit() }
            }
            Text(String(format: "%.0f", v)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accentGlow).frame(width: 46)
        }
    }
}
