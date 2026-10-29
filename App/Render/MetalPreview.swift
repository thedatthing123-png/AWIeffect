import SwiftUI
import MetalKit

/// Aspect-fit rect of a comp inside a container (points).
func fitRect(compWidth: Int, compHeight: Int, in size: CGSize) -> CGRect {
    guard compWidth > 0, compHeight > 0, size.width > 0, size.height > 0 else { return .zero }
    let s = min(size.width / CGFloat(compWidth), size.height / CGFloat(compHeight))
    let w = CGFloat(compWidth) * s, h = CGFloat(compHeight) * s
    return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
}

/// Live Metal preview of the composition. Renders at a proxy resolution matched to the on-screen size.
struct MetalPreview: UIViewRepresentable {
    let project: Project
    let time: Double
    let redrawToken: Int
    let mediaURL: (String) -> URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: Renderer.shared?.device)
        v.colorPixelFormat = .bgra8Unorm
        v.framebufferOnly = true
        v.enableSetNeedsDisplay = true
        v.isPaused = true
        v.preferredFramesPerSecond = 120
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
        v.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var project: Project?
        var time: Double = 0
        var mediaURL: ((String) -> URL)?
        private var comp: MTLTexture?
        /// Triple-buffered scratch pools so frames in flight never share textures.
        private lazy var pools: [TexturePool] = (0..<3).compactMap { _ in Renderer.shared?.makePool() }
        private var frame = 0
        private let inFlight = DispatchSemaphore(value: 3)

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { view.setNeedsDisplay() }

        func draw(in view: MTKView) {
            guard let r = Renderer.shared, let project, let mediaURL,
                  let drawable = view.currentDrawable, let rpd = view.currentRenderPassDescriptor,
                  let cb = r.queue.makeCommandBuffer() else { return }
            let ds = view.drawableSize
            let fit = fitRect(compWidth: project.width, compHeight: project.height, in: ds)
            // Proxy: never render more pixels than are displayed.
            let scale = min(1, Double(fit.width) / Double(project.width))
            let w = max(1, Int((Double(project.width) * scale).rounded()))
            let h = max(1, Int((Double(project.height) * scale).rounded()))
            if comp == nil || comp!.width != w || comp!.height != h {
                comp = r.makeCompTexture(width: w, height: h)
            }
            guard let comp, pools.count == 3 else { return }
            inFlight.wait()
            let pool = pools[frame % 3]
            frame += 1
            pool.recycle()
            let sem = inFlight
            cb.addCompletedHandler { _ in sem.signal() }
            r.encode(project: project, time: time, renderScale: scale, into: comp, commandBuffer: cb, pool: pool, mediaURL: mediaURL)

            rpd.colorAttachments[0].loadAction = .clear
            guard let enc = cb.makeRenderCommandEncoder(descriptor: rpd) else { return }
            enc.setViewport(MTLViewport(originX: Double(fit.minX), originY: Double(fit.minY),
                                        width: Double(fit.width), height: Double(fit.height), znear: 0, zfar: 1))
            enc.setRenderPipelineState(r.displayPSO)
            enc.setFragmentTexture(comp, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            enc.endEncoding()
            cb.present(drawable)
            cb.commit()
        }
    }
}
