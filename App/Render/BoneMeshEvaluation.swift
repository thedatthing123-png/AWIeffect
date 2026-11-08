import Foundation
import simd

/// Captures mesh palettes before hierarchy baking, so nested groups reuse the same pose instead of solving it again.
enum BoneMeshEvaluation {
    static func palette(_ binding: BoneMeshBinding, artworkID: UUID, posed: Project, time: Double) -> [RigAffine]? {
        guard !binding.boneIDs.isEmpty, binding.boneIDs.count <= 512,
              binding.inverseBinds.count == binding.boneIDs.count else { return nil }
        let nodes = Dictionary(posed.layers.map { ($0.id,$0) }, uniquingKeysWith: { first, _ in first })
        return binding.boneIDs.enumerated().map { index, id in
            guard let node = nodes[id],
                  let parent = EditorState.rigParentToArtwork(node, artworkID: artworkID, project: posed, time: time) else { return .identity }
            let matrix = RigAffine(parent * Renderer.layerMatrix(node, time: time, renderScale: 1) * binding.inverseBinds[index].matrix)
            return matrix.isFinite ? matrix : .identity
        }
    }

    /// Reconstruct the editable hierarchy for a shutter sample, rather than reposing a baked frame snapshot.
    static func sampleProject(_ binding: BoneMeshBinding, artworkID: UUID) -> Project? {
        guard let captured = binding.frameSource,
              let i = captured.project.layers.firstIndex(where: { $0.id == artworkID }) else { return nil }
        var source = captured.project
        var mesh = binding
        mesh.frameMatrices = nil; mesh.frameTime = nil; mesh.previewWeightIndex = nil
        // Keep the shared original frame source so nested sample renders can evaluate their own time.
        source.layers[i].boneMesh = mesh
        return source
    }

    static func prepare(_ project: inout Project, source: Project, time: Double) {
        let bound = project.layers.indices.filter { project.layers[$0].boneMesh != nil }
        guard !bound.isEmpty else { return }
        var sharedSource: BoneMeshFrameSource?
        // This immutable pre-bake value is shared by all palette evaluations in this frame.
        let current = project
        for i in bound {
            guard var binding = project.layers[i].boneMesh else { continue }
            if binding.frameTime == time, binding.frameMatrices?.count == binding.boneIDs.count { continue }
            let posed: Project
            if let captured = binding.frameSource {
                posed = AutoOrient.apply(IKSolver.apply(ExpressionResolver.resolve(captured.project, time: time), time: time), time: time)
            } else { posed = current }
            guard let matrices = palette(binding, artworkID: project.layers[i].id, posed: posed, time: time) else { continue }
            if binding.frameSource == nil {
                if sharedSource == nil { sharedSource = BoneMeshFrameSource(source) }
                binding.frameSource = sharedSource
            }
            binding.frameMatrices = matrices; binding.frameTime = time
            project.layers[i].boneMesh = binding
        }
    }
}
