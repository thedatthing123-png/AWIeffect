import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

/// Bounded pages avoid an enormous bitmap when reviewing hundreds of presets.
final class TextPresetSheetTests:XCTestCase {
    private let folder=URL(fileURLWithPath:"/tmp/awi-premades33")
    private func scene(_ name:String)->Project {
        var p=Project.new(name:name,width:640,height:360,fps:30,duration:3,background:RGBA(0.035,0.025,0.06))
        var l=p.makeLayer(name:"Editable title",content:.text,size:Vec2(640,360))
        l.text=TextData(string:"MAKE\nSOME NOISE",fontSize:72)
        l.text?.fontName="AvenirNext-Heavy"
        l.transform.position=Animated(Vec2(320,180));p.layers=[l]
        return p
    }
    private func sheet(_ rows:[(String,[UIImage])],name:String)throws {
        let w:CGFloat=180,h:CGFloat=102,label:CGFloat=24,columns=5
        let format=UIGraphicsImageRendererFormat();format.scale=1
        let image=UIGraphicsImageRenderer(size:CGSize(width:w*CGFloat(columns),height:(h+label)*CGFloat(rows.count)),format:format).image { ctx in
            UIColor.black.setFill();ctx.fill(CGRect(x:0,y:0,width:w*CGFloat(columns),height:(h+label)*CGFloat(rows.count)))
            for (row,entry) in rows.enumerated() {
                (entry.0 as NSString).draw(at:CGPoint(x:4,y:CGFloat(row)*(h+label)+4),withAttributes:[.font:UIFont.systemFont(ofSize:12),.foregroundColor:UIColor.white])
                for (index,frame) in entry.1.enumerated() { frame.draw(in:CGRect(x:CGFloat(index)*w,y:CGFloat(row)*(h+label)+label,width:w,height:h)) }
            }
        }
        try XCTUnwrap(image.jpegData(compressionQuality:0.88)).write(to:folder.appendingPathComponent(name+".jpg"))
    }
    private func movie(_ frames:[UIImage],id:String)throws {
        let url=folder.appendingPathComponent(id+".gif")
        let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,UTType.gif.identifier as CFString,frames.count,nil))
        CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for frame in frames {
            CGImageDestinationAddImage(destination,try XCTUnwrap(frame.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:0.1]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination),id)
    }
    func testTextIn()throws { try renderText("In") }
    func testTextOut()throws { try renderText("Out") }
    func testTextLoop()throws { try renderText("Loop") }
    func testTextEmphasis()throws { try renderText("Emphasis") }
    func testTextGlitch()throws { try renderText("Glitch") }
    func testTextTypewriter()throws { try renderText("Typewriter") }
    func testTextKinetic()throws { try renderText("Kinetic") }
    func testTextManga()throws { try renderText("Manga/AMV") }
    func testTextLyric()throws { try renderText("Lyric") }
    func testTextImpact()throws { try renderText("Impact") }
    func testText3DIn()throws { try renderText("3D In") }
    func testText3DOut()throws { try renderText("3D Out") }
    func testText3DLoop()throws { try renderText("3D Loop") }
    func testTextLooks()throws { try renderText("Looks") }
    private func renderText(_ category:String) throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var rows:[(String,[UIImage])]=[],page=0
        func append(_ name:String,_ frames:[UIImage])throws {
            rows.append((name,frames))
            if rows.count==12 { try sheet(rows,name:"text-\(category.replacingOccurrences(of:"/",with:"-"))-\(page)");page+=1;rows=[] }
        }
        for preset in TextPresetLibrary.animations where preset.category == category {
            try autoreleasepool {
                var p=scene(preset.name)
                TextPresetLibrary.applyPreset(preset,to:&p.layers[0],start:0.1,duration:1)
                let times:[Double]=[0.1,0.3,0.6,0.9,1.3]
                let frames=try times.map { try XCTUnwrap(renderer.renderImage(project:p,time:$0,maxDimension:360,mediaURL:{URL(fileURLWithPath:$0)}),preset.id) }
                try append("\(preset.category) · \(preset.name)",frames)
                if preset.id.hasPrefix("craft33.") {
                    let moving=try (0..<20).map { try XCTUnwrap(renderer.renderImage(project:p,time:Double($0)*0.1,maxDimension:320,mediaURL:{URL(fileURLWithPath:$0)}),preset.id) }
                    try movie(moving,id:preset.id)
                    XCTAssertGreaterThan(Set(moving.compactMap{$0.pngData()}).count,1,preset.id+" rendered no motion")
                }
            }
        }
        for look in TextPresetLibrary.looks where category == "Looks" {
            try autoreleasepool {
                var p=scene(look.name);TextPresetLibrary.applyLook(look,to:&p.layers[0])
                let image=try XCTUnwrap(renderer.renderImage(project:p,time:0.5,maxDimension:640,mediaURL:{URL(fileURLWithPath:$0)}),look.id)
                try append("Look · \(look.category) · \(look.name)",[image])
            }
        }
        if !rows.isEmpty { try sheet(rows,name:"text-\(category.replacingOccurrences(of:"/",with:"-"))-\(page)") }
    }
    func testGeneralShakes()throws { try renderGeneral(.shake) }
    func testGeneralIn()throws { try renderGeneral(.transitionIn) }
    func testGeneralOut()throws { try renderGeneral(.transitionOut) }
    func testGeneralGlow()throws { try renderGeneral(.glow) }
    func testGeneralLoops()throws { try renderGeneral(.loop) }
    func testGeneralManga()throws { try renderGeneral(.manga) }
    func testGeneralLooks()throws { try renderGeneral(.look) }
    func testGeneralVelocity()throws { try renderGeneral(.velocity) }
    private func renderGeneral(_ category:LayerPreset.Kind)throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var rows:[(String,[UIImage])]=[],page=0
        for preset in CraftPresets33.layerPresets where preset.kind == category {
            try autoreleasepool {
                var p=scene(preset.name)
                var star=p.makeLayer(name:"Artwork",content:.shape(.star),size:Vec2(120,120))
                star.fill=Animated(RGBA(0.9,0.16,0.35));star.transform.position=TPB.kf([(0,Vec2(100,180)),(2,Vec2(540,180))])
                p.layers.append(star)
                let anchor=preset.kind == .transitionOut ? 1.7:0.1
                p.layers[0]=PresetLibrary.applying(preset,to:p.layers[0],project:p,at:anchor)
                let frames=try (0..<20).map { try XCTUnwrap(renderer.renderImage(project:p,time:Double($0)*0.1,maxDimension:320,mediaURL:{URL(fileURLWithPath:$0)}),preset.id) }
                try movie(frames,id:preset.id)
                rows.append(("\(preset.kind.rawValue) · \(preset.name)",[frames[1],frames[4],frames[8],frames[12],frames[17]]))
                if rows.count==10 { try sheet(rows,name:"general-\(category.rawValue)-\(page)");page+=1;rows=[] }
            }
        }
        if !rows.isEmpty { try sheet(rows,name:"general-\(category.rawValue)-\(page)") }
    }
}
