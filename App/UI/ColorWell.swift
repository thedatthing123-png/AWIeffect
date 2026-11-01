import SwiftUI
import UIKit

/// AWIeffect's own color control (replaces the system color sheet everywhere): a swatch that opens a compact
/// picker beside it — saturation/brightness square, hue + opacity bars, typable HEX / RGB / HSB, recent and
/// saved swatches, and an eyedropper that picks from anything on screen (canvas, clip, UI).
struct AWIColorWell: View {
    let title: String
    @Binding var selection: Color
    var supportsOpacity = true
    @State private var open = false
    @State private var picking = false
    @State private var shot: UIImage?

    init(_ title: String, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.title = title
        _selection = selection
        self.supportsOpacity = supportsOpacity
    }

    var body: some View {
        HStack {
            if !title.isEmpty { Text(title) }
            if !title.isEmpty { Spacer() }
            Button { open = true } label: {
                ZStack {
                    CheckerBoard().clipShape(RoundedRectangle(cornerRadius: 7))
                    RoundedRectangle(cornerRadius: 7).fill(selection)
                    RoundedRectangle(cornerRadius: 7).strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                }
                .frame(width: 34, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title.isEmpty ? "Color" : title)
            .popover(isPresented: $open) {
                ColorEditor(color: $selection, supportsOpacity: supportsOpacity, onEyedropper: {
                    // The picker steps out of the way first, so you pick from the real screen (canvas, clips…).
                    open = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shot = ScreenEyedropper.capture(); picking = true }
                })
                .presentationCompactAdaptation(.popover)
            }
            .fullScreenCover(isPresented: $picking) {
                ScreenEyedropper(snapshot: shot) { c in
                    picking = false
                    if let c {
                        let a = UIColor(selection).cgColor.alpha
                        selection = c.opacity(Double(a))
                        ColorSwatches.pushRecent(HSBA(c).hex)
                    }
                }
                .presentationBackground(.clear)
            }
        }
    }
}

private struct CheckerBoard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 5
            for y in stride(from: 0, to: size.height, by: s) {
                for x in stride(from: 0, to: size.width, by: s) where (Int(x / s) + Int(y / s)) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)), with: .color(Color(white: 0.75)))
                }
            }
        }
        .background(Color(white: 0.95))
    }
}

/// Recent + saved colors, kept across projects.
enum ColorSwatches {
    private static let recentKey = "awi.colors.recent", savedKey = "awi.colors.saved"
    static func load(_ key: String) -> [String] { (UserDefaults.standard.array(forKey: key) as? [String]) ?? [] }
    static var recent: [String] { load(recentKey) }
    static var saved: [String] { load(savedKey) }
    static func pushRecent(_ hex: String) {
        var r = recent.filter { $0 != hex }
        r.insert(hex, at: 0)
        UserDefaults.standard.set(Array(r.prefix(12)), forKey: recentKey)
    }
    static func save(_ hex: String) {
        var s = saved.filter { $0 != hex }
        s.append(hex)
        UserDefaults.standard.set(Array(s.suffix(24)), forKey: savedKey)
    }
    static func remove(_ hex: String) { UserDefaults.standard.set(saved.filter { $0 != hex }, forKey: savedKey) }
}

struct HSBA: Equatable {
    var h: Double, s: Double, b: Double, a: Double

    init(_ c: Color) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(c).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        self.h = Double(h); self.s = Double(s); self.b = Double(b); self.a = Double(a)
    }
    init(h: Double, s: Double, b: Double, a: Double) { self.h = h; self.s = s; self.b = b; self.a = a }

    var color: Color { Color(hue: h, saturation: s, brightness: b, opacity: a) }
    var rgb: (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0, a: CGFloat = 0
        UIColor(hue: h, saturation: s, brightness: b, alpha: 1).getRed(&r, green: &g, blue: &bl, alpha: &a)
        return (Double(r), Double(g), Double(bl))
    }
    var hex: String {
        let (r, g, bl) = rgb
        return String(format: "%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((bl * 255).rounded()))
    }
    static func fromHex(_ raw: String, alpha: Double) -> HSBA? {
        let t = raw.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        guard t.count == 6, let v = UInt32(t, radix: 16) else { return nil }
        let c = Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
        var out = HSBA(c); out.a = alpha
        return out
    }
}

