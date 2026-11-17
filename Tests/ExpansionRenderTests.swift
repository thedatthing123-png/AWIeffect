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
        let newDefinitions=EffectRegistry.batch31+EffectRegistry.batch32+EffectRegistry.batch33+EffectRegistry.time33
            + EffectRegistry.batch34+EffectRegistry.cameraTransitions34+EffectRegistry.batch35+EffectRegistry.batch36
            + EffectRegistry.lights36+EffectRegistry.batch37+EffectRegistry.cleanup37+EffectRegistry.frequency37
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
    func testFrequencyFallbacksNeutralBandsAndBypass() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.frequency37 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertLessThan(difference(result,try pixels(EffectInstance(typeID:definition.id,params:[:]))),0.01,definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
        }
        let definition=try XCTUnwrap(EffectRegistry.definition("awi37.detailBands"))
        var effect=definition.makeInstance()
        for key in ["fine","middle","broad"] { effect.params[key] = .number(Animated(1)) }
        XCTAssertLessThan(difference(original,try pixels(effect)),0.01,"Unit gains must reconstruct the original signal")
    }
    func testChromaCleanupPreservesBrightnessAtSaturatedEdges() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi37.chromaClean"))
        var effect=definition.makeInstance()
        effect.params["radius"] = .number(Animated(6))
        effect.params["strength"] = .number(Animated(100))
        let original=try pixels(nil),filtered=try pixels(effect)
        var largestLumaError=0.0
        for index in stride(from:0,to:original.count,by:4) {
            let before=Double(original[index])*0.2126+Double(original[index+1])*0.7152+Double(original[index+2])*0.0722
            let after=Double(filtered[index])*0.2126+Double(filtered[index+1])*0.7152+Double(filtered[index+2])*0.0722
            largestLumaError=max(largestLumaError,abs(before-after))
        }
        XCTAssertLessThan(largestLumaError,2.0,"Chroma filtering must not brighten clipped color channels")
        XCTAssertGreaterThan(difference(original,filtered),0.01,"The chroma must actually be smoothed")
    }
    func testFrequencyFiltersKeepCoverageAndEmptyPixelsClean() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var project=Project.new(name:"Detail alpha",width:96,height:96,fps:30,duration:1,background:RGBA(0,0,0,0))
        var layer=project.makeLayer(name:"Soft subject",content:.shape(.star),size:Vec2(60,60))
        layer.fill=Animated(RGBA(0.7,0.3,0.9,0.5));project.layers=[layer]
        let original=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
        for definition in EffectRegistry.frequency37 {
            project.layers[0].effects=[definition.makeInstance()]
            let result=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            for index in stride(from:0,to:result.count,by:4) {
                XCTAssertEqual(result[index+3],original[index+3],"\(definition.name) changed the matte")
                if result[index+3]==0 { XCTAssertTrue(result[index...index+2].allSatisfy{$0==0},definition.name) }
            }
        }
    }
    func testCameraTransitionEndpointsAndShutterFollowsAnimation() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.cameraTransitions34 {
            var effect=definition.makeInstance()
            effect.params["completion"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
            effect.params["completion"] = .number(Animated(100))
            XCTAssertTrue(try pixels(effect).allSatisfy{$0==0},definition.name)
            effect=definition.makeInstance();effect.params["shutter"] = .number(Animated(0))
            let sharp=try pixels(effect)
            effect.params["shutter"] = .number(Animated(100))
            XCTAssertEqual(sharp,try pixels(effect),"A held completion must stay sharp: \(definition.name)")
            var progress=Animated(0.0)
            progress.insertKeyframe(Keyframe(time:0,value:0));progress.insertKeyframe(Keyframe(time:1,value:100))
            effect.params["completion"] = .number(progress)
            let moving=try pixels(effect)
            effect.params["shutter"] = .number(Animated(0))
            XCTAssertGreaterThan(difference(moving,try pixels(effect)),0.01,definition.name)
        }
    }
    func testOpticalLightsFallbacksAndBypass() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.lights36 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertLessThan(difference(result,try pixels(EffectInstance(typeID:definition.id,params:[:]))),0.01,definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
            effect=definition.makeInstance();effect.params["intensity"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
        }
    }
    func testOpticalLightsDoNotInventLightOnEmptyInput() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for definition in EffectRegistry.lights36 {
            var effect=definition.makeInstance();effect.params["only"] = .toggle(true)
            var project=scene(effect)
            for index in project.layers.indices where project.layers[index].content != .adjustment {
                project.layers[index].fill=Animated(RGBA(0,0,0,0))
            }
            let result=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            XCTAssertTrue(result.allSatisfy{$0==0},definition.name)
        }
    }
    func testWriteOpticalContactSheetAndAnimatedWinding() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let folder=URL(fileURLWithPath:"/tmp/awi-expansion",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let definitions=EffectRegistry.lights36
        let height=CGFloat((definitions.count+2)/3)*180
        let sheet=UIGraphicsImageRenderer(size:CGSize(width:576,height:height)).image { context in
            UIColor(white:0.06,alpha:1).setFill();context.fill(CGRect(x:0,y:0,width:576,height:height))
            for (index,definition) in definitions.enumerated() {
                let x=CGFloat(index%3)*192,y=CGFloat(index/3)*180
                renderer.renderImage(project:scene(definition.makeInstance()),time:0.4,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)})?.draw(in:CGRect(x:x,y:y,width:192,height:144))
                (definition.name as NSString).draw(at:CGPoint(x:x+6,y:y+150),withAttributes:[.font:UIFont.systemFont(ofSize:13),.foregroundColor:UIColor.white])
            }
        }
        try XCTUnwrap(sheet.pngData()).write(to:folder.appendingPathComponent("optical-contact-sheet.png"))
        let definition=try XCTUnwrap(EffectRegistry.definition("awi36.light.spiralLight"))
        var effect=definition.makeInstance(),angle=Animated(0.0)
        angle.insertKeyframe(Keyframe(time:0,value:0));angle.insertKeyframe(Keyframe(time:2,value:160))
        effect.params["angle"] = .number(angle)
        let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent("spiral-light.gif") as CFURL,UTType.gif.identifier as CFString,30,nil))
        CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for frame in 0..<30 {
            let image=try XCTUnwrap(renderer.renderImage(project:scene(effect),time:Double(frame)/15,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)}))
            CGImageDestinationAddImage(destination,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/15]] as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
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
    func testWriteRemainingFamilyReviewArtifacts() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let folder=URL(fileURLWithPath:"/tmp/awi-expansion",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let families:[(String,[EffectDefinition])]=[
            ("matte",EffectRegistry.batch33),
            ("time",EffectRegistry.time33),
            ("transition",EffectRegistry.batch34+EffectRegistry.cameraTransitions34),
            ("shape-particle",EffectRegistry.batch35),
            ("procedural",EffectRegistry.batch36),
            ("finish",EffectRegistry.batch37+EffectRegistry.cleanup37+EffectRegistry.frequency37)
        ]
        for (name,definitions) in families {
            let height=CGFloat((definitions.count+3)/4)*180
            let sheet=UIGraphicsImageRenderer(size:CGSize(width:768,height:height)).image { context in
                UIColor(white:0.06,alpha:1).setFill();context.fill(CGRect(x:0,y:0,width:768,height:height))
                for (index,definition) in definitions.enumerated() {
                    let x=CGFloat(index%4)*192,y=CGFloat(index/4)*180
                    let image=renderer.renderImage(project:reviewScene(definition.makeInstance()),time:0.4,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)})
                    XCTAssertNotNil(image,definition.name)
                    image?.draw(in:CGRect(x:x,y:y,width:192,height:144))
                    (definition.name as NSString).draw(at:CGPoint(x:x+6,y:y+150),withAttributes:[.font:UIFont.systemFont(ofSize:13),.foregroundColor:UIColor.white])
                }
            }
            try XCTUnwrap(sheet.pngData()).write(to:folder.appendingPathComponent(name+"-contact-sheet.png"))
        }
        // Animate actual editable controls, not a pan over a static contact sheet.
        let previews:[(String,String,Double,Double)]=[
            ("awi33.localContrast","threshold",5,35),("awi33.fringeMatte","radius",1,20),
            ("awi33.lumaBand","threshold",15,85),("awi33.lightWrap","radius",2,30),
            ("awi33.alphaSteps","band",2,12),
            ("awi33.time.slice","span",0,0.7),("awi33.time.difference","delay",0.01,0.4),
            ("awi33.time.median","spacing",0.01,0.3),
            ("awi34.spiralPeel","completion",0,100),("awi34.paperRip","completion",0,100),
            ("awi34.brushStrokeWipe","completion",0,100),("awi34.camera.cornerTumble","completion",0,100),
            ("awi34.camera.splitFold","completion",0,100),
            ("awi35.particlePetals","speed",0.5,1.5),("awi35.particleFeathers","speed",0.5,1.5),
            ("awi35.particleMeteor","speed",0.5,1.5),("awi35.particleRibbons","speed",0.5,1.5),
            ("awi35.particleComets","speed",0.5,1.5),
            ("awi36.fractalRidges","evolution",0,2),("awi36.domainWarpField","evolution",0,2),
            ("awi36.causticField","evolution",0,2),("awi36.fireTongues","evolution",0,2),
            ("awi36.electricFilaments","evolution",0,2),
            ("awi37.pixelBlur","block",1,32),("awi37.hotColor","lowHue",0,220),
            ("awi37.hotColor2","hue",0,220),("awi37.trimmedMean","radius",0.5,8),
            ("awi37.localRange","strength",0,100),
            ("awi37.detailBands","middle",0,2),("awi37.bandPass","radius",1,12),
            ("awi37.retinexDetail","strength",0,100)
        ]
        for (id,key,start,end) in previews {
            let definition=try XCTUnwrap(EffectRegistry.definition(id))
            XCTAssertTrue(definition.params.contains{$0.id==key},"Review control missing: \(id).\(key)")
            var effect=definition.makeInstance(),value=Animated(start)
            value.insertKeyframe(Keyframe(time:0,value:start));value.insertKeyframe(Keyframe(time:2,value:end))
            effect.params[key] = .number(value)
            let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(folder.appendingPathComponent(id+".gif") as CFURL,UTType.gif.identifier as CFString,30,nil))
            CGImageDestinationSetProperties(destination,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
            for frame in 0..<30 {
                let image=try XCTUnwrap(renderer.renderImage(project:reviewScene(effect),time:Double(frame)/15,maxDimension:192,mediaURL:{URL(fileURLWithPath:$0)}))
                CGImageDestinationAddImage(destination,try XCTUnwrap(image.cgImage),[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/15]] as CFDictionary)
            }
            XCTAssertTrue(CGImageDestinationFinalize(destination),id)
        }
    }
    private func reviewScene(_ effect:EffectInstance) -> Project {
        if EffectRegistry.temporalIDs33.contains(effect.typeID) { return TemporalEffectTests.scene(effect) }
        var project=scene(effect)
        // Matte tools need an isolated partial-alpha shape; reference mattes also
        // receive a real, differently colored background layer rather than nil.
        if effect.typeID.hasPrefix("awi33.") {
            project.layers.removeAll{$0.content == .adjustment}
            if let index=project.layers.firstIndex(where:{$0.name=="Star"}) {
                var e=effect
                if EffectRegistry.layerRefIDs.contains(effect.typeID),let back=project.layers.first(where:{$0.name=="Back"}) {
                    e.text=["layer":back.id.uuidString]
                }
                project.layers[index].fill=Animated(RGBA(0.95,0.67,0.28,0.58))
                project.layers[index].effects=[e]
            }
        }
        if EffectRegistry.cleanup37.contains(where:{$0.id==effect.typeID}) {
            let grain=EffectInstance(typeID:"ae.noise",params:["amount":.number(Animated(70)),"size":.number(Animated(0.5)),"color":.toggle(true)])
            for index in project.layers.indices where project.layers[index].content != .adjustment { project.layers[index].effects=[grain] }
        }
        return project
    }
}
