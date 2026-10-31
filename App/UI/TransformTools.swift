import SwiftUI

/// Alight Motion-style Move & Transform: a tool rail on the right, one big control on the left that fits the
/// tool (swipe pad, depth strip, dial, trackball, rulers) and the values on top (tap one to type). Everything is
/// live: only the canvas and these values redraw while a finger is down, so it stays at 60 fps.
struct TransformPanel: View {
    @ObservedObject var state: EditorState
    @State private var showVelocity = false

    enum Tool: String, CaseIterable, Identifiable {
        case position = "Position", depth = "Z", rotation = "Rotate", scale = "Scale", opacity = "Opacity", anchor = "Anchor", link = "Link"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .position: return "arrow.up.and.down.and.arrow.left.and.right"
            case .depth: return "square.3.layers.3d.down.right"
            case .rotation: return "arrow.triangle.2.circlepath"
            case .scale: return "arrow.up.left.and.arrow.down.right"
            case .opacity: return "circle.lefthalf.filled"
            case .anchor: return "scope"
            case .link: return "link"
            }
        }
        var key: PropertyKey? {
            switch self {
            case .position: return .position
            case .depth: return .positionZ
            case .rotation: return .rotation
            case .scale: return .scale
            case .opacity: return .opacity
            case .anchor: return .anchor
            case .link: return nil
            }
        }
        var canvasTool: TransformTool {
            switch self {
            case .scale: return .scale
            case .rotation: return .rotate
            case .anchor: return .pivot
            default: return .move
            }
        }
    }
    @AppStorage("awi.transformTool") private var toolRaw = Tool.position.rawValue
    private var tool: Tool { Tool(rawValue: toolRaw) ?? .position }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(state: state, title: state.selectedLayer?.content == .camera ? "Camera" : "Move & Transform")
            if state.selectedLayer != nil {
                HStack(spacing: 0) {
                    leftRail
                    LiveReader(live: state.live) { lp in
                        if let l = (lp ?? state.project).layers.first(where: { $0.id == state.selectedLayerID }) {
                            TransformToolBody(state: state, layer: l, tool: tool)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    rightRail
                }
                .padding(.bottom, 6)
            }
        }
        .onAppear { state.transformTool = tool.canvasTool }
        .awiSheet(isPresented: $showVelocity) { KeyframeVelocitySheet(state: state).presentationDetents([.medium, .large]) }
    }

    /// Keyframe + graph, always in the same spot.
    private var leftRail: some View {
        VStack(spacing: 10) {
            if let key = tool.key {
                KeyframeDiamond(filled: state.hasKeyframe(key), animated: state.isAnimated(key)) { state.toggleKeyframe(key) }
                    .frame(width: 40, height: 36)
            }
            Button { state.graphEffect = nil; state.panel = .graph } label: {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 36)
            }
            .accessibilityLabel("Graph")
            Button { showVelocity = true } label: {
                Image(systemName: "speedometer").font(.system(size: 15, weight: .semibold)).frame(width: 40, height: 36)
            }
            .accessibilityLabel("Velocity")
            Spacer()
        }
        .foregroundStyle(Theme.text)
        .frame(width: 46)
    }

    private var rightRail: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(tools) { t in
                    Button {
                        toolRaw = t.rawValue
                        state.transformTool = t.canvasTool
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: t.icon).font(.system(size: 15, weight: .semibold))
                            Text(t.rawValue).font(.system(size: 8.5, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(width: 54, height: 42)
                        .foregroundStyle(tool == t ? Theme.accentGlow : Theme.text)
                        .background(RoundedRectangle(cornerRadius: 9).fill(tool == t ? Theme.accent.opacity(0.28) : .clear))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(t.rawValue) tool")
                }
            }
        }
        .frame(width: 60)
    }

    private var tools: [Tool] {
        guard let l = state.selectedLayer else { return [] }
        if l.content == .light { return [.position, .depth, .rotation, .link] }
        return Tool.allCases
    }
}

/// The control for one transform tool, fed with the live layer (updates while dragging).
struct TransformToolBody: View {
    @ObservedObject var state: EditorState
    let layer: Layer
    let tool: TransformPanel.Tool

    private var t: Double { state.currentTime }
    private var compW: Double { Double(state.project.width) }

