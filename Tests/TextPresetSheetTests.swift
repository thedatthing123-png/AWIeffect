import XCTest
import UIKit
@testable import AWIeffect

/// Renders every text preset (5 frames across its animation) and every look into one review sheet, uploaded by CI
/// with the effect contact sheet, so each preset's design can be judged by eye — not just "it animates".
final class TextPresetSheetTests: XCTestCase {
    func testWriteTextPresetSheet() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device; preset sheet not generated") }
        let presets = TextPresetLibrary.animations
        let looks = TextPresetLibrary.looks
        let fw: CGFloat = 150, fh: CGFloat = 70, frames = 5, label: CGFloat = 18
        let rowH = fh + label
        let size = CGSize(width: fw * CGFloat(frames), height: CGFloat(presets.count + looks.count) * rowH)

        func project(_ edit: (inout Layer) -> Void) -> Project {
            var p = Project.new(name: "sheet", width: 600, height: 280, fps: 30, duration: 2, background: RGBA(0.08, 0.07, 0.12))
            var l = p.makeLayer(name: "t", content: .text, size: Vec2(600, 280))
            l.text = TextData(string: "SHONEN")
            l.text?.fontSize = 120
            l.transform.position = Animated(Vec2(300, 140))
            edit(&l)
            p.layers = [l]
            return p
        }

        let sheet = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.04, green: 0.035, blue: 0.06, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            var row = 0
            for preset in presets {
                let p = project { l in _ = TextPresetLibrary.applyPreset(preset, to: &l, start: 0, duration: 1) }
                for f in 0..<frames {
                    let t = Double(f) / Double(frames - 1) * 1.2
                    if let img = r.renderImage(project: p, time: t, maxDimension: fw * 2, mediaURL: { URL(fileURLWithPath: $0) }) {
                        img.draw(in: CGRect(x: CGFloat(f) * fw, y: CGFloat(row) * rowH + label, width: fw, height: fh))
                    }
                }
                ("\(preset.shownCategory) · \(preset.name)" as NSString).draw(at: CGPoint(x: 4, y: CGFloat(row) * rowH + 2),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: UIColor.white])
                row += 1
            }
            for look in looks {
                let p = project { l in TextPresetLibrary.applyLook(look, to: &l) }
                if let img = r.renderImage(project: p, time: 0.5, maxDimension: fw * 4, mediaURL: { URL(fileURLWithPath: $0) }) {
                    img.draw(in: CGRect(x: 0, y: CGFloat(row) * rowH + label, width: fw * 2, height: fh))
                }
                ("Look · \(look.category) · \(look.name)" as NSString).draw(at: CGPoint(x: 4, y: CGFloat(row) * rowH + 2),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: UIColor.white])
                row += 1
            }
        }
        let data = try XCTUnwrap(sheet.jpegData(compressionQuality: 0.8))
        try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: "/tmp/awi-ui/text-preset-sheet.jpg"))
        let a = XCTAttachment(data: data, uniformTypeIdentifier: "public.jpeg"); a.name = "text-preset-sheet"; a.lifetime = .keepAlways
        add(a)
    }
}