struct ColorEditor: View {
    @Binding var color: Color
    var supportsOpacity = true
    @State private var hsb = HSBA(h: 0, s: 0, b: 1, a: 1)
    @State private var hexText = ""
    @State private var mode = 0
    @State private var saved = ColorSwatches.saved
    @State private var picking = false
    @State private var shot: UIImage?
    /// Set by the color well: closes the picker, then picks from the live screen.
    var onEyedropper: (() -> Void)? = nil

    private func push(_ v: HSBA) {
        hsb = v
        color = v.color
        hexText = v.hex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Saturation (x) / brightness (y) square for the current hue.
            GeometryReader { g in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(LinearGradient(colors: [.white, Color(hue: hsb.h, saturation: 1, brightness: 1)], startPoint: .leading, endPoint: .trailing))
                    Rectangle().fill(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    Circle().strokeBorder(.white, lineWidth: 2).background(Circle().strokeBorder(.black.opacity(0.5), lineWidth: 3))
                        .frame(width: 20, height: 20)
                        .offset(x: g.size.width * hsb.s - 10, y: g.size.height * (1 - hsb.b) - 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    var n = hsb
                    n.s = min(max(v.location.x / g.size.width, 0), 1)
                    n.b = 1 - min(max(v.location.y / g.size.height, 0), 1)
                    push(n)
                }.onEnded { _ in ColorSwatches.pushRecent(hsb.hex) })
            }
            .frame(height: 170)
            bar(LinearGradient(colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) }, startPoint: .leading, endPoint: .trailing),
                value: hsb.h) { var n = hsb; n.h = min($0, 0.9999); push(n) }
            if supportsOpacity {
                bar(LinearGradient(colors: [hsb.color.opacity(0), hsb.color.opacity(1)], startPoint: .leading, endPoint: .trailing),
                    value: hsb.a, checker: true) { var n = hsb; n.a = $0; push(n) }
            }
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8).fill(hsb.color).frame(width: 40, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.3)))
                Text("#").foregroundStyle(Theme.textDim)
                TextField("HEX", text: $hexText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { if let v = HSBA.fromHex(hexText, alpha: hsb.a) { push(v); ColorSwatches.pushRecent(v.hex) } else { hexText = hsb.hex } }
                    .padding(.horizontal, 8).frame(height: 32).background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                Button { if let f = onEyedropper { f() } else { shot = ScreenEyedropper.capture(); picking = true } } label: { Image(systemName: "eyedropper").frame(width: 34, height: 32) }
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
                    .accessibilityLabel("Pick color from screen")
            }
            Picker("", selection: $mode) { Text("RGB").tag(0); Text("HSB").tag(1) }.pickerStyle(.segmented)
            if mode == 0 {
                let (r, g, b) = hsb.rgb
                numberRow("R", r * 255, 0...255) { v in setRGB(v / 255, g, b) }
                numberRow("G", g * 255, 0...255) { v in setRGB(r, v / 255, b) }
                numberRow("B", b * 255, 0...255) { v in setRGB(r, g, v / 255) }
            } else {
                numberRow("H", hsb.h * 360, 0...360) { v in var n = hsb; n.h = min(v / 360, 0.9999); push(n) }
                numberRow("S", hsb.s * 100, 0...100) { v in var n = hsb; n.s = v / 100; push(n) }
                numberRow("B", hsb.b * 100, 0...100) { v in var n = hsb; n.b = v / 100; push(n) }
            }
            if supportsOpacity { numberRow("Opacity", hsb.a * 100, 0...100) { v in var n = hsb; n.a = v / 100; push(n) } }
            swatches("RECENT", ColorSwatches.recent, removable: false)
            HStack {
                Text("SAVED").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim)
                Spacer()
                Button { ColorSwatches.save(hsb.hex); saved = ColorSwatches.saved } label: { Label("Save Color", systemImage: "plus") }
                    .font(.system(size: 12, weight: .semibold))
            }
            swatches(nil, saved, removable: true)
        }
        .padding(14)
        .frame(width: 320)
        .background(Theme.background)
        .onAppear { hsb = HSBA(color); hexText = hsb.hex }
        .fullScreenCover(isPresented: $picking) {
            ScreenEyedropper(snapshot: shot) { picked in
                picking = false
                if let picked { var n = HSBA(picked); n.a = hsb.a; push(n); ColorSwatches.pushRecent(n.hex) }
            }
            .presentationBackground(.clear)
        }
    }

    private func setRGB(_ r: Double, _ g: Double, _ b: Double) {
        var n = HSBA(Color(red: min(max(r, 0), 1), green: min(max(g, 0), 1), blue: min(max(b, 0), 1)))
        n.a = hsb.a
        push(n)
    }

    private func bar(_ fill: LinearGradient, value: Double, checker: Bool = false, set: @escaping (Double) -> Void) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                if checker { CheckerBoard() }
                Rectangle().fill(fill)
                Capsule().fill(.white).frame(width: 6, height: 26).shadow(radius: 1)
                    .offset(x: g.size.width * value - 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in set(min(max(v.location.x / g.size.width, 0), 1)) }
                .onEnded { _ in ColorSwatches.pushRecent(hsb.hex) })
        }
        .frame(height: 22)
    }

    private func numberRow(_ t: String, _ v: Double, _ r: ClosedRange<Double>, _ set: @escaping (Double) -> Void) -> some View {
        HStack {
            Text(t).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text).frame(width: 56, alignment: .leading)
            ValueScrubber(value: v, range: r, step: 1, onChange: { set(min(max($0, r.lowerBound), r.upperBound)) })
        }
    }

    @ViewBuilder private func swatches(_ title: String?, _ list: [String], removable: Bool) -> some View {
        if let title { Text(title).font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.textDim) }
        if list.isEmpty {
            Text(removable ? "Tap Save Color to keep colors for every project." : "Colors you use show up here.")
                .font(.caption).foregroundStyle(Theme.textDim)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 6), count: 8), alignment: .leading, spacing: 6) {
                ForEach(list, id: \.self) { hex in
                    Button { if let v = HSBA.fromHex(hex, alpha: hsb.a) { push(v) } } label: {
                        RoundedRectangle(cornerRadius: 6).fill(HSBA.fromHex(hex, alpha: 1)?.color ?? .clear).frame(width: 28, height: 28)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.25)))
                    }
                    .buttonStyle(.plain)
                    .contextMenu { if removable { Button(role: .destructive) { ColorSwatches.remove(hex); saved = ColorSwatches.saved } label: { Label("Remove", systemImage: "trash") } } }
                }
            }
        }
    }
}

