import SwiftUI
import simd

/// One skinning engine for both workflows. A cutout rig can enable deformation
/// per piece; a continuous PNG/vector keeps all its bones on one artwork layer.
enum BoneSkinWorkflow: String, Codable, Equatable {
    case rigPieces
    case boneWeight
}

struct BoneSkinBinding: Codable, Equatable, Identifiable {
    var jointID: UUID
    /// Joint pivot captured in the source artwork's unwarped local pixel space.
    var rest: Vec2
    /// 0 anchors this area at rest; 1 follows the joint fully.
    var influence: Double = 1
    var id: UUID { jointID }
}

struct BoneSkinSettings: Codable, Equatable {
    var workflow: BoneSkinWorkflow
    var enabled = true
    /// Controls how locally or softly the GPU's moving-least-squares warp responds.
    var sensitivity: Double = 1.2
    /// Global deformation intensity 0...1. Zero is a rigid layer.
    var deformation: Double = 1
    var bindings: [BoneSkinBinding] = []
}

enum BoneSkinRuntime {
    // The current Puppet MLS GPU kernel uses 32 input handles per artwork.
    // This is a per-layer GPU budget, not a limit on the skeleton's total bones.
    static let maximumWarpHandlesPerArtwork = 32

    /// A bone pivot in *artwork image pixels* (not camera/comp space).
    /// The artwork's parent affine includes its own transform and anchor, so
    /// local displacement remains correct under rotated parents and the camera.
    static func localJoint(_ id: UUID, artworkID: UUID, in project: Project, time: Double) -> Vec2? {
        guard let art = project.layers.first(where: { $0.id == artworkID }),
              let artFrame = Renderer.parentAffine(artworkID, in: project, time: time),
              let jointFrame = Renderer.parentAffine(id, in: project, time: time),
              abs(artFrame.m.determinant) > 1e-10,
              let relative = LayerPlacement.projected(.zero, by: artFrame.m.inverse * jointFrame.m) else { return nil }
        return relative + art.transform.anchor.value(at: time)
    }

    /// Auto-bind uses the exact same hierarchy for either mode.
    /// - A continuous image uses all the bone nulls authored for that image.
    /// - A cutout piece can be warped by itself, parent and neighboring joints.
    static func candidateIDs(for artworkID: UUID, mode: BoneSkinWorkflow, in project: Project) -> [UUID] {
        guard let art = project.layers.first(where: { $0.id == artworkID }) else { return [] }
        let authored = project.layers.filter { $0.bone?.artworkID == artworkID }
        if !authored.isEmpty {
            return Array(authored.map(\.id).reversed())
        }
        guard mode == .rigPieces else { return [] }
        var ids: [UUID] = []
        if let parent = art.parentID, project.layers.contains(where: { $0.id == parent }) { ids.append(parent) }
        ids.append(artworkID)
        // Direct children control the flexible edge of each separate image piece.
        ids.append(contentsOf: project.layers.filter { $0.parentID == artworkID }.map(\.id))
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    static func makeBindings(for artworkID: UUID, mode: BoneSkinWorkflow,
                             in project: Project, time: Double) -> [BoneSkinBinding] {
        candidateIDs(for: artworkID, mode: mode, in: project)
            .compactMap { id in
                guard let rest = localJoint(id, artworkID: artworkID, in: project, time: time) else { return nil }
                return BoneSkinBinding(jointID: id, rest: rest)
            }
    }

    /// Evaluated *only in a frame snapshot*. Never write posed pin coordinates
    /// back to the project's authoring/keyframe tracks.
    static func apply(to posed: Project, at time: Double) -> Project {
        guard posed.layers.contains(where: { $0.boneSkin?.enabled == true }) else { return posed }
        var result = posed
        for index in result.layers.indices {
            guard let skin = result.layers[index].boneSkin, skin.enabled, skin.deformation > 0,
                  skin.bindings.count > 1 else { continue }
            let artID = result.layers[index].id
            var fx = EffectRegistry.puppet18.makeInstance()
            fx.params["stiffness"] = .number(Animated(min(3, max(0.5, skin.sensitivity))))
            let blend = min(1, max(0, skin.deformation))
            var count = 0
            for binding in skin.bindings {
                if count >= maximumWarpHandlesPerArtwork { break }
                guard let pose = localJoint(binding.jointID, artworkID: artID, in: posed, time: time),
                      pose.x.isFinite, pose.y.isFinite,
                      binding.rest.x.isFinite, binding.rest.y.isFinite else { continue }
                let strength = min(1, max(0, binding.influence)) * blend
                let deformed = binding.rest + (pose - binding.rest) * strength
                fx.params["pinR\(count)"] = .point(Animated(binding.rest))
                fx.params["pinD\(count)"] = .point(Animated(deformed))
                count += 1
            }
            if count >= 2 {
                // This is a real GPU pixel warp using the existing Puppet MLS
                // kernel. Ordinary Puppet effects and authored FX stay intact.
                result.layers[index].effects.insert(fx, at: 0)
            }
        }
        return result
    }
}

extension EditorState {
    /// Whether the currently selected artwork (or selected bone's artwork) can receive a skin.
    var skinArtworkID: UUID? {
        guard let selected = selectedLayer else { return nil }
        if let bone = selected.bone { return bone.artworkID }
        if selected.isNull || selected.isGroup || selected.isAudioOnly ||
           selected.content == .camera || selected.content == .light ||
           selected.content == .adjustment { return nil }
        return selected.id
    }

