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
    @State private var busy = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Media").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                Spacer()
                if busy { ProgressView().tint(Theme.accent) }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
            if lib.allowed {
                tabs
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
                        .onTapGesture { pick(a) }
                }
            }
            .padding(.horizontal, 3)
        }
    }

    private func pick(_ a: PHAsset) {
        guard !busy else { return }
        busy = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if a.mediaType == .video {
            let o = PHVideoRequestOptions()
            o.isNetworkAccessAllowed = true
            o.deliveryMode = .highQualityFormat
            PHImageManager.default().requestAVAsset(forVideo: a, options: o) { av, _, _ in
                // Export to a file the importer can copy (works for slow-mo / edited videos too).
                guard let av else { Task { @MainActor in busy = false }; return }
                let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                if let u = (av as? AVURLAsset)?.url {
                    Task { @MainActor in state.addVideo(from: u); busy = false; isPresented = false }
                } else if let ex = AVAssetExportSession(asset: av, presetName: AVAssetExportPresetHighestQuality) {
                    ex.outputURL = out; ex.outputFileType = .mov
                    ex.exportAsynchronously {
                        Task { @MainActor in
                            if ex.status == .completed { state.addVideo(from: out) }
                            busy = false; isPresented = false
                        }
                    }
                } else { Task { @MainActor in busy = false } }
            }
        } else {
            let o = PHImageRequestOptions()
            o.isNetworkAccessAllowed = true
            o.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImageDataAndOrientation(for: a, options: o) { data, uti, _, _ in
                Task { @MainActor in
                    if let data {
                        // HEIC etc. → PNG/JPEG so every part of the app can read it.
                        if let ui = UIImage(data: data), uti?.contains("heic") == true || uti?.contains("heif") == true, let j = ui.jpegData(compressionQuality: 0.95) {
                            state.addImage(data: j, ext: "jpg")
                        } else {
                            let ext = (uti?.contains("png") == true) ? "png" : "jpg"
                            state.addImage(data: data, ext: ext)
                        }
                    }
                    busy = false; isPresented = false
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