/// Scene eyedropper (like AE / Alight Motion): shows the current frame of the edit only, never the app UI; drag with
/// a magnifying loupe and a live color readout, lift to pick.
struct ScreenEyedropper: View {
    /// The frame of the edit at the playhead.
    let snapshot: UIImage?
    let done: (Color?) -> Void
    @State private var probe: CGPoint?
    /// Renders the edit's current frame (set by the editor). Falls back to the screen only outside the editor.
    static var sceneProvider: (() -> UIImage?)?

    var body: some View {
        GeometryReader { g in
            let frame = imageRect(in: g.size)
            ZStack {
                Color.black
                if let snapshot { Image(uiImage: snapshot).resizable().frame(width: frame.width, height: frame.height).position(x: frame.midX, y: frame.midY) }
                if let p = probe, let c = color(at: p, frame: frame) {
                    loupe(at: p, frame: frame, color: c)
                        .position(x: min(max(70, p.x), g.size.width - 70), y: p.y > 220 ? p.y - 110 : p.y + 110)
                    // Crosshair on the exact pixel.
                    Path { path in
                        path.move(to: CGPoint(x: p.x - 12, y: p.y)); path.addLine(to: CGPoint(x: p.x + 12, y: p.y))
                        path.move(to: CGPoint(x: p.x, y: p.y - 12)); path.addLine(to: CGPoint(x: p.x, y: p.y + 12))
                    }
                    .stroke(.white, lineWidth: 1.5).shadow(radius: 1)
                }
                VStack {
                    Text("Drag over the frame · lift to pick").font(.system(size: 13, weight: .semibold)).padding(8)
                        .background(Capsule().fill(.black.opacity(0.6))).foregroundStyle(.white).padding(.top, 50)
                    Spacer()
                    Button("Cancel") { done(nil) }.buttonStyle(PrimaryButtonStyle()).padding(.bottom, 40)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in probe = CGPoint(x: min(max(v.location.x, frame.minX), frame.maxX - 1), y: min(max(v.location.y, frame.minY), frame.maxY - 1)) }
                .onEnded { _ in done(probe.flatMap { color(at: $0, frame: frame) }) })
        }
        .ignoresSafeArea()
    }