    func autoBindSkin(artworkID: UUID, workflow: BoneSkinWorkflow) {
        guard let art = project.layers.first(where: { $0.id == artworkID }), !art.isLocked else { return }
        let evaluated = IKSolver.apply(project, time: currentTime)
        let found = BoneSkinRuntime.makeBindings(for: artworkID, mode: workflow, in: evaluated, time: currentTime)
        guard found.count >= 2 else {
            recoveryNotice = workflow == .boneWeight
                ? "Draw at least two connected bones on this artwork first. Select a bone tip to extend or branch."
                : "This piece needs two linked joints: connect it to the next piece or draw bones first."
            return
        }
        let bindings = Array(found.prefix(BoneSkinRuntime.maximumWarpHandlesPerArtwork))
        if found.count > bindings.count {
            recoveryNotice = "Bound the first \(bindings.count) handles to this image; use smaller artwork regions for very dense rigs."
        }
        mutate("Auto Bind Bone Weights") { p in
            guard let index = p.layers.firstIndex(where: { $0.id == artworkID }) else { return }
            let old = p.layers[index].boneSkin
            p.layers[index].boneSkin = BoneSkinSettings(
                workflow: workflow,
                enabled: true,
                sensitivity: old?.sensitivity ?? 1.2,
                deformation: old?.deformation ?? 1,
                bindings: bindings
            )
        }
    }

    /// Handy for the original Build 26 multi-piece workflow: deform the
    /// selected piece and its linked children without replacing its IK.
    func autoBindRigPieces(from artworkID: UUID) {
        let descendants = IKSolver.descendants(of: artworkID, in: project)
        let ids = [artworkID] + project.layers.filter {
            descendants.contains($0.id) &&
                !$0.isNull && !$0.isGroup && !$0.isAudioOnly
        }.map(\.id)
        let evaluated = IKSolver.apply(project, time: currentTime)
        let bindings: [(UUID, [BoneSkinBinding])] = ids.compactMap { id in
            let handles = BoneSkinRuntime.makeBindings(for: id, mode: .rigPieces, in: evaluated, time: currentTime)
            return handles.count >= 2 ? (id, Array(handles.prefix(BoneSkinRuntime.maximumWarpHandlesPerArtwork))) : nil
        }
        guard !bindings.isEmpty else {
            recoveryNotice = "Connect at least two artwork joints before auto-binding the rig's pieces."
            return
        }
        mutate("Auto Bind Rig Pieces") { p in
            for (id, handles) in bindings {
                guard let i = p.layers.firstIndex(where: { $0.id == id }), !p.layers[i].isLocked else { continue }
                let existing = p.layers[i].boneSkin
                p.layers[i].boneSkin = BoneSkinSettings(
                    workflow: .rigPieces, enabled: true,
                    sensitivity: existing?.sensitivity ?? 1.2,
                    deformation: existing?.deformation ?? 1,
                    bindings: handles
                )
            }
        }
    }
}
