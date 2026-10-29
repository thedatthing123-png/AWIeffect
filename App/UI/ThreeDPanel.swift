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

/// 3D layer switch + Z / X / Y controls, and camera options for camera layers.
struct ThreeDPanel: View {
    @ObservedObject var state: EditorState

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.content == .camera ? "Camera" : "3D")
            if let l = state.selectedLayer {
                let t = state.currentTime
                ScrollView {
                    VStack(spacing: 8) {
                        if l.content != .camera {
                            Toggle("3D Layer", isOn: Binding(get: { l.is3D }, set: { b in
                                state.mutate("3D Layer") { p in if let i = state.selectedIndex { p.layers[i].is3D = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                        }
                        if l.is3D || l.content == .camera {
                            row("Position Z", l.transform.positionZ.value(at: t), -6000...6000,
                                set: { v in state.mutateLayer { $0.transform.positionZ.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.positionZ.toggleKeyframe(at: t) } })
                            row("X Rotation", l.transform.rotationX.value(at: t), -360...360,
                                set: { v in state.mutateLayer { $0.transform.rotationX.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.rotationX.toggleKeyframe(at: t) } })
                            row("Y Rotation", l.transform.rotationY.value(at: t), -360...360,
                                set: { v in state.mutateLayer { $0.transform.rotationY.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.transform.rotationY.toggleKeyframe(at: t) } })
                        }
                        if l.content == .camera, let c = l.camera {
                            row("Zoom", c.zoom.value(at: t), 100...8000,
                                set: { v in state.mutateLayer { $0.camera?.zoom.set(v, at: t) } },
                                keyed: { state.mutateLayer { $0.camera?.zoom.toggleKeyframe(at: t) } })
                            Toggle("Depth of Field", isOn: Binding(get: { c.depthOfField }, set: { b in
                                state.mutate("Depth of Field") { p in if let i = state.selectedIndex { p.layers[i].camera?.depthOfField = b } }
                            }))
                            .tint(Theme.accent).foregroundStyle(Theme.text)
                            if c.depthOfField {
                                row("Focus Distance", c.focusDistance.value(at: t), 10...10000,
                                    set: { v in state.mutateLayer { $0.camera?.focusDistance.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.focusDistance.toggleKeyframe(at: t) } })
                                row("Aperture", c.aperture.value(at: t), 0...400,
                                    set: { v in state.mutateLayer { $0.camera?.aperture.set(v, at: t) } },
                                    keyed: { state.mutateLayer { $0.camera?.aperture.toggleKeyframe(at: t) } })
                                row("Blur Level", c.blurLevel.value(at: t), 0...300,
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

    private func row(_ title: String, _ v: Double, _ r: ClosedRange<Double>, set: @escaping (Double) -> Void,
                     keyed: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Button(action: { state.beginEdit("Keyframe \(title)"); keyed(); state.endEdit() }) {
                Image(systemName: "diamond").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.keyframe).frame(width: 30, height: 30)
            }
            Text(title).font(.system(size: 12)).foregroundStyle(Theme.text).frame(width: 92, alignment: .leading)
            Slider(value: Binding(get: { min(max(v, r.lowerBound), r.upperBound) }, set: { x in state.beginEdit(title); set(x) }), in: r) { e in
                if !e { state.endEdit() }
            }
            Text(String(format: "%.0f", v)).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.accentGlow).frame(width: 46)
        }
    }
}
