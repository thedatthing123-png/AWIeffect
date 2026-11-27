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
    @State private var shareFiles: [URL] = []
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var importURL: URL?
    @State private var importResult: AEPImportResult?
    @State private var importError: String?
    /// A version waiting for the user to confirm the restore (project + version file).
    @State private var pendingRestore: (project: ProjectSummary, url: URL)?
    @State private var deleted: [DeletedProject] = []
    @State private var showDeleted = false
    @State private var search = ""
    @State private var source = ProjectSource.all
    @AppStorage("awi.homeSort") private var sortRaw = ProjectSort.modified.rawValue
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var pendingBulkDelete = false
    @State private var namingVersion: ProjectSummary?
    @State private var versionName = ""
    @State private var versionsRefresh = 0

    private var shown: [ProjectSummary] {
        ProjectSort.apply(ProjectSort(rawValue: sortRaw) ?? .modified, to: projects, search: search, source: source)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    listControls
                    if projects.isEmpty {
                        emptyState
                    } else if shown.isEmpty {
                        Text(search.trimmingCharacters(in: .whitespaces).isEmpty ? "No \(source.title) projects yet." : "No project matches “\(search)”.")
                            .font(.subheadline).foregroundStyle(Theme.textDim).padding(.vertical, 20)
                    }
                    ForEach(shown) { p in projectRow(p) }
                    if !deleted.isEmpty {
                        Button { showDeleted = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "trash").font(.system(size: 16, weight: .semibold)).frame(width: 34, height: 34)
                                    .foregroundStyle(Theme.textDim)
                                Text("Recently Deleted (\(deleted.count))").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.textDim)
                            }
                            .padding(12).frame(minHeight: 44).glass()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Recently Deleted")
                        .padding(.top, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            if selecting { selectionBar } else { dock }
        }
        .onAppear(perform: reload)
        .confirmationDialog("Delete \(selection.count) projects?", isPresented: $pendingBulkDelete, titleVisibility: .visible) {
            Button("Delete \(selection.count)", role: .destructive) {
                for id in selection { ProjectStore.shared.delete(id) }
                selection = []; selecting = false; reload()
            }
        } message: { Text("They move to Recently Deleted for 30 days, where you can restore them.") }

        .sheet(item: $shareFile) { f in ActivitySheet(items: [f.url]) }
        .sheet(isPresented: Binding(get: { !shareFiles.isEmpty }, set: { if !$0 { shareFiles = [] } })) { ActivitySheet(items: shareFiles) }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.aep, .xml, UTType(filenameExtension: "awi") ?? .data, .data]) { result in
            guard case .success(let url) = result else { return }
            importURL = url
            runImport()
        }
        .awiSheet(isPresented: Binding(get: { importResult != nil }, set: { if !$0 { importResult = nil } })) {
            if let r = importResult {
                ImportCompositionSheet(result: r) { id in
                    if id == r.report.selectedCompositionID { openImportedProject(r.project) }
                    else { runImport(compositionID: id) }
                }
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
                    let urls = versionsRefresh >= 0 ? ProjectStore.shared.versions(for: t.id) : []
                    Button { versionName = ""; namingVersion = t } label: {
                        Label("Save Named Version of Current State", systemImage: "bookmark").frame(minHeight: 44)
                    }
                    if urls.isEmpty { Text("No saved versions yet — they're made automatically while you edit.").foregroundStyle(Theme.textDim) }
                    ForEach(urls, id: \.self) { u in
                        Button { pendingRestore = (t, u) } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.black)
                                    if let img = ProjectStore.shared.versionThumbnail(u) { Image(uiImage: img).resizable().scaledToFit() }
                                    else { Image(systemName: "clock").foregroundStyle(Theme.textDim) }
                                }
                                .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ProjectStore.shared.versionName(u) ?? "Autosave").font(.system(size: 15, weight: .semibold))
                                    Text(((try? u.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()).formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(Theme.textDim)
                                }
                            }
                        }
                        .swipeActions { Button("Delete", role: .destructive) { ProjectStore.shared.deleteVersion(u); versionsRefresh += 1 } }
                    }
                }
                .navigationTitle("Restore \(t.name)").navigationBarTitleDisplayMode(.inline)
                .alert("Name this version", isPresented: Binding(get: { namingVersion != nil }, set: { if !$0 { namingVersion = nil } })) {
                    TextField("e.g. Before the drop", text: $versionName)
                    Button("Save") {
                        if let t = namingVersion, let proj = try? ProjectStore.shared.load(t.id) {
                            let n = versionName.trimmingCharacters(in: .whitespaces)
                            do { try ProjectStore.shared.saveNamedVersion(proj, name: n.isEmpty ? "Version" : n, thumbnail: t.thumbnail) }
                            catch { importError = "Couldn't save the version: " + error.localizedDescription }
                            versionsRefresh += 1
                        }
                        namingVersion = nil
                    }
                    Button("Cancel", role: .cancel) { namingVersion = nil }
                }
                .confirmationDialog("Restore this version?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                                    titleVisibility: .visible) {
                    Button("Restore") {
                        if let r = pendingRestore {
                            do { try ProjectStore.shared.restoreVersion(r.url, for: r.project.id) }
                            catch { importError = "Couldn't restore the version: " + error.localizedDescription }
                        }
                        pendingRestore = nil; reload(); versionsTarget = nil
                    }
                    Button("Cancel", role: .cancel) { pendingRestore = nil }
                } message: {
                    Text("The project as it is now is saved as a version first, so you can come back to it.")
                }
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
            }
            .presentationDetents([.medium])
        }
        .alert("Import failed", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(importError ?? "") }
        .awiSheet(isPresented: $showCreate) {
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
        } message: { _ in Text("It moves to Recently Deleted for 30 days, where you can restore it.") }
        .sheet(isPresented: $showDeleted, onDismiss: reload) { recentlyDeletedSheet }
    }

    private var header: some View {
        HStack(spacing: 4) {
            (Text("AWI").foregroundStyle(Theme.text) + Text("effect").italic().foregroundStyle(Theme.accentGlow))
                .font(.system(size: 26, weight: .heavy))
                .accessibilityLabel("AWIeffect")
            Spacer()
            if !projects.isEmpty {
                Button(selecting ? "Done" : "Select") { selecting.toggle(); selection = [] }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accentGlow)
                    .frame(minWidth: 52, minHeight: 44)
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").font(.system(size: 20, weight: .semibold)).foregroundStyle(Theme.text)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .awiSheet(isPresented: $showSettings) { SettingsSheet() }
    }

    /// Projects | New Project | Video Enhance.
    private var dock: some View {
        HStack(alignment: .bottom, spacing: 0) {
            dockItem("Projects", icon: "folder", active: true) {}
            Button { showCreate = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 52, height: 52).background(Circle().fill(Theme.accent).shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 2))
                    Text("New Project").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create New Project")
            // Video Enhance has no destination yet (END_PLAN), so it stays visibly unavailable.
            dockItem("Video Enhance", icon: "film", active: false, soon: true) {}
                .disabled(true)
        }
        .padding(.top, 6).padding(.bottom, 2)
        .background(Theme.background.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    private func dockItem(_ title: String, icon: String, active: Bool, soon: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: active ? icon + ".fill" : icon).font(.system(size: 22, weight: .medium))
                    .frame(height: 28)
                    .overlay(alignment: .topTrailing) {
                        if soon {
                            Text("SOON").font(.system(size: 8, weight: .heavy)).foregroundStyle(Theme.text)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Capsule().fill(Theme.raised)).overlay(Capsule().stroke(Theme.stroke))
                                .fixedSize().offset(x: 22, y: -4)
                        }
                    }
                Text(title).font(.system(size: 12, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(active ? Theme.accentGlow : Theme.textDim.opacity(soon ? 0.7 : 1))
            .frame(maxWidth: .infinity, minHeight: 50).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(soon ? "\(title), coming soon" : title)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles").font(.system(size: 36)).foregroundStyle(Theme.accentGlow)
            Text("No projects yet").font(.headline).foregroundStyle(Theme.text)
            Text("Tap + to start your first edit, or import an AEP / XML.").font(.subheadline).foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func projectRow(_ p: ProjectSummary) -> some View {
        Button {
            if selecting {
                if selection.contains(p.id) { selection.remove(p.id) } else { selection.insert(p.id) }
            } else if let proj = try? ProjectStore.shared.load(p.id) { open(proj) }
        } label: {
            HStack(spacing: 12) {
                if selecting {
                    Image(systemName: selection.contains(p.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22)).foregroundStyle(selection.contains(p.id) ? Theme.accent : Theme.textDim)
                }
                ProjectThumbnail(image: p.thumbnail)
                    .frame(width: 156, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.stroke))
                    .overlay(alignment: .bottomTrailing) {
                        Text(String(format: "%02d:%02d", Int(p.duration) / 60, Int(p.duration) % 60))
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.72)))
                            .foregroundStyle(.white).padding(5)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.text)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    let src = ProjectSource(p.importedFormat)
                    let frame = "\(p.width) × \(p.height)", rate = "\(Int(p.fps.rounded())) fps"
                    HStack(spacing: 6) {
                        SourceBadge(source: src)
                        // Longest variant that fits: source name only on imported projects, and only with room.
                        ViewThatFits(in: .horizontal) {
                            if src != .awi { Text("\(src.title) · \(frame)") }
                            Text("\(frame) · \(rate)")
                            Text(frame)
                        }
                        .lineLimit(1)
                    }
                    Text(p.modifiedAt.formatted(date: .abbreviated, time: .shortened)).lineLimit(1)
                }
                .font(.system(size: 13)).foregroundStyle(Theme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                if !selecting {
                    Menu { cardActions(p) } label: {
                        Image(systemName: "ellipsis").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                            .frame(width: 36, height: 48).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Actions for \(p.name)")
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("project-row")
        .contextMenu { cardActions(p) }
    }

    @ViewBuilder private func cardActions(_ p: ProjectSummary) -> some View {
            Button { renameText = p.name; renameTarget = p } label: { Label("Rename", systemImage: "character.cursor.ibeam") }
            Button { _ = try? ProjectStore.shared.duplicate(p.id); reload() } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Button { versionsTarget = p } label: { Label("Restore Version", systemImage: "clock.arrow.circlepath") }
            Button {
                if let proj = try? ProjectStore.shared.load(p.id), let url = try? ProjectPackage.export(proj) { shareFile = SharedFile(url: url) }
            } label: { Label("Share Project File (.awi)", systemImage: "square.and.arrow.up") }
            Button(role: .destructive) { pendingDelete = p } label: { Label("Delete", systemImage: "trash") }
    }

    /// Title + import, search + sort, then the source rail. Search, sort and source compose.
    private var listControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projects").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                Button { showImporter = true } label: {
                    Label("Import AEP / XML", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold)).lineLimit(1)
                        .padding(.horizontal, 12).frame(minHeight: 40)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accent.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.accent.opacity(0.7)))
                }
                .buttonStyle(.plain).foregroundStyle(Theme.text)
                .accessibilityHint(".aep, .ffx, Alight Motion .xml or .awi from Files")
            }
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.textDim)
                    TextField("Search projects", text: $search).foregroundStyle(Theme.text).submitLabel(.search)
                    if !search.isEmpty {
                        Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textDim).frame(width: 32, height: 40) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12).frame(height: 40).glass(radius: 10)
                Menu {
                    Picker("Sort", selection: $sortRaw) {
                        ForEach(ProjectSort.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Sort: \(ProjectSort(rawValue: sortRaw)?.title ?? "")").lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
                    .padding(.horizontal, 12).frame(height: 40).glass(radius: 10)
                }
                .fixedSize()
                .accessibilityLabel("Sort: \(ProjectSort(rawValue: sortRaw)?.title ?? "")")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ProjectSource.allCases) { s in
                        Button { source = s } label: {
                            Text(s.title).font(.system(size: 14, weight: source == s ? .semibold : .medium))
                                .foregroundStyle(source == s ? .white : Theme.textDim)
                                .padding(.horizontal, 14).frame(minHeight: 34)
                                .background(Capsule().fill(source == s ? Theme.accent : .clear))
                                .frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(source == s ? .isSelected : [])
                    }
                }
            }
        }
        .padding(.top, 14).padding(.bottom, 4)
    }

    /// Actions for the selected projects (3 buttons).
    private var selectionBar: some View {
        HStack(spacing: 8) {
            Button {
                for id in selection { _ = try? ProjectStore.shared.duplicate(id) }
                selection = []; selecting = false; reload()
            } label: { Label("Duplicate", systemImage: "plus.square.on.square").frame(maxWidth: .infinity, minHeight: 44) }
            Button {
                let urls = selection.compactMap { id in (try? ProjectStore.shared.load(id)).flatMap { try? ProjectPackage.export($0) } }
                if !urls.isEmpty { shareFiles = urls }
            } label: { Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44) }
            Button(role: .destructive) { pendingBulkDelete = true } label: {
                Label("Delete", systemImage: "trash").frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .disabled(selection.isEmpty)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.surface.ignoresSafeArea())
    }

    private func reload() {
        projects = ProjectStore.shared.list()
        deleted = ProjectStore.shared.deletedProjects()
    }

    /// Deleted projects (kept 30 days): restore or remove for good.
    private var recentlyDeletedSheet: some View {
        NavigationStack {
            List {
                if deleted.isEmpty { Text("Nothing here.").foregroundStyle(Theme.textDim) }
                ForEach(deleted) { d in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(d.summary.name).font(.system(size: 15, weight: .semibold))
                            let left = max(0, Int(((ProjectStore.deletedRetention - Date().timeIntervalSince(d.deletedAt)) / 86_400).rounded(.up)))
                            Text("\(left) day\(left == 1 ? "" : "s") left").font(.caption).foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Button("Restore") {
                            do { try ProjectStore.shared.restoreDeleted(d.id) }
                            catch { importError = "Couldn't restore: " + error.localizedDescription }
                            reload()
                        }
                        .buttonStyle(.borderless).frame(minHeight: 44)
                    }
                    .swipeActions {
                        Button("Delete Now", role: .destructive) { ProjectStore.shared.deletePermanently(d.id); reload() }
                    }
                }
            }
            .navigationTitle("Recently Deleted").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDeleted = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func runImport(compositionID: UInt32? = nil) {
        guard let url = importURL else { return }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            if ProjectPackage.isPackage(data) {
                // A project shared from AWIeffect: opens exactly as it was saved.
                let p = try ProjectPackage.importPackage(data)
                reload()
                open(p)
                return
            }
            let name = url.deletingPathExtension().lastPathComponent
            if AMImporter.isAMProject(data) {
                openImportedProject(try AMImporter.load(data: data, fallbackName: name).project)
            } else {
                let result = try AEPImporter.importData(data, projectName: name, compositionID: compositionID)
                if compositionID == nil && result.report.compositions.count > 1 {
                    importResult = result
                } else {
                    openImportedProject(result.project)
                }
            }
        } catch {
            importResult = nil
            importError = error.localizedDescription
        }
    }

    private func openImportedProject(_ project: Project) {
        do {
            try ProjectStore.shared.save(project)
            importResult = nil
            open(project)
        } catch {
            importResult = nil
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
    @State private var aspect = aspects.first { $0.label == AppSettings.defaultAspect } ?? aspects[0]
    @State private var shortSide = AppSettings.defaultShortSide
    @State private var fps: Double = AppSettings.defaultFPS
    /// No duration to pick (Alight Motion): the project is as long as its clips; new layers start at 5 s.
    private let duration: Double = 5
    @State private var background = Color.black
    /// Custom composition size (any width × height).
    @State private var custom = false
    @State private var customW = "1080"
    @State private var customH = "1920"

    var size: (Int, Int) {
        if custom {
            let w = min(8192, max(16, (Int(customW) ?? 1080) / 2 * 2)), h = min(8192, max(16, (Int(customH) ?? 1920) / 2 * 2))
            return (w, h)
        }
        // Short side = chosen resolution; long side rounded to even.
        if aspect.w == aspect.h { return (shortSide, shortSide) }
        if aspect.w < aspect.h {
            let h = Int((Double(shortSide) * Double(aspect.h) / Double(aspect.w) / 2).rounded()) * 2
            return (shortSide, h)
        }
        let w = Int((Double(shortSide) * Double(aspect.w) / Double(aspect.h) / 2).rounded()) * 2
        return (w, shortSide)
    }

    private func sizeField(_ label: String, _ v: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textDim)
            TextField("", text: v).keyboardType(.numberPad).font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.text)
        }
        .padding(.horizontal, 12).frame(height: 42).glass(radius: 10)
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

                if !custom {
                    row("Resolution") {
                        Picker("", selection: $shortSide) {
                            ForEach(Self.resolutions, id: \.short) { Text($0.label).tag($0.short) }
                        }
                    }
                }
                Toggle("Custom size", isOn: $custom).tint(Theme.accent).foregroundStyle(Theme.text)
                if custom {
                    HStack(spacing: 10) {
                        sizeField("Width", $customW)
                        Text("×").foregroundStyle(Theme.textDim)
                        sizeField("Height", $customH)
                    }
                }
                Text("Composition size \(size.0) × \(size.1)").font(.caption).foregroundStyle(Theme.textDim).padding(.top, -14)
                row("Frame rate") {
                    Picker("", selection: $fps) { ForEach(Self.rates, id: \.self) { Text("\(Int($0)) fps").tag($0) } }
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

/// Project list ordering (search matches the name, case- and accent-insensitive).
enum ProjectSort: String, CaseIterable, Identifiable {
    case modified, name, size, duration
    var id: String { rawValue }
    var title: String {
        switch self {
        case .modified: return "Last Edited"
        case .name: return "Name"
        case .size: return "Largest Frame"
        case .duration: return "Longest"
        }
    }

    static func apply(_ sort: ProjectSort, to list: [ProjectSummary], search: String, source: ProjectSource = .all) -> [ProjectSummary] {
        let q = search.trimmingCharacters(in: .whitespaces)
        let filtered = list.filter { source.matches($0) && (q.isEmpty || $0.name.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil) }
        switch sort {
        case .modified: return filtered.sorted { $0.modifiedAt > $1.modifiedAt }
        case .name: return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size: return filtered.sorted { $0.width * $0.height > $1.width * $1.height }
        case .duration: return filtered.sorted { $0.duration > $1.duration }
        }
    }
}

/// Home source filter, read from the stored `importedFormat` (nil = native AWI).
enum ProjectSource: String, CaseIterable, Identifiable {
    case all, awi, afterEffects, alightMotion
    var id: String { rawValue }

    init(_ format: ImportedProjectFormat?) {
        switch format {
        case nil: self = .awi
        case .afterEffects?: self = .afterEffects
        case .alightMotion?: self = .alightMotion
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .awi: return "AWI"
        case .afterEffects: return "After Effects"
        case .alightMotion: return "Alight Motion"
        }
    }

    var badge: String {
        switch self {
        case .all: return ""
        case .awi: return "AWI"
        case .afterEffects: return "AE"
        case .alightMotion: return "AM"
        }
    }

    func matches(_ p: ProjectSummary) -> Bool { self == .all || self == ProjectSource(p.importedFormat) }
}

struct SourceBadge: View {
    let source: ProjectSource
    var body: some View {
        Text(source.badge)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.accentGlow)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Theme.accent.opacity(0.2)))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.accent.opacity(0.55)))
            .fixedSize()
            .accessibilityLabel(source.title)
    }
}

/// Wide row thumbnail. Wide renders fill the frame; taller ones (9:16, 4:5, 1:1) fit inside over a
/// blurred copy, so titles and subjects at the top or bottom of a vertical edit stay visible.
struct ProjectThumbnail: View {
    let image: UIImage?
    #if DEBUG
    /// UI-test comparison only: crop everything to the frame.
    static let forceCrop = ProcessInfo.processInfo.arguments.contains("-uiTesting-homeCrop")
    #else
    static let forceCrop = false
    #endif

    var body: some View {
        Color.black.overlay {
            if let image {
                if Self.forceCrop || image.size.width / max(image.size.height, 1) >= 1.6 {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Image(uiImage: image).resizable().scaledToFill().blur(radius: 14).opacity(0.55)
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                }
            } else {
                Image(systemName: "film").font(.system(size: 22)).foregroundStyle(Theme.textDim.opacity(0.6))
            }
        }
        .clipped()
    }
}