    var body: some View {
        VStack(spacing: 6) {
            switch tool {
            case .position:
                let p = layer.transform.position.value(at: t)
                valueRow([("X", p.x, { v in edit("Move") { $0.transform.position.set(Vec2(v, p.y), at: t) } }),
                          ("Y", p.y, { v in edit("Move") { $0.transform.position.set(Vec2(p.x, v), at: t) } }),
                          ("Z", layer.transform.positionZ.value(at: t), { v in edit("Depth") { $0.transform.positionZ.set(v, at: t) } })])
                SwipePad(hint: "Swipe here to move the layer", gain: compW) { d in
                    state.mutateLayer { l in
                        let q = l.transform.position.value(at: t)
                        l.transform.position.set(Vec2(((q.x + d.width) * 10).rounded() / 10, ((q.y + d.height) * 10).rounded() / 10), at: t)
                    }
                } begin: { state.beginPanelGesture("Move Layer") } end: { state.endPanelGesture() }
            case .depth:
                valueRow([("Z", layer.transform.positionZ.value(at: t), { v in edit("Depth") { $0.transform.positionZ.set(v, at: t) } })])
                SwipePad(hint: "Swipe up to bring it closer (−Z), down to push it back", gain: compW * 2, vertical: true) { d in
                    state.mutateLayer { l in
                        let z = l.transform.positionZ.value(at: t)
                        l.transform.positionZ.set(((z + d.height) * 10).rounded() / 10, at: t)
                    }
                } begin: { state.beginPanelGesture("Depth") } end: { state.endPanelGesture() }
            case .rotation:
                if layer.is3D {
                    valueRow([("X", layer.transform.rotationX.value(at: t), { v in edit("Rotate") { $0.transform.rotationX.set(v, at: t) } }),
                              ("Y", layer.transform.rotationY.value(at: t), { v in edit("Rotate") { $0.transform.rotationY.set(v, at: t) } }),
                              ("Z", layer.transform.rotation.value(at: t), { v in edit("Rotate") { $0.transform.rotation.set(v, at: t) } })])
                    Trackball { dx, dy in
                        state.mutateLayer { l in
                            l.transform.rotationY.set(((l.transform.rotationY.value(at: t) + dx) * 10).rounded() / 10, at: t)
                            l.transform.rotationX.set(((l.transform.rotationX.value(at: t) - dy) * 10).rounded() / 10, at: t)
                        }
                    } begin: { state.beginPanelGesture("Rotate 3D") } end: { state.endPanelGesture() }
                } else {
                    valueRow([("°", layer.transform.rotation.value(at: t), { v in edit("Rotate") { $0.transform.rotation.set(v, at: t) } })])
                    RotationDial(angle: layer.transform.rotation.value(at: t)) { a in
                        state.mutateLayer { $0.transform.rotation.set((a * 10).rounded() / 10, at: t) }
                    } begin: { state.beginPanelGesture("Rotate Layer") } end: { state.endPanelGesture() }
                }
            case .scale:
                let s = layer.transform.scale.value(at: t)
                valueRow([("W%", s.x, { v in edit("Scale") { $0.transform.scale.set(state.scaleLinked ? Vec2(v, s.x == 0 ? v : v * s.y / s.x) : Vec2(v, s.y), at: t) } }),
                          ("H%", s.y, { v in edit("Scale") { $0.transform.scale.set(state.scaleLinked ? Vec2(s.y == 0 ? v : v * s.x / s.y, v) : Vec2(s.x, v), at: t) } })])
                HStack(spacing: 6) {
                    VStack(spacing: 6) {
                        RulerStrip(label: "Width") { d in scaleBy(dx: d, dy: state.scaleLinked ? d : 0) }
                            begin: { state.beginPanelGesture("Scale Layer") } end: { state.endPanelGesture() }
                        RulerStrip(label: "Height") { d in scaleBy(dx: state.scaleLinked ? d : 0, dy: d) }
                            begin: { state.beginPanelGesture("Scale Layer") } end: { state.endPanelGesture() }
                    }
                    Button { state.scaleLinked.toggle() } label: {
                        Image(systemName: state.scaleLinked ? "link" : "link.badge.plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 36, height: 80)
                            .background(RoundedRectangle(cornerRadius: 9).fill(state.scaleLinked ? Theme.accent.opacity(0.3) : Theme.surface))
                            .foregroundStyle(state.scaleLinked ? Theme.accentGlow : Theme.textDim)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(state.scaleLinked ? "Scale linked" : "Scale unlinked")
                }
            case .opacity:
                valueRow([("%", layer.transform.opacity.value(at: t), { v in edit("Opacity") { $0.transform.opacity.set(min(100, max(0, v)), at: t) } })])
                RulerStrip(label: "Opacity", perPoint: 0.25) { d in
                    state.mutateLayer { l in l.transform.opacity.set(min(100, max(0, ((l.transform.opacity.value(at: t) + d) * 10).rounded() / 10)), at: t) }
                } begin: { state.beginPanelGesture("Opacity") } end: { state.endPanelGesture() }
                Spacer(minLength: 0)
            case .anchor:
                let a = layer.transform.anchor.value(at: t)
                valueRow([("X", a.x, { v in edit("Anchor") { $0.transform.anchor.set(Vec2(v, a.y), at: t) } }),
                          ("Y", a.y, { v in edit("Anchor") { $0.transform.anchor.set(Vec2(a.x, v), at: t) } })])
                SwipePad(hint: "Swipe to move the pivot (or drag it on the canvas)", gain: compW * 0.6) { d in
                    state.mutateLayer { l in
                        let q = l.transform.anchor.value(at: t)
                        l.transform.anchor.set(Vec2(((q.x + d.width) * 10).rounded() / 10, ((q.y + d.height) * 10).rounded() / 10), at: t)
                    }
                } begin: { state.beginPanelGesture("Move Pivot") } end: { state.endPanelGesture() }
            case .link:
                LinkSection(state: state, layer: layer)
            }
        }
        .padding(.horizontal, 4)
    }

    private func scaleBy(dx: Double, dy: Double) {
        state.mutateLayer { l in
            let s = l.transform.scale.value(at: t)
            l.transform.scale.set(Vec2(((s.x + dx) * 10).rounded() / 10, ((s.y + dy) * 10).rounded() / 10), at: t)
        }
    }

    private func edit(_ label: String, _ change: (inout Layer) -> Void) {
        state.beginEdit(label); state.mutateLayer(change); state.endEdit()
    }

    /// Values on top: drag sideways to nudge, tap to type (the old number is selected, so just type over it).
    private func valueRow(_ items: [(String, Double, (Double) -> Void)]) -> some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { i in
                NumberField(value: items[i].1, label: items[i].0, onCommit: items[i].2)
            }
        }
    }
}

