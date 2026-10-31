import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    let open: (Project) -> Void
    @State private var projects: [ProjectSummary] = []
    @State private var showCreate = false
    @State private var pendingDelete: ProjectSummary?
    @State private var renameTarget: ProjectSummary?
    @State private var renameText = ""
    @State private var versionsTarget: ProjectSummary?
    @State private var shareFile: SharedFile?
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var importURL: URL?
    @State private var importResult: AEPImportResult?
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    createCard
                    Button { showImporter = true } label: {
                        HStack(spacing: 12) {
                            Text("Ae").font(.system(size: 15, weight: .black, design: .rounded))
                                .frame(width: 34, height: 34)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0x1F0F3D)))
                                .foregroundStyle(Theme.accentGlow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import AE or Alight Motion Project").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                                Text(".aep, .ffx or Alight Motion .xml from Files").font(.caption).foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                        }
                        .padding(14).glass()
                    }
                    .buttonStyle(.plain)
                    if projects.isEmpty {
                        emptyState
                    } else {
                        Text("Latest projects").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                            .padding(.top, 6)
                        ForEach(projects) { p in projectRow(p) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .onAppear(perform: reload)
        .sheet(item: $shareFile) { f in ActivitySheet(items: [f.url]) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.aep, .xml, UTType(filenameExtension: "awi") ?? .data, .data]) { result in
            guard case .success(let url) = result else { return }
            importURL = url
            runImport(compName: nil)
        }
        .sheet(isPresented: Binding(get: { importResult != nil }, set: { if !$0 { importResult = nil } })) {
            if let r = importResult {
                ImportReportSheet(result: r, open: { p in
                    try? ProjectStore.shared.save(p)
                    importResult = nil
                    open(p)
                }, reimport: { runImport(compName: $0) })
            }
        }
        .alert("Rename Project", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                let n = renameText.trimmingCharacters(in: .whitespaces)
                if let t = renameTarget, !n.isEmpty, var proj = try? ProjectStore.shared.load(t.id) {
                    proj.name = n; try? ProjectStore.shared.save(proj); reload()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $versionsTarget) { t in
            NavigationStack {
                List {
                    let urls = ProjectStore.shared.versions(for: t.id)
                    if urls.isEmpty { Text("No saved versions yet — they're made automatically every couple of minutes while you edit.").foregroundStyle(Theme.textDim) }
                    ForEach(urls, id: \.self) { u in
                        Button {
                            if var v = try? ProjectStore.shared.loadVersion(u) {
                                v.id = t.id; try? ProjectStore.shared.save(v, snapshotVersion: true); reload(); versionsTarget = nil
                            }
                        } label: {
                            Text(((try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                .navigationTitle("Restore \(t.name)").navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium])
        }
        .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
        .sheet(isPresented: $showCreate) {
            CreateProjectSheet { p in
                try? ProjectStore.shared.save(p)
                showCreate = false
                open(p)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Delete project?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible, presenting: pendingDelete) { p in
            Button("Delete \(p.name)", role: .destructive) {
                ProjectStore.shared.delete(p.id)
                reload()
            }
        } message: { _ in Text("This can't be undone.") }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                .resizable().frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 8))
                .opacity(UIImage(named: "AppIcon") == nil ? 0 : 1)
            Text("AWIeffect")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Theme.text, Theme.accentGlow], startPoint: .leading, endPoint: .trailing))
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.text)
                    .frame(width: 36, height: 36)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    private var createCard: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus").font(.system(size: 18, weight: .bold))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.accent))
                    .foregroundStyle(.white)
                Text("Create New Project").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 36)).foregroundStyle(Theme.accentGlow)
            Text("No projects yet").font(.headline).foregroundStyle(Theme.text)
            Text("Tap Create New Project to start your first edit.").font(.subheadline).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func projectRow(_ p: ProjectSummary) -> some View {
        Button {
            if let proj = try? ProjectStore.shared.load(p.id) { open(proj) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.black)
                    if let t = p.thumbnail {
                        Image(uiImage: t).resizable().scaledToFit()
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomLeading) {
                    Text(formatTimecode(p.duration, fps: p.fps))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.7)))
                        .foregroundStyle(.white).padding(4)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(1)
                    HStack(spacing: 10) {
                        Label("\(p.width)×\(p.height)", systemImage: "aspectratio")
                        Label("\(Int(p.fps))fps", systemImage: "speedometer")
                    }
                    .font(.system(size: 11)).foregroundStyle(Theme.textDim)
                    Text(p.modifiedAt, style: .relative).font(.system(size: 11)).foregroundStyle(Theme.textDim)
                }
                Spacer()
            }
            .padding(12)
            .glass()
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { renameText = p.name; renameTarget = p } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
            Button { _ = try? ProjectStore.shared.duplicate(p.id); reload() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button { versionsTarget = p } label: { Label("Restore Version", systemImage: "clock.arrow.circlepath") }
            Button {
                if let proj = try? ProjectStore.shared.load(p.id), let url = try? ProjectPackage.export(proj) { shareFile = SharedFile(url: url) }
            } label: { Label("Share Project File (.awi)", systemImage: "square.and.arrow.up") }
            Button(role: .destructive) { pendingDelete = p } label: { Label("Delete", systemImage: "trash") }
        }
    }

    private func reload() { projects = ProjectStore.shared.list() }

    private func runImport(compName: String?) {
        guard let url = importURL else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            if let data = try? Data(contentsOf: url), ProjectPackage.isPackage(data) {
                // A project shared from AWIeffect: opens exactly as it was saved.
                let p = try ProjectPackage.importPackage(data)
                reload()
                open(p)
                return
            }
            if let data = try? Data(contentsOf: url), AMImporter.isAMProject(data) {
                importResult = try AMImporter.load(data: data, fallbackName: url.deletingPathExtension().lastPathComponent)
            } else {
                importResult = try AEPImporter.load(url: url, compName: compName)
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

struct CreateProjectSheet: View {
    let create: (Project) -> Void

    struct Aspect: Identifiable, Hashable {
        let label: String; let w: Int; let h: Int
        var id: String { label }
    }
    static let aspects = [
        Aspect(label: "9:16", w: 9, h: 16), Aspect(label: "16:9", w: 16, h: 9), Aspect(label: "4:5", w: 4, h: 5),
        Aspect(label: "1:1", w: 1, h: 1), Aspect(label: "4:3", w: 4, h: 3), Aspect(label: "3:4", w: 3, h: 4),
    ]
    static let resolutions = [(label: "720p", short: 720), (label: "1080p (FHD)", short: 1080), (label: "1440p (QHD)", short: 1440), (label: "2160p (4K)", short: 2160)]
    static let rates: [Double] = [24, 25, 30, 60]

    @State private var name = "Project \(Int.random(in: 100...999))"
    @State private var aspect = aspects[0]
    @State private var shortSide = 1080
    @State private var fps: Double = 60
    @State private var duration: Double = 10
    @State private var background = Color.black

    var size: (Int, Int) {
        // Short side = chosen resolution; long side rounded to even.
        if aspect.w == aspect.h { return (shortSide, shortSide) }
        if aspect.w < aspect.h {
            let h = Int((Double(shortSide) * Double(aspect.h) / Double(aspect.w) / 2).rounded()) * 2
            return (shortSide, h)
        }
        let w = Int((Double(shortSide) * Double(aspect.w) / Double(aspect.h) / 2).rounded()) * 2
        return (w, shortSide)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create").font(.system(size: 28, weight: .bold)).foregroundStyle(Theme.text).padding(.top, 24)

                VStack(alignment: .leading, spacing: 8) {
                    label("Project name")
                    TextField("Name", text: $name)
                        .padding(12).glass(radius: 12).foregroundStyle(Theme.text)
                }

                VStack(alignment: .leading, spacing: 10) {
                    label("Aspect ratio")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                        ForEach(Self.aspects) { a in
                            Button { aspect = a } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(aspect == a ? Theme.accentGlow : Theme.textDim, lineWidth: 1.5)
                                        .aspectRatio(CGFloat(a.w) / CGFloat(a.h), contentMode: .fit)
                                        .frame(height: 30)
                                    Text(a.label).font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(aspect == a ? Theme.accentGlow : Theme.textDim)
                                }
                                .frame(maxWidth: .infinity, minHeight: 62)
                                .background(RoundedRectangle(cornerRadius: 10).fill(aspect == a ? Theme.accent.opacity(0.18) : Theme.surface))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                row("Resolution") {
                    Picker("", selection: $shortSide) {
                        ForEach(Self.resolutions, id: \.short) { Text($0.label).tag($0.short) }
                    }
                }
                Text("Composition size \(size.0) × \(size.1)").font(.caption).foregroundStyle(Theme.textDim).padding(.top, -14)
                row("Frame rate") {
                    Picker("", selection: $fps) { ForEach(Self.rates, id: \.self) { Text("\(Int($0)) fps").tag($0) } }
                }
                row("Duration") {
                    Stepper("\(Int(duration)) s", value: $duration, in: 1...600).foregroundStyle(Theme.text)
                }
                row("Background") {
                    AWIColorWell("", selection: $background, supportsOpacity: true).labelsHidden()
                }

                Button("Create from scratch") {
                    let (w, h) = size
                    var p = Project.new(name: name.isEmpty ? "Untitled" : name, width: w, height: h, fps: fps,
                                        duration: duration, background: background.rgba)
                    p.autoLength = true   // length follows the layers, like Alight Motion
                    create(p)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func label(_ s: String) -> some View {
        Text(s).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textDim)
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack {
            Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.text)
            Spacer()
            content()
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glass(radius: 12)
    }
}


struct SharedFile: Identifiable { let id = UUID(); let url: URL }

/// System share sheet (AirDrop, Messages, Files…).
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
