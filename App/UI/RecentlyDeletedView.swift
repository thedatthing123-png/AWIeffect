import SwiftUI

/// Recently Deleted as its own Home page: one-tap restore or delete per row, multi-select,
/// and Restore All / Delete All. Permanent deletes always confirm.
struct RecentlyDeletedView: View {
    let items: [DeletedProject]
    let close: () -> Void
    /// Called after anything changes on disk so Home reloads its lists.
    let changed: () -> Void

    @State private var selecting = false
    @State private var selection = Set<UUID>()
    /// Projects waiting for the permanent-delete confirmation.
    @State private var pendingDelete: [UUID] = []
    @State private var error: String?

    private var selected: [UUID] { items.map(\.id).filter(selection.contains) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button(action: close) {
                    Label("Projects", systemImage: "chevron.left").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.accentGlow).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Projects")
                Spacer()
                if !items.isEmpty {
                    Button(selecting ? "Done" : "Select") { selecting.toggle(); selection = [] }
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accentGlow)
                        .frame(minWidth: 52, minHeight: 44)
                }
            }
            .padding(.horizontal, 16).padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Recently Deleted").font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.text)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("Projects stay here for 30 days, then they're removed for good.")
                        .font(.system(size: 13)).foregroundStyle(Theme.textDim).padding(.top, 4).padding(.bottom, 10)
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "trash").font(.system(size: 34)).foregroundStyle(Theme.textDim)
                            Text("Nothing here").font(.headline).foregroundStyle(Theme.text)
                            Text("Deleted projects wait here so you can bring them back.").font(.subheadline)
                                .foregroundStyle(Theme.textDim).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 60)
                    }
                    ForEach(items) { row($0) }
                }
                .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 24)
            }
            if !items.isEmpty { actionBar }
        }
        .background(Theme.background.ignoresSafeArea())
        .confirmationDialog(pendingDelete.count == 1 ? "Delete this project permanently?" : "Delete \(pendingDelete.count) projects permanently?",
                            isPresented: Binding(get: { !pendingDelete.isEmpty }, set: { if !$0 { pendingDelete = [] } }),
                            titleVisibility: .visible) {
            Button(pendingDelete.count == 1 ? "Delete Permanently" : "Delete \(pendingDelete.count) Permanently", role: .destructive) {
                for id in pendingDelete { ProjectStore.shared.deletePermanently(id) }
                pendingDelete = []; finish()
            }
            Button("Cancel", role: .cancel) { pendingDelete = [] }
        } message: { Text("This can't be undone.") }
        .alert("Couldn't restore", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(error ?? "") }
    }

    private func row(_ d: DeletedProject) -> some View {
        let p = d.summary
        let left = max(0, Int(((ProjectStore.deletedRetention - Date().timeIntervalSince(d.deletedAt)) / 86_400).rounded(.up)))
        return Button {
            // A row tap starts selection with that row, so picking several never needs a separate first step.
            selecting = true
            if selection.contains(p.id) { selection.remove(p.id) } else { selection.insert(p.id) }
        } label: {
            HStack(spacing: 12) {
                if selecting {
                    Image(systemName: selection.contains(p.id) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22)).foregroundStyle(selection.contains(p.id) ? Theme.accent : Theme.textDim)
                }
                ProjectThumbnail(image: p.thumbnail)
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Theme.stroke))
                    .opacity(0.8)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text).lineLimit(2)
                    HStack(spacing: 6) {
                        SourceBadge(source: ProjectSource(p.importedFormat))
                        Text("\(left) day\(left == 1 ? "" : "s") left")
                            .foregroundStyle(left <= 3 ? Theme.warning : Theme.textDim).lineLimit(1)
                    }
                }
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                if !selecting {
                    Button { restore([p.id]) } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accentGlow).frame(width: 40, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Restore \(p.name)")
                    Button { pendingDelete = [p.id] } label: {
                        Image(systemName: "trash").font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.danger).frame(width: 40, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete \(p.name) permanently")
                }
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.stroke).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("deleted-row")
    }

    /// Restore All / Delete All, or the same two actions for the selection.
    private var actionBar: some View {
        HStack(spacing: 10) {
            if selecting {
                let all = selection.count == items.count
                Button(all ? "Deselect All" : "Select All") { selection = all ? [] : Set(items.map(\.id)) }
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.accentGlow)
                    .frame(minWidth: 88, minHeight: 44)
            }
            let ids = selecting ? selected : items.map(\.id)
            Button { restore(ids) } label: {
                Label(selecting ? "Restore (\(ids.count))" : "Restore All", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.accent.opacity(ids.isEmpty ? 0.3 : 1)))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            Button { pendingDelete = ids } label: {
                Label(selecting ? "Delete (\(ids.count))" : "Delete All", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.danger.opacity(ids.isEmpty ? 0.3 : 0.8)))
                    .foregroundStyle(Theme.danger.opacity(ids.isEmpty ? 0.4 : 1))
            }
            .buttonStyle(.plain)
        }
        .disabled(selecting && selection.isEmpty)
        .font(.system(size: 14, weight: .semibold))
        .lineLimit(1).minimumScaleFactor(0.85)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 1) }
    }

    private func restore(_ ids: [UUID]) {
        var failed: [String] = []
        for id in ids {
            do { try ProjectStore.shared.restoreDeleted(id) }
            catch { failed.append(items.first { $0.id == id }?.summary.name ?? "A project") }
        }
        if !failed.isEmpty { error = "\(failed.joined(separator: ", ")) couldn't be restored." }
        finish()
    }

    private func finish() {
        selection = []; selecting = false
        changed()
    }
}
