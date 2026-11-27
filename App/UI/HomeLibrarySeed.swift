#if DEBUG
import Foundation

/// UI-test library for Home screenshots (`-uiTesting-homeLibrary`, `-uiTesting-homeEmpty`).
/// Existing projects move to Recently Deleted (restorable); seeds are saved and thumbnailed
/// through the normal ProjectStore + Renderer path, and the Alight Motion one goes through AMImporter.
enum HomeLibrarySeed {
    static func runIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-uiTesting-homeLibrary") || args.contains("-uiTesting-homeEmpty") else { return }
        let store = ProjectStore.shared
        for p in store.list() { store.delete(p.id) }
        guard args.contains("-uiTesting-homeLibrary") else { return }

        var trashed = Project.new(name: "Old Draft", width: 1080, height: 1920, fps: 30, duration: 3)
        trashed.layers = [trashed.makeLayer(name: "bg", content: .solid, size: Vec2(1080, 1920))]
        save(trashed, age: 9_000)
        store.delete(trashed.id)

        // 9:16 with titles near the top and bottom: the framing check for vertical edits.
        var vertical = Project.new(name: "Rooftop Flow Edit", width: 1080, height: 1920, fps: 30, duration: 14, background: RGBA(hex: 0x1A0F33))
        vertical.layers = [
            text(&vertical, "NEON", at: Vec2(540, 260), size: 210, color: RGBA(hex: 0xF2EEF8)),
            shape(&vertical, .star, at: Vec2(540, 960), size: 620, color: RGBA(hex: 0x9B5CFF)),
            text(&vertical, "FLOW", at: Vec2(540, 1680), size: 210, color: RGBA(hex: 0xFFB84D)),
        ]
        save(vertical, age: 600)

        var wide = Project.new(name: "Opening Titles", width: 1920, height: 1080, fps: 24, duration: 42, background: RGBA(hex: 0x0F1A2E))
        wide.importedFormat = .afterEffects
        wide.layers = [
            shape(&wide, .ellipse, at: Vec2(1500, 540), size: 700, color: RGBA(hex: 0x5C8CFF)),
            text(&wide, "TITLES", at: Vec2(760, 540), size: 240, color: RGBA(hex: 0xF2EEF8)),
        ]
        save(wide, age: 3_600)

        let xml = """
        <scene title="Velocity Intro with an extra long name for narrow phones" width="1080" height="1350" fps="60" totalTime="8000" bgcolor="#2B1240">
          <shape label="Disc" type="ellipse" startTime="0" endTime="8000" fillColor="#ff5ca8"/>
        </scene>
        """
        if var am = try? AMImporter.load(data: Data(xml.utf8), fallbackName: "Velocity Intro").project {
            if am.layers.isEmpty { am.layers = [shape(&am, .polygon, at: Vec2(540, 675), size: 700, color: RGBA(hex: 0xFF5CA8))] }
            save(am, age: 86_400)
        }

        var square = Project.new(name: "Square Loop", width: 1080, height: 1080, fps: 30, duration: 6, background: RGBA(hex: 0x0E2A24))
        square.layers = [shape(&square, .rectangle, at: Vec2(540, 540), size: 560, color: RGBA(hex: 0x3FD6C6))]
        save(square, age: 172_800)
    }

    private static func save(_ project: Project, age: TimeInterval) {
        var p = project
        p.modifiedAt = Date().addingTimeInterval(-age)
        let store = ProjectStore.shared
        try? store.save(p)
        if let img = Renderer.shared?.renderImage(project: p, time: 0, maxDimension: 360, mediaURL: { store.mediaURL($0, projectID: p.id) }) {
            store.saveThumbnail(img, for: p.id)
        }
    }

    private static func text(_ p: inout Project, _ s: String, at: Vec2, size: Double, color: RGBA) -> Layer {
        var l = p.makeLayer(name: s, content: .text, size: Vec2(Double(p.width), size * 1.3))
        var t = TextData(string: s, fontSize: size)
        t.fill = Animated(color); t.ensureCharIDs()
        l.text = t
        l.transform.position = Animated(at)
        return l
    }

    private static func shape(_ p: inout Project, _ kind: ShapeKind, at: Vec2, size: Double, color: RGBA) -> Layer {
        var l = p.makeLayer(name: kind.title, content: .shape(kind), size: Vec2(size, size))
        l.fill = Animated(color)
        l.transform.position = Animated(at)
        return l
    }
}
#endif
