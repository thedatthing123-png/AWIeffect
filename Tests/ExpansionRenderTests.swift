import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

enum EffectFixtureRequirements {
    static let detailIDs:Set<String> = {
        let families:[[EffectDefinition]]=[EffectRegistry.cleanup37,EffectRegistry.nonlinear37,EffectRegistry.advancedClean37,EffectRegistry.morphology37]
        return Set(families.flatMap{$0}.map(\.id)).union(["awi37.draw.flowPaint","awi31.segmentSort"])
    }()
}

/// Shared real-image checks and review artifacts for the combined expansion.
final class ExpansionRenderTests: XCTestCase {
    func testCombinedReleaseContainsAtLeastNineHundredDistinctDefinitions() {
        // Owner revised the release target to 900 on November 17. Distinctness,
        // rendered quality and performance gates still apply; aliases do not count.
        let definitions=EffectRegistry.all
        XCTAssertGreaterThanOrEqual(definitions.count,900,"Build 32's full expansion is not implemented yet")
        XCTAssertEqual(Set(definitions.map(\.id)).count,definitions.count)
        let families:[[EffectDefinition]]=[EffectRegistry.batch31,EffectRegistry.sorting31,EffectRegistry.batch32,
            EffectRegistry.batch33,EffectRegistry.time33,EffectRegistry.batch34,EffectRegistry.cameraTransitions34,
            EffectRegistry.batch35,EffectRegistry.batch36,EffectRegistry.lights36,EffectRegistry.batch37,
            EffectRegistry.cleanup37,EffectRegistry.frequency37,EffectRegistry.drawing37,EffectRegistry.retro37,
            EffectRegistry.textGeometry37,EffectRegistry.batch38,EffectRegistry.conformal32,EffectRegistry.morphology37,EffectRegistry.sampling33,
            EffectRegistry.featureMattes33,EffectRegistry.surfaces38,EffectRegistry.flow31,EffectRegistry.transforms37,EffectRegistry.nonlinear37,EffectRegistry.math30,
            EffectRegistry.advancedClean37,EffectRegistry.data39,EffectRegistry.surfaces40,EffectRegistry.distance41,EffectRegistry.projection42,EffectRegistry.temporalAnalysis43,EffectRegistry.finishes44,EffectRegistry.poisson45,EffectRegistry.spectral46,EffectRegistry.interactions47,EffectRegistry.craft48]
        let newDefinitions=families.flatMap{$0}
        XCTAssertEqual(Set(newDefinitions.map(\.name)).count,newDefinitions.count,"New effects need distinct names and behaviors")
    }
    func testNewFamiliesHaveIntentionalBrowserSections() {
        for definition in EffectRegistry.math30 { XCTAssertEqual(EffectSection.of(definition),.backgrounds,definition.name) }
        for definition in EffectRegistry.conformal32 { XCTAssertEqual(EffectSection.of(definition),.distort,definition.name) }
        for definition in EffectRegistry.sampling33 { XCTAssertEqual(EffectSection.of(definition),.time,definition.name) }
        for definition in EffectRegistry.featureMattes33 { XCTAssertEqual(EffectSection.of(definition),.keying,definition.name) }
        XCTAssertEqual(EffectSection.of(EffectRegistry.surfaces38[0]),.glow)
        XCTAssertEqual(EffectSection.of(EffectRegistry.surfaces38[1]),.distort)
        for definition in EffectRegistry.morphology37 {
            let matte=["awi37.morph.whiteHat","awi37.morph.blackHat","awi37.morph.gradient"].contains(definition.id)
            XCTAssertEqual(EffectSection.of(definition),matte ? .keying:.blur,definition.name)
        }
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
    func testDrawingFallbacksAndBlendBypass() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        func render(_ effect:EffectInstance) throws -> [UInt8] {
            try XCTUnwrap(renderer.renderPixels(project:reviewScene(effect),time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
        }
        for definition in EffectRegistry.drawing37 {
            var effect=definition.makeInstance(),disabled=effect;disabled.isEnabled=false
            let original=try render(disabled),processed=try render(effect)
            XCTAssertGreaterThan(difference(original,processed),0.05,definition.name)
            XCTAssertLessThan(difference(processed,try render(EffectInstance(typeID:definition.id,params:[:]))),0.01,definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original,try render(effect),definition.name)
        }
    }
    func testDrawingDoesNotPaintOutsideEmptyCoverage() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for definition in EffectRegistry.drawing37 {
            var project=scene(definition.makeInstance())
            for index in project.layers.indices where project.layers[index].content != .adjustment {
                project.layers[index].fill=Animated(RGBA(0,0,0,0))
            }
            let rgba=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            XCTAssertTrue(rgba.allSatisfy{$0==0},definition.name)
        }
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
    func testCoordinateMapsFallbacksAndBypass() throws {
        let original = try pixels(nil)
        for definition in EffectRegistry.conformal32 {
            var effect = definition.makeInstance()
            let result = try pixels(effect)
            XCTAssertGreaterThan(difference(original, result), 0.05, definition.name)
            XCTAssertEqual(result, try pixels(EffectInstance(typeID: definition.id, params: [:])), definition.name)
            effect.params["amount"] = .number(Animated(0))
            XCTAssertEqual(original, try pixels(effect), definition.name)
            effect = definition.makeInstance()
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original, try pixels(effect), definition.name)
        }
    }
    func testMorphologyFallbacksAndBlendBypass() throws {
        let original = try pixels(nil)
        for definition in EffectRegistry.morphology37 {
            var effect = definition.makeInstance()
            let result = try pixels(effect)
            XCTAssertGreaterThan(difference(original, result), 0.01, definition.name)
            XCTAssertEqual(result, try pixels(EffectInstance(typeID: definition.id, params: [:])), definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original, try pixels(effect), definition.name)
        }
    }
    func testFeatureMattesFallbacksAndBypass() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.featureMattes33 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertEqual(result,try pixels(EffectInstance(typeID:definition.id,params:[:])),definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
        }
    }
    func testMathBackgroundFallbacksAndBlendBypass() throws {
        let original=try pixels(nil)
        for definition in EffectRegistry.math30 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertEqual(result,try pixels(EffectInstance(typeID:definition.id,params:[:])),definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
        }
    }
    func testPrimeSpiralMarksKnownIntegers() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        var project=Project.new(name:"Prime grid",width:164,height:164,fps:30,duration:1,background:RGBA(0,0,0,0))
        var layer=project.makeLayer(name:"Pattern",content:.solid,size:Vec2(164,164))
        var effect=try XCTUnwrap(EffectRegistry.definition("awi30.math.primeSpiral")).makeInstance()
        effect.params["speed"] = .number(Animated(0));effect.params["evolution"] = .number(Animated(0))
        effect.params["color"] = .color(Animated(RGBA(1,1,1)));effect.params["color2"] = .color(Animated(RGBA(0,0,0)))
        layer.effects=[effect];project.layers=[layer]
        let rgba=try XCTUnwrap(renderer.renderPixels(project:project,time:0,preserveAlpha:true,
            mediaURL:{URL(fileURLWithPath:$0)})).rgba
        // Coordinates, integers and primality are supplied independently of the shader.
        let marks:[(Int,Int,Int,Bool)]=[(0,0,1,false),(1,0,2,true),(1,1,3,true),(0,1,4,false),
            (-1,1,5,true),(-1,0,6,false),(-1,-1,7,true),(0,-1,8,false),(1,-1,9,false),
            (2,-1,10,false),(2,0,11,true),(2,1,12,false),(2,2,13,true),(-2,2,17,true)]
        for (x,y,integer,prime) in marks {
            let index=((81+y*4)*164+81+x*4)*4
            if prime { XCTAssertGreaterThan(rgba[index],180,"Prime \(integer)") }
            else { XCTAssertEqual(rgba[index],0,"Composite or one: \(integer)") }
            XCTAssertEqual(rgba[index+3],255)
        }
    }
    func testSurfaceCompositesFallbackBypassAndEmptyInput() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let original=try pixels(nil)
        for definition in EffectRegistry.surfaces38 {
            var effect=definition.makeInstance()
            let result=try pixels(effect)
            XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
            XCTAssertEqual(result,try pixels(EffectInstance(typeID:definition.id,params:[:])),definition.name)
            effect.params["blend"] = .number(Animated(0))
            XCTAssertEqual(original,try pixels(effect),definition.name)
            for only in [false,true] {
                effect=definition.makeInstance();effect.params["only"] = .toggle(only)
                var project=scene(effect)
                for index in project.layers.indices where project.layers[index].content != .adjustment {
                    project.layers[index].fill=Animated(RGBA(0,0,0,0))
                }
                let empty=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,
                    preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
                XCTAssertTrue(empty.allSatisfy{$0==0},definition.name)
            }
        }
    }
    func testFlatFieldsProduceNoFeatureMatte() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for definition in EffectRegistry.featureMattes33 {
            var project=Project.new(name:"Flat",width:32,height:32,fps:30,duration:1,background:RGBA(0,0,0,0))
            var layer=project.makeLayer(name:"Uniform",content:.solid,size:Vec2(32,32))
            layer.fill=Animated(RGBA(0.37,0.42,0.51));layer.effects=[definition.makeInstance()]
            project.layers=[layer]
            let result=try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,
                preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            // Ignore the rasterizer's outer edge, which is a real silhouette.
            for y in 10..<22 { for x in 10..<22 {
                XCTAssertEqual(result[(y*32+x)*4+3],0,definition.name)
            }}
        }
    }
    func testMorphologyRemovesAnIsolatedSpeckAndFillsAnIsolatedHole() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for opening in [true,false] {
            var project=Project.new(name:"Morphology",width:33,height:33,fps:30,duration:1,background:RGBA(0,0,0,0))
            var back=project.makeLayer(name:"Gray",content:.solid,size:Vec2(33,33))
            back.fill=Animated(RGBA(0.25,0.25,0.25))
            var mark=project.makeLayer(name:"Mark",content:.solid,size:Vec2(1,1))
            mark.fill=Animated(opening ? RGBA(1,1,1):RGBA(0,0,0))
            var adjustment=project.makeLayer(name:"Morphology",content:.adjustment,size:Vec2(33,33))
            let id=opening ? "awi37.morph.opening":"awi37.morph.closing"
            adjustment.effects=[try XCTUnwrap(EffectRegistry.definition(id)).makeInstance()]
            project.layers=[adjustment,mark,back]
            let result=try XCTUnwrap(renderer.renderPixels(project:project,time:0,
                preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
            for index in stride(from:0,to:result.count,by:4) {
                XCTAssertLessThanOrEqual(abs(Int(result[index])-64),2,id)
                XCTAssertEqual(result[index+3],255,id)
            }
        }
    }
    func testCoordinateMapPolesAndEmptyCoverage() throws {
        guard let renderer = Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        for definition in EffectRegistry.conformal32 {
            for edge in 0...3 {
                var effect = definition.makeInstance()
                effect.params["edge"] = .choice(edge)
                var project = scene(effect)
                // Place a reciprocal pole on an actual pixel center.
                project.layers[0].effects[0].params["center"] = .point(Animated(Vec2(96.5/192, 72.5/144)))
                for index in project.layers.indices where project.layers[index].content != .adjustment {
                    project.layers[index].fill = Animated(RGBA(0,0,0,0))
                }
                let result = try XCTUnwrap(renderer.renderPixels(project: project, time: 0.4,
                    preserveAlpha: true, mediaURL: { URL(fileURLWithPath: $0) })).rgba
                XCTAssertTrue(result.allSatisfy { $0 == 0 }, "\(definition.name), edges \(edge)")
            }
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
        try writeRemainingFamilyReview(shard:0)
    }
    func testRemainingReviewPart1()throws { try writeRemainingFamilyReview(shard:1) }
    func testRemainingReviewPart2()throws { try writeRemainingFamilyReview(shard:2) }
    func testRemainingReviewPart3()throws { try writeRemainingFamilyReview(shard:3) }
    func testRemainingReviewPart4()throws { try writeRemainingFamilyReview(shard:4) }
    func testRemainingReviewPart5()throws { try writeRemainingFamilyReview(shard:5) }
    func testRemainingReviewPart6()throws { try writeRemainingFamilyReview(shard:6) }
    func testRemainingReviewPart7()throws { try writeRemainingFamilyReview(shard:7) }
    func testRemainingReviewPart8()throws { try writeRemainingFamilyReview(shard:8) }
    func testRemainingReviewPart9()throws { try writeRemainingFamilyReview(shard:9) }
    func testRemainingReviewPart10()throws { try writeRemainingFamilyReview(shard:10) }
    func testRemainingReviewPart11()throws { try writeRemainingFamilyReview(shard:11) }
    private func writeRemainingFamilyReview(shard:Int)throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        let folder=URL(fileURLWithPath:"/tmp/awi-expansion",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let families:[(String,[EffectDefinition])]=[
            ("matte",EffectRegistry.batch33+EffectRegistry.featureMattes33),
            ("time",EffectRegistry.time33+EffectRegistry.sampling33),
            ("transition",EffectRegistry.batch34+EffectRegistry.cameraTransitions34),
            ("shape-particle",EffectRegistry.batch35),
            ("procedural",EffectRegistry.batch36),
            ("finish",EffectRegistry.batch37+EffectRegistry.cleanup37+EffectRegistry.frequency37),
            ("drawing",EffectRegistry.drawing37),("sort",EffectRegistry.sorting31),
            ("retro",EffectRegistry.retro37),("text-geometry",EffectRegistry.textGeometry37),
            ("motion-light",EffectRegistry.batch38),("coordinate-map",EffectRegistry.conformal32),
            ("morphology",EffectRegistry.morphology37),("surface-composite",EffectRegistry.surfaces38),
            ("frequency-stylize",EffectRegistry.transforms37),("nonlinear-detail",EffectRegistry.nonlinear37),
            ("math-background",EffectRegistry.math30),("advanced-clean",EffectRegistry.advancedClean37),
            ("vector-surface",EffectRegistry.data39),
            ("textured-surfaces",EffectRegistry.surfaces40),
            ("distance-contours",EffectRegistry.distance41),
            ("projection",EffectRegistry.projection42),
            ("temporal-analysis",EffectRegistry.temporalAnalysis43),
            ("surface-finish",EffectRegistry.finishes44),
            ("gradient-domain",EffectRegistry.poisson45),
            ("spectral",EffectRegistry.spectral46),
            ("layer-interaction",EffectRegistry.interactions47),
            ("graphic-craft",EffectRegistry.craft48),
            ("measured-motion",EffectRegistry.flow31)
        ]
        for (index,family) in families.enumerated() where index%12==shard {
            let (name,definitions)=family
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
        var previews:[(String,String,Double,Double)]=[
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
            ("awi37.retinexDetail","strength",0,100),
            ("awi37.draw.flowPaint","detail",2,16),("awi37.draw.adaptiveHatch","detail2",0,100),
            ("awi37.draw.edgeStretch","detail",-40,40),("awi37.draw.ridgeInk","detail",1,8),
            ("awi37.draw.spiralEngraving","detail",1,6),
            ("awi37.retro.compositeCrosstalk","phase",0,180),("awi37.retro.ccdSmear","length",10,200),
            ("awi37.retro.plateRegistration","redAngle",-5,5),("awi37.retro.phosphor","window",0.01,0.4),
            ("awi31.segmentSort","length",8,128),
            ("awi37.text.arc","bend",-90,90),("awi37.text.cylinder","phase",0,160),
            ("awi37.text.sphere","latitude",-45,45),("awi37.text.accordion","fold",0,80),
            ("awi37.text.helix","phase",0,180),("awi37.text.attractor","strength",-80,80),
            ("awi38.motionGlow","radius",10,100),("awi38.motionStreaks","angle",0,120),
            ("awi38.motionRays","reach",5,90),("awi38.motionRings","radius",2,40)
        ]
        previews.append(("awi48.craft.burn","first",0,35))
        // Every expansion effect gets motion review, not just the handpicked
        // representatives above. Animate a meaningful authored control around its
        // default; preserve explicit review ranges for effects that need them.
        let explicitIDs=Set(previews.map{$0.0})
        let expansion=EffectRegistry.all.filter { definition in
            (30...48).contains { definition.id.hasPrefix("awi\($0).") }
        }
        for definition in expansion where !explicitIDs.contains(definition.id) {
            for parameter in definition.params where !["blend","mix"].contains(parameter.id) {
                if case .number(let low,let high,_,_)=parameter.kind,
                   case .number(let value)=parameter.defaultValue {
                    let center=value.staticValue,delta=(high-low)*0.15
                    previews.append((definition.id,parameter.id,max(low,center-delta),min(high,center+delta)))
                    break
                }
                if case .point=parameter.kind {
                    previews.append((definition.id,parameter.id,0.25,0.75));break
                }
                if case .angle=parameter.kind,case .number(let value)=parameter.defaultValue {
                    previews.append((definition.id,parameter.id,value.staticValue-90,value.staticValue+90));break
                }
            }
        }
        XCTAssertEqual(Set(previews.map{$0.0}).intersection(Set(expansion.map(\.id))).count,expansion.count,
            "Every expansion effect needs an authored motion review")
        let manifest=previews.map { ["id":$0.0,"parameter":$0.1,"start":$0.2,"end":$0.3] as [String:Any] }
        try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys])
            .write(to:folder.appendingPathComponent("motion-review.json"))
        for (index,preview) in previews.enumerated() where index%12==shard {
            let (id,key,start,end)=preview
            let definition=try XCTUnwrap(EffectRegistry.definition(id))
            XCTAssertTrue(definition.params.contains{$0.id==key},"Review control missing: \(id).\(key)")
            var effect=definition.makeInstance(),value=Animated(start)
            value.insertKeyframe(Keyframe(time:0,value:start));value.insertKeyframe(Keyframe(time:2,value:end))
            if case .point?=definition.params.first(where:{$0.id==key})?.kind {
                var point=Animated(Vec2(start,0.5))
                point.insertKeyframe(Keyframe(time:0,value:Vec2(start,0.5)));point.insertKeyframe(Keyframe(time:2,value:Vec2(end,0.5)))
                effect.params[key] = .point(point)
            } else { effect.params[key] = .number(value) }
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
        if Expansion50EffectTests.contains(effect.typeID) { return Expansion50EffectTests.scene(effect) }
        if effect.typeID.hasPrefix("awi45.poisson.") { return DataEffectTests.scene(effect) }
        if effect.typeID.hasPrefix("awi44.finish.") { return DistanceEffectTests.scene(effect) }
        if effect.typeID.hasPrefix("awi42.projection.") { return ProjectionEffectTests.scene(effect) }
        if effect.typeID.hasPrefix("awi41.contour.") { return DistanceEffectTests.scene(effect) }
        if effect.typeID.hasPrefix("awi39.data.") { return DataEffectTests.scene(effect) }
        if effect.typeID.hasPrefix("awi31.flow") { return FlowEffectTests.scene(effect) }
        if EffectRegistry.temporalIDs33.contains(effect.typeID) { return TemporalEffectTests.scene(effect) }
        if EffectRegistry.textGeometryIDs37.contains(effect.typeID) {
            var project=Project.new(name:"Native type",width:192,height:144,fps:30,duration:3,background:RGBA(0.05,0.07,0.12))
            var layer=project.makeLayer(name:"Type",content:.text,size:Vec2(150,100))
            var text=TextData(string:"AWI\nEFFECT");text.fontSize=28;layer.text=text;layer.effects=[effect];project.layers=[layer]
            return project
        }
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
        if EffectFixtureRequirements.detailIDs.contains(effect.typeID) {
            let grain=EffectInstance(typeID:"ae.noise",params:["amount":.number(Animated(70)),"size":.number(Animated(0.5)),"color":.toggle(true)])
            for index in project.layers.indices where project.layers[index].content != .adjustment { project.layers[index].effects=[grain] }
        }
        return project
    }
}