    /// Magnified pixels around the probe with the picked color and its hex code.
    private func loupe(at p: CGPoint, frame: CGRect, color c: Color) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if let snapshot, let cg = snapshot.cgImage {
                    let px = CGPoint(x: (p.x - frame.minX) / frame.width * CGFloat(cg.width), y: (p.y - frame.minY) / frame.height * CGFloat(cg.height))
                    if let crop = cg.cropping(to: CGRect(x: px.x - 7, y: px.y - 7, width: 15, height: 15)) {
                        Image(uiImage: UIImage(cgImage: crop)).interpolation(.none).resizable().frame(width: 96, height: 96)
                    }
                }
                Rectangle().strokeBorder(.white, lineWidth: 1.5).frame(width: 8, height: 8)
            }
            .frame(width: 96, height: 96).clipShape(Circle()).overlay(Circle().strokeBorder(c, lineWidth: 6)).overlay(Circle().strokeBorder(.white, lineWidth: 1))
            Text({ let r = c.rgba; return String(format: "#%02X%02X%02X", Int(r.r * 255), Int(r.g * 255), Int(r.b * 255)) }()).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(.black.opacity(0.7)))
        }
    }

    private func imageRect(in size: CGSize) -> CGRect {
        guard let s = snapshot?.size, s.width > 0, s.height > 0 else { return CGRect(origin: .zero, size: size) }
        let k = min(size.width / s.width, (size.height - 180) / s.height)
        let w = s.width * k, h = s.height * k
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    static func capture() -> UIImage? {
        if let scene = sceneProvider?() { return scene }
        guard let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).flatMap(\.windows).first(where: \.isKeyWindow)
        else { return nil }
        let r = UIGraphicsImageRenderer(bounds: window.bounds)
        return r.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: false) }
    }

    private func color(at p: CGPoint, frame: CGRect) -> Color? {
        guard let img = snapshot, let cg = img.cgImage, frame.width > 0, frame.height > 0 else { return nil }
        let x = Int((p.x - frame.minX) / frame.width * CGFloat(cg.width)), y = Int((p.y - frame.minY) / frame.height * CGFloat(cg.height))
        guard x >= 0, y >= 0, x < cg.width, y < cg.height else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: -x, y: y - cg.height + 1, width: cg.width, height: cg.height))
        return Color(red: Double(px[0]) / 255, green: Double(px[1]) / 255, blue: Double(px[2]) / 255)
    }
}
