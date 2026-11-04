import SwiftUI
import Photos
import AVFoundation

/// AWIeffect's own media picker. Reads your Photos library (after you allow it), so your Photos Favorites and
/// albums (your folders) are already there: Recents · Favorites · Videos · Photos · Albums. Tap to add.
@MainActor
final class PhotoLibraryModel: ObservableObject {
    enum Source: Hashable { case recents, favorites, videos, photos, album(String) }

    @Published var status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published var assets: [PHAsset] = []
    @Published var albums: [PHAssetCollection] = []
    @Published var source: Source = .recents
    let images = PHCachingImageManager()

    func start() {
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { s in
                Task { @MainActor in self.status = s; self.reload() }
            }
        } else { reload() }
    }

    var allowed: Bool { status == .authorized || status == .limited }

    func reload() {
        guard allowed else { return }
        var list: [PHAssetCollection] = []
        PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil).enumerateObjects { c, _, _ in
            if PHAsset.fetchAssets(in: c, options: nil).count > 0 { list.append(c) }
        }
        albums = list
        load(source)
    }

    func load(_ s: Source) {
        source = s
        guard allowed else { return }
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result: PHFetchResult<PHAsset>
        switch s {
        case .recents:
            opts.predicate = NSPredicate(format: "mediaType == %d || mediaType == %d", PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
            result = PHAsset.fetchAssets(with: opts)
        case .favorites:
            opts.predicate = NSPredicate(format: "favorite == YES")
            result = PHAsset.fetchAssets(with: opts)
        case .videos: result = PHAsset.fetchAssets(with: .video, options: opts)
        case .photos: result = PHAsset.fetchAssets(with: .image, options: opts)
        case .album(let id):
            guard let c = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [id], options: nil).firstObject else { assets = []; return }
            result = PHAsset.fetchAssets(in: c, options: opts)
        }
        var out: [PHAsset] = []
        out.reserveCapacity(min(result.count, 3000))
        result.enumerateObjects { a, i, stop in out.append(a); if i >= 2999 { stop.pointee = true } }
        assets = out
    }
}