/// Link (parent) to another layer: tap, then tap the layer to follow on the canvas.
struct LinkSection: View {
    @ObservedObject var state: EditorState
    let layer: Layer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pid = layer.parentID, let parent = state.project.layers.first(where: { $0.id == pid }) {
                Label("Linked to \(parent.name)", systemImage: "link").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.text)
                Button { state.setParent(nil) } label: { bigButton("Unlink", "link.badge.plus") }.buttonStyle(.plain)
            } else {
                Text("Linked layers follow their parent's move, turn and size, and still keep their own keyframes.")
                    .font(.system(size: 12)).foregroundStyle(Theme.textDim)
            }
            Button { state.beginLinkPick() } label: { bigButton(layer.parentID == nil ? "Tap a Layer to Link" : "Link to Another Layer", "hand.tap") }
                .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func bigButton(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(RoundedRectangle(cornerRadius: 11).fill(Theme.accent.opacity(0.28)))
            .foregroundStyle(Theme.accentGlow)
    }
}

// MARK: - Controls

/// Swipe area: your finger never covers the canvas. Slow swipes are fine, quick swipes travel far.
struct SwipePad: View {
    let hint: String
    /// Comp units per full pad width at normal speed.
    let gain: Double
    var vertical = false
    let onDelta: (CGSize) -> Void
    var begin: () -> Void = {}
    var end: () -> Void = {}
    @State private var last: CGSize?
    @State private var lastTime: TimeInterval = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Theme.surface)
                RoundedRectangle(cornerRadius: 14).stroke(last == nil ? Theme.stroke : Theme.accent, lineWidth: last == nil ? 1 : 2)
                VStack(spacing: 6) {
                    Image(systemName: vertical ? "arrow.up.and.down" : "hand.draw").font(.system(size: 20)).foregroundStyle(Theme.textDim.opacity(0.7))
                    Text(hint).font(.system(size: 11, weight: .semibold)).foregroundStyle(last == nil ? Theme.textDim : Theme.accentGlow)
                        .multilineTextAlignment(.center).padding(.horizontal, 10)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if last == nil { last = .zero; lastTime = CACurrentMediaTime(); begin() }
                    let now = CACurrentMediaTime()
                    let dx = g.translation.width - (last?.width ?? 0), dy = g.translation.height - (last?.height ?? 0)
                    let dt = max(now - lastTime, 1.0 / 240)
                    last = g.translation; lastTime = now
                    // Speed-based acceleration: < ~60 pt/s precise, fast flicks up to 4×.
                    let speed = Double(hypot(dx, dy)) / dt
                    let accel = speed < 60 ? 0.35 : min(4, 0.35 + (speed - 60) / 260)
                    let k = gain / Double(max(geo.size.width, 1)) * accel
                    onDelta(vertical ? CGSize(width: 0, height: Double(dy) * k) : CGSize(width: Double(dx) * k, height: Double(dy) * k))
                }
                .onEnded { _ in last = nil; end() })
        }
        .frame(minHeight: 90)
    }
}

