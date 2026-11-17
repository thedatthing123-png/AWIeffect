import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

/// Shared real-image checks and review artifacts for the combined expansion.
final class ExpansionRenderTests: XCTestCase {
    func testCombinedReleaseContainsOverOneThousandDistinctDefinitions() {
        // Owner's Build 32 release gate. Keep this failing until the expansion is complete;
        // never count aliases or silently drop this assertion to package an unfinished release.
        let definitions=EffectRegistry.all
        XCTAssertGreaterThan(definitions.count,1000,"Build 32's full expansion is not implemented yet")
        XCTAssertEqual(Set(definitions.map(\.id)).count,definitions.count)
        let newDefinitions=EffectRegistry.batch31+EffectRegistry.batch32
        XCTAssertEqual(Set(newDefinitions.map(\.name)).count,newDefinitions.count,"New effects need distinct names and behaviors")
    }
    private func scene(_ effect: EffectInstance?) -> Project {
        var project=Project.new(name:"Expansion",width:192,height:144,fps:30,duration:3,background:RGBA(0,0,0,0))
        var back=project.makeLayer(name:"Back",content:.solid,size:Vec2(192,144))
        back.fill=Animated(RGBA(0.07,0.16,0.27))
        var star=project.makeLayer(name:"Star",content:.shape(.star),size:Vec2(120,120))
        star.fill=Animated(RGBA(0.95,0.67,0.28)); star.transform.position=Animated(Vec2(80,72))
        var rect=project.makeLayer(name:"Accent",content:.solid,size:Vec2(60,90))
        rect.fill=Animated(RGBA(0.65,0.15,0.7)); rect.transform.position=Animated(Vec2(145,65))
        project.layers=[rect,star,back]
        if let effect {
            var adjustment=project.makeLayer(name:"Effect",content:.adjustment,size:Vec2(192,144))
            adjustment.effects=[effect]; project.layers.insert(adjustment,at:0)
        }
        return project
    }
    private func pixels(_ effect: EffectInstance?,time:Double=0.4) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:scene(effect),time:time,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    private func difference(_ a:[UInt8],_ b:[UInt8]) -> Double {
        zip(a,b).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(a.count)
    }
    func testSignalDefaultsMissingParametersAndZeroAmount() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.batch31 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertLessThan(difference(result,try pixels(EffectInstance(typeID:definition.id,params:[:]))),0.01,definition.name)
            effect.params["amount"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
        }
    }
    func testKeyframeHitsDoNotRunBeforeKeysAndDecayAfterHit() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi31.chromaShatter"))
        var effect=definition.makeInstance(); effect.params["motion"] = .choice(3)
        XCTAssertEqual(try pixels(nil),try pixels(effect),"No trigger keys means no keyframe hit")
        var trigger=Animated(0.0); trigger.insertKeyframe(Keyframe(time:0.35,value:100))
        effect.params["trigger"] = .number(trigger)
        XCTAssertEqual(try pixels(nil,time:0.3),try pixels(effect,time:0.3))
        XCTAssertGreaterThan(difference(try pixels(nil),try pixels(effect,time:0.4)),0.05)
        XCTAssertEqual(try pixels(nil,time:0.7),try pixels(effect,time:0.7))
    }
    func testChoppyHoldsAndSmoothMovesWithinAFrameInterval() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi31.chromaShatter"))
        var effect=definition.makeInstance(); effect.params["motion"] = .choice(1)
        XCTAssertEqual(try pixels(effect,time:0.1),try pixels(effect,time:0.11))
        effect.params["motion"] = .choice(0)
        XCTAssertGreaterThan(difference(try pixels(effect,time:0.1),try pixels(effect,time:0.11)),0.001)
    }
    func testFlowFallbacksBypassAndNegativeDisplacement() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.batch32 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertLessThan(difference(result,try pixels(EffectInstance(typeID:definition.id,params:[:]))),0.01,definition.name)
            effect.params["amount"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
            effect.params["amount"] = .number(Animated(-28))
            XCTAssertGreaterThan(difference(result,try pixels(effect)),0.01,definition.name)
        }
    }
    func testFlowEdgeModesAndTransparentInput() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let definition=try XCTUnwrap(EffectRegistry.definition("awi32.liquidCurl"))
        for edge in 0...3 {
            var effect=definition.makeInstance(); effect.params["edge"] = .choice(edge)
            var project=scene(effect)
            for index in project.layers.indices where project.layers[index].content != .adjustment {
                project.layers[index].fill=Animated(RGBA(0,0,0,0))
            }
            let result=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            XCTAssertTrue(result.allSatisfy{$0==0},"Transparent input must stay transparent for edge mode \(edge)")
        }
    }
    func testWriteSignalSheetMotionAndCatalog() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let folder=URL(fileURLWithPath:"/tmp/awi-expansion",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let definitions=EffectRegistry.batch31
        let height=CGFloat((definitions.count+3)/4)*180
        let sheet=UIGraphicsImageRenderer(size:CGSize(width:768,height:height)).image { context in
            UIColor(white:0.06,alpha:1).setFill(); context.fill(CGRect(x:0,y:0,width:768,height:height))
            for (index,definition) in definitions.enumerated() {
                let x=CGFloat(index%4)*192,y=CGFloat(index/4)*180
                renderer.renderImage(project:scene(definition.makeInstance()),time:0.4,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)})?.draw(in:CGRect(x:x,y:y,width:192,height:144))
                (definition.name as NSString).draw(at:CGPoint(x:x+6,y:y+150),withAttributes:[.font:UIFont.systemFont(ofSize:13),.foregroundColor:UIColor.white])
            }
        }
        try XCTUnwrap(sheet.pngData()).write(to:folder.appendingPathComponent("glitch-contact-sheet.png"))
        for id in ["chromaShatter","rowDuplicate","trackingBand","edgeTear","bitplaneSlip"] {
            let definition=try XCTUnwrap(EffectRegistry.definition("awi31."+id))
            let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent(id+".gif") as CFURL,UTType.gif.identifier as CFString,30,nil))
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for frame in 0..<30 {
                let image=try XCTUnwrap(renderer.renderImage(project:scene(definition.makeInstance()),time:Double(frame)/15,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)}))
                CGImageDestinationAddImage(destination,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/15]] as CFDictionary)
                if frame%10==0 { try XCTUnwrap(image.pngData()).write(to:folder.appendingPathComponent("\(id)-\(frame).png")) }
            }
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
        let catalog=EffectRegistry.all.map { ["id":$0.id,"name":$0.name,"section":EffectSection.of($0).rawValue,"controls":$0.params.map(\.id)] as [String:Any] }
        try JSONSerialization.data(withJSONObject:catalog,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("effect-catalog.json"))
    }
    func testWriteFlowContactSheetAndMotion() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let folder=URL(fileURLWithPath:"/tmp/awi-expansion",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let definitions=EffectRegistry.batch32,height=CGFloat((EffectRegistry.batch32.count+3)/4)*180
        let sheet=UIGraphicsImageRenderer(size:CGSize(width:768,height:height)).image { context in
            UIColor(white:0.06,alpha:1).setFill(); context.fill(CGRect(x:0,y:0,width:768,height:height))
            for (index,definition) in definitions.enumerated() {
                let x=CGFloat(index%4)*192,y=CGFloat(index/4)*180
                renderer.renderImage(project:scene(definition.makeInstance()),time:0.4,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)})?.draw(in:CGRect(x:x,y:y,width:192,height:144))
                (definition.name as NSString).draw(at:CGPoint(x:x+6,y:y+150),withAttributes:[.font:UIFont.systemFont(ofSize:13),.foregroundColor:UIColor.white])
            }
        }
        try XCTUnwrap(sheet.pngData()).write(to:folder.appendingPathComponent("flow-contact-sheet.png"))
        for id in ["liquidCurl","liquidDrip","liquidTidal","lensQuilt","vortexPair"] {
            let definition=try XCTUnwrap(EffectRegistry.definition("awi32."+id))
            let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent(id+".gif") as CFURL,UTType.gif.identifier as CFString,30,nil))
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for frame in 0..<30 {
                let image=try XCTUnwrap(renderer.renderImage(project:scene(definition.makeInstance()),time:Double(frame)/15,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)}))
                CGImageDestinationAddImage(destination,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/15]] as CFDictionary)
                if frame%10==0 { try XCTUnwrap(image.pngData()).write(to:folder.appendingPathComponent("\(id)-\(frame).png")) }
            }
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
    }
}