struct MediaPickerView: View {
    @ObservedObject var state: EditorState
    @Binding var isPresented: Bool
    @StateObject private var lib = PhotoLibraryModel()
    var libraryOnly = false
    @State private var busy = false
    @State private var selected: [PHAsset] = []
    @State private var pending: [PHAsset] = []
    @State private var failed = 0
    @State private var currentAsset: PHAsset?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(libraryOnly ? "Import to My Library" : "Add Media").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                if busy { ProgressView().tint(Theme.accent) }
                else { Button("\(libraryOnly ? "Import" : "Add") (\(selected.count)/20)") { beginImport() }.disabled(selected.isEmpty) }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if lib.allowed {
                tabs
                if failed > 0 { Text("\(failed) items could not be imported. Check that they are downloaded from iCloud and try again.").font(.caption).foregroundStyle(Theme.danger) }
                grid
            } else if lib.status == .notDetermined {
                Spacer(); ProgressView().tint(Theme.accent); Spacer()
            } else {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 36)).foregroundStyle(Theme.textDim)
                    Text("Allow access to Photos in Settings to pick media here.").font(.system(size: 14)).foregroundStyle(Theme.textDim)
                    Button("Open Settings") { if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) } }
                        .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
                .padding()
            }
        }
        .onAppear { lib.start() }
    }

    private var tabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip("Recents", .recents, "clock")
                chip("Favorites", .favorites, "heart.fill")
                chip("Videos", .videos, "video.fill")
                chip("Photos", .photos, "photo")
                ForEach(lib.albums, id: \.localIdentifier) { a in
                    chip(a.localizedTitle ?? "Album", .album(a.localIdentifier), "folder.fill")
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 40)
    }

    private func chip(_ title: String, _ s: PhotoLibraryModel.Source, _ icon: String) -> some View {
        Button { lib.load(s) } label: {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Capsule().fill(lib.source == s ? Theme.accent : Theme.raised))
                .foregroundStyle(lib.source == s ? .white : Theme.text)
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
            if lib.assets.isEmpty {
                Text(lib.source == .favorites ? "No favorites yet: tap ♥ on a photo or video in the Photos app and it shows up here."
                                               : "Nothing here.")
                    .font(.system(size: 13)).foregroundStyle(Theme.textDim).padding(30)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 4), spacing: 3) {
                ForEach(lib.assets, id: \.localIdentifier) { a in
                    AssetThumb(asset: a, manager: lib.images)
                        .overlay(alignment: .topLeading) {
                            if let i = selected.firstIndex(where: { $0.localIdentifier == a.localIdentifier }) {
                                Text("\(i + 1)").font(.caption.bold()).padding(7).background(Circle().fill(Theme.accent)).foregroundStyle(.white)
                            }
                        }
                        .onTapGesture {
                            guard !busy else { return }
                            if let i = selected.firstIndex(where: { $0.localIdentifier == a.localIdentifier }) { selected.remove(at: i) }
                            else if selected.count < 20 { selected.append(a) }
                        }
                }
            }
            .padding(.horizontal, 3)
        }
    }

    private func beginImport() {
        guard !busy, !selected.isEmpty else { return }
        busy = true; failed = 0; pending = selected
        nextImport()
    }

    private func nextImport() {
        guard !pending.isEmpty else { busy = false; if failed == 0 { isPresented = false }; return }
        let asset = pending.removeFirst()
        currentAsset = asset
        pick(asset)
    }

    private func finish(_ success: Bool) {
        if !success { failed += 1 }
        else if let currentAsset { selected.removeAll { $0.localIdentifier == currentAsset.localIdentifier } }
        nextImport()
    }

    private func addMovie(_ url: URL) -> Bool {
        if libraryOnly { return UserLibrary.save(file: url) }
        state.addVideo(from: url); return true
    }
    private func addImage(_ data: Data, ext: String) -> Bool {
        if libraryOnly { return UserLibrary.save(data: data, ext: ext) }
        state.addImage(data: data, ext: ext); return true
    }

    private func pick(_ a: PHAsset) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if a.mediaType == .video {
            let o = PHVideoRequestOptions()
            o.isNetworkAccessAllowed = true
            o.deliveryMode = .highQualityFormat
            PHImageManager.default().requestAVAsset(forVideo: a, options: o) { av, _, _ in
                // Export to a file the importer can copy (works for slow-mo / edited videos too).
                guard let av else { Task { @MainActor in finish(false) }; return }
                let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                if let u = (av as? AVURLAsset)?.url {
                    Task { @MainActor in finish(addMovie(u)) }
                } else if let ex = AVAssetExportSession(asset: av, presetName: AVAssetExportPresetHighestQuality) {
                    ex.outputURL = out; ex.outputFileType = .mov
                    ex.exportAsynchronously {
                        Task { @MainActor in
                            finish(ex.status == .completed && addMovie(out))
                        }
                    }
                } else { Task { @MainActor in finish(false) } }
            }
        } else {
            let o = PHImageRequestOptions()
            o.isNetworkAccessAllowed = true
            o.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: a, options: o) { data, uti, _, _ in
                Task { @MainActor in
                    var success = false
                    if let data {
                        // HEIC etc. → PNG/JPEG so every part of the app can read it.
                        if let ui = UIImage(data: data), uti?.contains("heic") == true || uti?.contains("heif") == true, let j = ui.jpegData(compressionQuality: 0.95) {
                            success = addImage(j, ext: "jpg")
                        } else {
                            let ext = (uti?.contains("png") == true) ? "png" : "jpg"
                            success = addImage(data, ext: ext)
                        }
                    }
                    finish(success)
                }
            }
        }
    }
}

struct AssetThumb: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    @State private var image: UIImage?

    var body: some View {
        Theme.raised
            .aspectRatio(1, contentMode: .fit)
            .overlay { if let image { Image(uiImage: image).resizable().scaledToFill() } }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Text(String(format: "%d:%02d", Int(asset.duration) / 60, Int(asset.duration) % 60))
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.white).padding(4)
                        .shadow(radius: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if asset.isFavorite { Image(systemName: "heart.fill").font(.system(size: 9)).foregroundStyle(.white).padding(4).shadow(radius: 2) }
            }
            .contentShape(Rectangle())
            .onAppear {
                let o = PHImageRequestOptions()
                o.deliveryMode = .opportunistic
                o.isNetworkAccessAllowed = true
                manager.requestImage(for: asset, targetSize: CGSize(width: 240, height: 240), contentMode: .aspectFill, options: o) { img, _ in
                    if let img { image = img }
                }
            }
    }
}