/// Rotation dial: drag around the ring; whole turns keep counting (720° = two spins).
struct RotationDial: View {
    let angle: Double
    let onChange: (Double) -> Void
    var begin: () -> Void = {}
    var end: () -> Void = {}
    @State private var startAngle: Double?
    @State private var lastFinger: Double = 0
    @State private var accumulated: Double = 0

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - 8
            let c = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let r = side / 2
            ZStack {
                Circle().stroke(Theme.surface, lineWidth: 14).frame(width: side, height: side)
                Circle().trim(from: 0, to: CGFloat(min(1, abs(angle.truncatingRemainder(dividingBy: 360)) / 360)))
                    .stroke(Theme.accentGlow, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: angle < 0 ? -1 : 1)
                    .frame(width: side, height: side)
                let a = (angle - 90) * .pi / 180
                Circle().fill(.white).frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.4), radius: 3)
                    .position(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
                Text(String(format: "%.1f°", angle)).font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.raised))
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let f = atan2(Double(g.location.y - c.y), Double(g.location.x - c.x)) * 180 / .pi
                    if startAngle == nil { startAngle = angle; lastFinger = f; accumulated = 0; begin() }
                    var d = f - lastFinger
                    if d > 180 { d -= 360 } else if d < -180 { d += 360 }
                    lastFinger = f
                    accumulated += d
                    var v = (startAngle ?? 0) + accumulated
                    // Gentle snap to 45° steps.
                    let s = (v / 45).rounded() * 45
                    if abs(v - s) < 1.5 { v = s }
                    onChange(v)
                }
                .onEnded { _ in startAngle = nil; end() })
        }
        .frame(minHeight: 110)
    }
}

/// 3D rotation: drag the ball to tumble the layer (sideways = Y, up / down = X).
struct Trackball: View {
    let onDelta: (Double, Double) -> Void
    var begin: () -> Void = {}
    var end: () -> Void = {}
    @State private var last: CGSize?

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) - 8
            ZStack {
                Circle().fill(RadialGradient(colors: [Theme.raised, Theme.surface], center: .topLeading, startRadius: 4, endRadius: side))
                    .frame(width: side, height: side)
                ForEach(0..<3) { i in
                    Ellipse().stroke(Theme.accentGlow.opacity(0.35), lineWidth: 1)
                        .frame(width: side * (i == 0 ? 1 : 0.35), height: side * (i == 0 ? 0.35 : 1))
                        .rotationEffect(.degrees(i == 2 ? 45 : 0))
                }
                Text("Drag to tumble").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    if last == nil { last = .zero; begin() }
                    let dx = g.translation.width - (last?.width ?? 0), dy = g.translation.height - (last?.height ?? 0)
                    last = g.translation
                    onDelta(Double(dx) * 0.6, Double(dy) * 0.6)
                }
                .onEnded { _ in last = nil; end() })
        }
        .frame(minHeight: 110)
    }
}

/// Ruler you drag sideways (the ticks slide under the finger). Slow drags are fine, quick ones go far.
struct RulerStrip: View {
    let label: String
    var perPoint: Double = 0.5
    let onDelta: (Double) -> Void
    var begin: () -> Void = {}
    var end: () -> Void = {}
    @State private var last: CGFloat?
    @State private var lastTime: TimeInterval = 0
    @State private var shift: CGFloat = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Theme.surface)
            Canvas { ctx, size in
                let step: CGFloat = 8
                var x = shift.truncatingRemainder(dividingBy: step * 5) - step * 5
                var i = 0
                while x < size.width + step {
                    let major = i % 5 == 0
                    ctx.fill(Path(CGRect(x: x, y: size.height * (major ? 0.25 : 0.4), width: 1, height: size.height * (major ? 0.5 : 0.2))),
                             with: .color(Theme.textDim.opacity(major ? 0.7 : 0.35)))
                    x += step; i += 1
                }
                ctx.fill(Path(CGRect(x: size.width / 2 - 1, y: 4, width: 2, height: size.height - 8)), with: .color(Theme.accentGlow))
            }
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.textDim)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(5)
        }
        .frame(height: 37)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { g in
                if last == nil { last = 0; lastTime = CACurrentMediaTime(); begin() }
                let now = CACurrentMediaTime()
                let dx = g.translation.width - (last ?? 0)
                let dt = max(now - lastTime, 1.0 / 240)
                last = g.translation.width; lastTime = now
                shift += dx
                let speed = Double(abs(dx)) / dt
                let accel = speed < 60 ? 0.4 : min(4, 0.4 + (speed - 60) / 260)
                onDelta(Double(dx) * perPoint * accel)
            }
            .onEnded { _ in last = nil; end() })
    }
}
