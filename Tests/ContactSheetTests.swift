import XCTest
import UIKit
@testable import AWIeffect

/// Renders every effect at default and strong settings into one image (CI artifact) so they can be eyeballed.
final class ContactSheetTests: XCTestCase {
    func testWriteContactSheet() throws {
        guard let r = Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device; contact sheet not generated") }
        let defs = EffectRegistry.all
        let cell: CGFloat = 200, label: CGFloat = 26, cols = 4
        let rows = Int(ceil(Double(defs.count) / Double(cols)))
        let size = CGSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * (cell + label) + 40)
        let url = PreviewImage.url()

        let sheet = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 0.055, green: 0.043, blue: 0.078, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let title = "AWIeffect contact sheet — \(defs.count) effects" as NSString
            title.draw(at: CGPoint(x: 10, y: 10), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18), .foregroundColor: UIColor.white])
            for (i, d) in defs.enumerated() {
                let x = CGFloat(i % cols) * cell, y = 40 + CGFloat(i / cols) * (cell + label)
                var inst = d.makeInstance()
                if d.id == "awi.shake" { inst.params["amplitude"] = .number(Animated(40)) }
                let p = EffectThumbnails.previewProject(effect: inst)
                if let img = r.renderImage(project: p, time: 0.37, maxDimension: cell - 8, mediaURL: { _ in url }) {
                    img.draw(in: CGRect(x: x + 4, y: y + 4, width: cell - 8, height: cell - 8))
                }
                (d.name as NSString).draw(at: CGPoint(x: x + 6, y: y + cell), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: UIColor.white])
            }
        }
        let data = try XCTUnwrap(sheet.pngData())
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        attachment.name = "contact-sheet"
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also drop it where CI can upload it directly.
        try? data.write(to: URL(fileURLWithPath: "/tmp/awi-contact-sheet.png"))
    }
}
