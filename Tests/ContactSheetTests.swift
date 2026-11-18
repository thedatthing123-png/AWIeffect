import XCTest
import UIKit
@testable import AWIeffect

/// Render every effect in bounded pages. A 900-effect single sheet exceeds
/// normal image dimensions and needlessly multiplies peak review memory.
final class ContactSheetTests:XCTestCase {
    func testWriteContactSheet() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU: no Metal device") }
        let definitions=EffectRegistry.all,cell:CGFloat=200,label:CGFloat=26,columns=4,pageSize=48
        let folder=URL(fileURLWithPath:"/tmp/awi-contact-sheets")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let url=PreviewImage.url()
        let format=UIGraphicsImageRendererFormat();format.scale=1
        for start in stride(from:0,to:definitions.count,by:pageSize) {
            try autoreleasepool {
                let page=Array(definitions[start..<min(start+pageSize,definitions.count)])
                let rows=(page.count+columns-1)/columns
                let size=CGSize(width:CGFloat(columns)*cell,height:CGFloat(rows)*(cell+label)+40)
                let sheet=UIGraphicsImageRenderer(size:size,format:format).image { context in
                    UIColor(red:0.055,green:0.043,blue:0.078,alpha:1).setFill()
                    context.fill(CGRect(origin:.zero,size:size))
                    ("AWIeffect · effects \(start+1)–\(start+page.count) of \(definitions.count)" as NSString).draw(at:CGPoint(x:10,y:10),withAttributes:[.font:UIFont.boldSystemFont(ofSize:18),.foregroundColor:UIColor.white])
                    for (index,definition) in page.enumerated() {
                        let x=CGFloat(index%columns)*cell,y=40+CGFloat(index/columns)*(cell+label)
                        let project=EffectThumbnails.previewProject(effect:EffectThumbnails.showcase(definition))
                        let image=renderer.renderImage(project:project,time:0.37,maxDimension:cell-8,mediaURL:{_ in url})
                        XCTAssertNotNil(image,definition.id)
                        image?.draw(in:CGRect(x:x+4,y:y+4,width:cell-8,height:cell-8))
                        (definition.name as NSString).draw(at:CGPoint(x:x+6,y:y+cell),withAttributes:[.font:UIFont.systemFont(ofSize:13,weight:.semibold),.foregroundColor:UIColor.white])
                    }
                }
                let data=try XCTUnwrap(sheet.pngData()),name="contact-\(start/pageSize)"
                try data.write(to:folder.appendingPathComponent(name+".png"))
                if start==0 { try data.write(to:URL(fileURLWithPath:"/tmp/awi-contact-sheet.png")) }
                let attachment=XCTAttachment(data:data,uniformTypeIdentifier:"public.png")
                attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
            }
        }
    }
}
