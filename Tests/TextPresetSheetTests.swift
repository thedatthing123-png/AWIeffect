import XCTest
import UIKit
@testable import AWIeffect

/// Review the original presets in bounded pages, without the discarded catalog.
final class TextPresetSheetTests:XCTestCase {
    func testWriteTextPresetSheet()throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var entries:[(String,(inout Layer)->Void)]=TextPresetLibrary.animations.map { preset in
            (preset.name,{ layer in _ = TextPresetLibrary.applyPreset(preset,to:&layer,start:0,duration:1) })
        }
        entries += TextPresetLibrary.looks.map { look in (look.name,{ layer in TextPresetLibrary.applyLook(look,to:&layer) }) }
        let folder=URL(fileURLWithPath:"/tmp/awi-ui")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let format=UIGraphicsImageRendererFormat();format.scale=1
        for start in stride(from:0,to:entries.count,by:24) {
            try autoreleasepool {
                let page=Array(entries[start..<min(start+24,entries.count)])
                let size=CGSize(width:750,height:CGFloat(page.count)*88)
                let sheet=UIGraphicsImageRenderer(size:size,format:format).image { context in
                    UIColor(white:0.04,alpha:1).setFill();context.fill(CGRect(origin:.zero,size:size))
                    for (row,entry) in page.enumerated() {
                        var p=Project.new(name:"Original preset review",width:600,height:280,fps:30,duration:2,background:RGBA(0.08,0.07,0.12))
                        var layer=p.makeLayer(name:"Title",content:.text,size:Vec2(600,280))
                        layer.text=TextData(string:"SHONEN",fontSize:120)
                        layer.transform.position=Animated(Vec2(300,140));entry.1(&layer);p.layers=[layer]
                        (entry.0 as NSString).draw(at:CGPoint(x:4,y:CGFloat(row)*88+2),withAttributes:[.font:UIFont.systemFont(ofSize:11),.foregroundColor:UIColor.white])
                        for frame in 0..<5 {
                            let image=renderer.renderImage(project:p,time:Double(frame)*0.3,maxDimension:300,mediaURL:{URL(fileURLWithPath:$0)})
                            image?.draw(in:CGRect(x:CGFloat(frame)*150,y:CGFloat(row)*88+18,width:150,height:70))
                        }
                    }
                }
                let data=try XCTUnwrap(sheet.jpegData(compressionQuality:0.85))
                try data.write(to:folder.appendingPathComponent("original-text-presets-\(start/24).jpg"))
            }
        }
    }
}
