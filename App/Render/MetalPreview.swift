import SwiftUI
import MetalKit

/// Aspect-fit rect of a comp inside a container (points).
func fitRect(compWidth: Int, compHeight: Int, in size: CGSize) -> CGRect {
    guard compWidth > 0, compHeight > 0, size.width > 0, size.height > 0 else { return .zero }
    let s = min(size.width / CGFloat(compWidth), size.height / CGFloat(compHeight))
    let w = CGFloat(compWidth) * s, h = CGFloat(compHeight) * s
    return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
}

/// Which frames are ready in the RAM preview (AE's green bar on the timeline ruler).
@MainActor
final class PreviewCacheMonitor: ObservableObject {
    static let shared = PreviewCacheMonitor()
    @Published var frames = IndexSet()
    @Published var fps: Double = 30
}

/// Live Metal preview of the composition. Renders at a proxy resolution matched to the on-screen size.
struct MetalPreview: UIViewRepresentable {
    let project: Project
    let time: Double
    let redrawToken: Int
    let mediaURL: (String) -> URL
    var viewZoom: CGFloat = 1
    var viewPan: CGSize = .zero
    var qualityCap: Double = 1
    /// While playing the preview may drop resolution to keep up; paused frames always settle at full quality.
    var isPlaying = false
    /// Frames rendered at full quality are remembered (RAM preview) until the project changes.
    var cacheEnabled = true

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: Renderer.shared?.device)
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = true
        v.enableSetNeedsDisplay = true
        v.isPaused = true
        v.preferredFramesPerSecond = 120
        // 2x backing store: indistinguishable on a phone preview, ~45% fewer pixels than 3x.
        v.contentScaleFactor = min(UIScreen.main.scale, 2)
        v.clearColor = MTLClearColor(red: 0.055, green: 0.043, blue: 0.078, alpha: 1)
        v.backgroundColor = .clear
        v.isOpaque = false
        v.delegate = context.coordinator
        return v
    }

    func updateUIView(_ v: MTKView, context: Context) {
        context.coordinator.project = project
        context.coordinator.time = time
        context.coordinator.mediaURL = mediaURL
        context.coordinator.viewZoom = viewZoom
        context.coordinator.qualityCap = qualityCap
        context.coordinator.isPlaying = isPlaying
        context.coordinator.cacheEnabled = cacheEnabled
        context.coordinator.viewPan = CGSize(width: viewPan.width * v.contentScaleFactor, height: viewPan.height * v.contentScaleFactor)
        v.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var project: Project?
        var time: Double = 0
        var mediaURL: ((String) -> URL)?
        var viewZoom: CGFloat = 1
        var viewPan: CGSize = .zero
        var qualityCap: Double = 1
        var isPlaying = false
        var cacheEnabled = true
        private var comp: MTLTexture?
        /// Triple-buffered scratch pools so frames in flight never share textures.
        private lazy var pools: [TexturePool] = (0..<3).compactMap { _ in Renderer.shared?.makePool() }
        private var frame = 0
        private let inFlight = DispatchSemaphore(value: 2)
        /// Adaptive preview resolution (AE-style): drops while frames are heavy, sharpens when there's headroom
        /// and re-renders at full quality once playback / scrubbing stops.
        private var quality: Double = 1
        private var pendingRedraw = false
        private var settleWork: DispatchWorkItem?
        private var forceFull = false
        /// Consecutive heavy / light frames: quality only changes after a run of them (no sharp/soft flicker).
        private var heavyRun = 0
        private var lightRun = 0

        // RAM preview cache: full-quality frames keyed by frame index, dropped whenever the project changes.
        private var cache: [Int: MTLTexture] = [:]
        private var cacheOrder: [Int] = []
        private var cacheToken = ""
        private var cacheBytes = 0
        private static let cacheBudget = 140 * 1024 * 1024

        override init() {
            super.init()
            NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
                self?.cache.removeAll(); self?.cacheOrder.removeAll(); self?.cacheBytes = 0
                self?.pools.forEach { $0.purge() }
                self?.quality = min(self?.quality ?? 1, 0.5)
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.setNeedsDisplay() }

        private func token(_ p: Project, _ w: Int, _ h: Int) -> String {
            "\(p.id)|\(p.modifiedAt.timeIntervalSinceReferenceDate)|\(p.layers.count)|\(w)x\(h)"
        }

        private func remember(_ tex: MTLTexture, frame idx: Int) {
            if cache[idx] == nil { cacheOrder.append(idx); cacheBytes += tex.width * tex.height * 8 }
            cache[idx] = tex
            while cacheBytes > Self.cacheBudget, let old = cacheOrder.first {
                cacheOrder.removeFirst()
                if let t = cache.removeValue(forKey: old) { cacheBytes -= t.width * t.height * 8 }
            }
            publishCache()
        }

        private func publishCache() {
            let set = IndexSet(cache.keys)
            let fps = project?.fps ?? 30
            Task { @MainActor in
                let m = PreviewCacheMonitor.shared
                if m.frames != set { m.frames = set }
                if m.fps != fps { m.fps = fps }
            }
        }

        // MARK: Background render (AE-style): while paused, render the frames after the playhead at full quality.
        private var prerenderWork: DispatchWorkItem?
        private var prerenderToken = ""
        private lazy var prerenderPool: TexturePool? = Renderer.shared?.makePool()

        private func schedulePrerender(from start: Int, size: (Int, Int), scale: Double) {
            prerenderWork?.cancel()
            guard cacheEnabled, !isPlaying, let project else { return }
            let token = cacheToken
            prerenderToken = token
            let last = min(Int((project.duration * max(project.fps, 1)).rounded(.down)) - 1, start + Int(max(project.fps, 1) * 3))
            var next = start + 1
            func step() {
                // Stop as soon as anything changes (editing, playing, another frame, memory).
                guard self.prerenderToken == token, self.cacheToken == token, !self.isPlaying, next <= last,
                      let r = Renderer.shared, let p = self.project, let media = self.mediaURL, let pool = self.prerenderPool else { return }
                while next <= last, self.cache[next] != nil { next += 1 }
                guard next <= last, self.cacheBytes < Self.cacheBudget * 9 / 10,
                      let tex = r.makeCompTexture(width: size.0, height: size.1), let cb = r.queue.makeCommandBuffer() else { return }
                pool.recycle()
                Renderer.blurSampleCap = 12
                r.encode(project: p, time: Double(next) / max(p.fps, 1), renderScale: scale, into: tex, commandBuffer: cb, pool: pool, mediaURL: media)
                let idx = next
                cb.addCompletedHandler { [weak self] _ in
                    DispatchQueue.main.async {
                        guard let self, self.cacheToken == token else { return }
                        self.remember(tex, frame: idx)
                        // One frame at a time, with a breath between, so the UI never stutters.
                        let w = DispatchWorkItem { step() }
                        self.prerenderWork = w
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012, execute: w)
                    }
                }
                cb.commit()
                next += 1
            }
            let w = DispatchWorkItem { step() }
            prerenderWork = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: w)
        }

        func draw(in view: MTKView) {
            guard let r = Renderer.shared, let project, let mediaURL,
                  let drawable = view.currentDrawable, let rpd = view.currentRenderPassDescriptor,
                  let cb = r.queue.makeCommandBuffer() else { return }
            let ds = view.drawableSize
            let base = fitRect(compWidth: project.width, compHeight: project.height, in: ds)
            let fit = CGRect(x: base.midX - base.width * viewZoom / 2 + viewPan.width, y: base.midY - base.height * viewZoom / 2 + viewPan.height,
                             width: base.width * viewZoom, height: base.height * viewZoom)
            let fullScale = min(1, Double(fit.width) / Double(project.width)) * qualityCap
            let fw = max(1, Int((Double(project.width) * fullScale).rounded()))
            let fh = max(1, Int((Double(project.height) * fullScale).rounded()))
            let frameIdx = Int((time * max(project.fps, 1)).rounded())
            // Always render exactly on a frame (like export). Mixing in-between times with cached whole frames made
            // keyframed layers and the camera jitter against the footage.
            let frameTime = Double(frameIdx) / max(project.fps, 1)

            // Project edited / view resized: forget cached frames.
            let tk = token(project, fw, fh)
            if tk != cacheToken { cache.removeAll(); cacheOrder.removeAll(); cacheBytes = 0; cacheToken = tk; prerenderWork?.cancel(); publishCache() }

            // Never block the main thread waiting on the GPU: skip this frame and redraw when one finishes.
            if inFlight.wait(timeout: .now()) == .timedOut {
                pendingRedraw = true
                return
            }
            let sem = inFlight
            var shown: MTLTexture? = cacheEnabled ? cache[frameIdx] : nil
            var renderedFull = false
            var rendered = false
            if shown == nil {
                let steps: [Double] = [1, 0.75, 0.5, 0.35, 0.25]
                let q = forceFull ? 1 : (steps.first { $0 <= quality + 1e-6 } ?? 0.25)
                let scale = fullScale * q
                let w = max(1, Int((Double(project.width) * scale).rounded()))
                let h = max(1, Int((Double(project.height) * scale).rounded()))
                renderedFull = q >= 0.999
                let target: MTLTexture
                if renderedFull && cacheEnabled {
                    guard let t = r.makeCompTexture(width: w, height: h) else { sem.signal(); return }
                    target = t
                } else {
                    if comp == nil || comp!.width != w || comp!.height != h { comp = r.makeCompTexture(width: w, height: h) }
                    guard let c = comp else { sem.signal(); return }
                    target = c
                }
                guard pools.count == 3 else { sem.signal(); return }
                let pool = pools[frame % 3]
                frame += 1
                pool.recycle()
                // Preview: lighter motion blur while playing, finer when paused (export always renders the full count).
                Renderer.blurSampleCap = isPlaying ? 4 : (renderedFull ? 12 : 6)
                r.encode(project: project, time: frameTime, renderScale: scale, into: target, commandBuffer: cb, pool: pool, mediaURL: mediaURL)
                if renderedFull && cacheEnabled { remember(target, frame: frameIdx) }
                shown = target
                rendered = true
            }
            forceFull = false
            let playing = isPlaying
            let full = renderedFull
            if full && !playing && cacheEnabled { schedulePrerender(from: frameIdx, size: (fw, fh), scale: fullScale) }
            if playing { prerenderWork?.cancel() }
            cb.addCompletedHandler { [weak self, weak view] buffer in
                sem.signal()
                let gpu = buffer.gpuEndTime - buffer.gpuStartTime
                DispatchQueue.main.async {
                    guard let self else { return }
                    if rendered {
                        // Budget ≈16 ms (60 fps): heavy frames drop resolution (down to 1/4 while playing), light ones recover.
                        let floor = playing ? 0.25 : 0.5
                        if gpu > 0.018 { self.heavyRun += 1; self.lightRun = 0 } else if gpu < 0.008 { self.lightRun += 1; self.heavyRun = 0 } else { self.heavyRun = 0; self.lightRun = 0 }
                        if self.heavyRun >= 3 || gpu > 0.05 { self.quality = max(floor, self.quality * (gpu > 0.04 ? 0.7 : 0.85)); self.heavyRun = 0 }
                        else if self.lightRun >= 12 && !playing && self.cacheEnabled { self.quality = min(1, self.quality * 1.15); self.lightRun = 0 }
                    }
                    if self.pendingRedraw { self.pendingRedraw = false; view?.setNeedsDisplay() }
                    // Settle: when nothing changes for a moment, show this frame at full quality.
                    if rendered && !full && !playing {
                        self.settleWork?.cancel()
                        let w = DispatchWorkItem { [weak self, weak view] in self?.forceFull = true; view?.setNeedsDisplay() }
                        self.settleWork = w
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: w)
                    }
                }
            }
            guard let tex = shown else { cb.commit(); return }
            rpd.colorAttachments[0].loadAction = .clear
            guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { cb.commit(); return }
            enc.setViewport(MTLViewport(originX: Double(fit.minX), originY: Double(fit.minY),
                                        width: Double(fit.width), height: Double(fit.height), znear: 0, zfar: 1))
            enc.setRenderPipelineState(r.displayPSO)
            enc.setFragmentTexture(tex, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
            cb.present(drawable)
            cb.commit()
        }
    }
}
