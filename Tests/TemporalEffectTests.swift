import XCTest
import AVFoundation
@testable import AWIeffect

/// Animated fixtures are essential: a real time effect is correctly unchanged on
/// a still image. Do not replace these with displaced copies of one static frame.
final class TemporalEffectTests:XCTestCase {
    static func scene(_ effect:EffectInstance?,onAdjustment:Bool=true) -> Project {
        var project=Project.new(name:"Temporal source",width:160,height:160,fps:30,duration:2,background:RGBA(0.04,0.07,0.12))
        var subject=project.makeLayer(name:"Temporal subject",content:.solid,size:Vec2(120,120))
        var fill=Animated(RGBA(0.9,0.1,0.2))
        for (time,color) in [(0.0,RGBA(0.9,0.1,0.2)),(0.3,RGBA(0.9,0.9,0.95)),
            (0.4,RGBA(0.08,0.1,0.15)),(0.5,RGBA(0.9,0.9,0.95)),
            (1.0,RGBA(0.95,0.8,0.1)),(2.0,RGBA(0.7,0.15,0.85))] {
            fill.insertKeyframe(Keyframe(time:time,value:color))
        }
        subject.fill=fill
        var accent=project.makeLayer(name:"Moving accent",content:.shape(.star),size:Vec2(55,55))
        accent.fill=Animated(RGBA(0.95,0.95,0.9))
        var position=Animated(Vec2(35,40))
        position.insertKeyframe(Keyframe(time:0,value:Vec2(35,40)))
        position.insertKeyframe(Keyframe(time:2,value:Vec2(125,115)))
        accent.transform.position=position
        project.layers=[accent,subject]
        if let effect {
            if onAdjustment {
                var adjustment=project.makeLayer(name:"Time effect",content:.adjustment,size:Vec2(160,160))
                adjustment.effects=[effect];project.layers.insert(adjustment,at:0)
            } else { project.layers[1].effects=[effect] }
        }
        return project
    }
    private func render(_ project:Project,time:Double=0.4) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:project,time:time,preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    private func difference(_ a:[UInt8],_ b:[UInt8]) -> Double {
        zip(a,b).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(a.count)
    }
    func testTemporalDefaultsFallbacksAndBypassOnBothLayerTypes() throws {
        for adjustment in [false,true] {
            let original=try render(Self.scene(nil,onAdjustment:adjustment))
            for definition in EffectRegistry.time33+EffectRegistry.sampling33+EffectRegistry.retro37.filter({EffectRegistry.temporalIDs33.contains($0.id)})+EffectRegistry.batch38 {
                var effect=definition.makeInstance()
                let result=try render(Self.scene(effect,onAdjustment:adjustment))
                XCTAssertGreaterThan(difference(original,result),0.05,definition.name)
                XCTAssertLessThan(difference(result,try render(Self.scene(EffectInstance(typeID:definition.id,params:[:]),onAdjustment:adjustment))),0.01,definition.name)
                effect.params["blend"] = .number(Animated(0))
                XCTAssertEqual(original,try render(Self.scene(effect,onAdjustment:adjustment)),definition.name)
            }
        }
    }
    func testZeroTimeSpanAndOffsetAreIdentity() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var effect=definition.makeInstance()
        effect.params["span"] = .number(Animated(0));effect.params["offset"] = .number(Animated(0))
        for adjustment in [false,true] {
            XCTAssertEqual(try render(Self.scene(nil)),try render(Self.scene(effect,onAdjustment:adjustment)))
        }
    }
    func testFrameHoldUsesOneStableSourceFrameBetweenClockTicks() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.hold"))
        let project=Self.scene(definition.makeInstance(),onAdjustment:true)
        XCTAssertEqual(try render(project,time:0.35),try render(project,time:0.4))
        XCTAssertGreaterThan(difference(try render(project,time:0.4),try render(project,time:0.51)),0.05)
    }
    func testRGBTimeSplitWithZeroDelaysPreservesTheCurrentFrame() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.rgb"))
        var effect=definition.makeInstance()
        for key in ["red","green","blue"] { effect.params[key] = .number(Animated(0)) }
        for adjustment in [false,true] {
            XCTAssertLessThan(difference(try render(Self.scene(nil,onAdjustment:adjustment)),
                try render(Self.scene(effect,onAdjustment:adjustment))),0.01)
        }
    }
    func testMotionLightsIgnoreColorChangesWhenAlphaSourceIsSelected() throws {
        let original=try render(Self.scene(nil))
        for definition in EffectRegistry.batch38 {
            var effect=definition.makeInstance();effect.params["source"] = .choice(2)
            // The opaque scene changes color and position but not its full-frame alpha.
            XCTAssertLessThan(difference(original,try render(Self.scene(effect))),0.01,definition.name)
            effect=definition.makeInstance();effect.params["delay"] = .number(Animated(0))
            XCTAssertEqual(original,try render(Self.scene(effect)),definition.name)
        }
    }
    func testSliceSamplesParentedMotionAtRequestedTime() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var effect=definition.makeInstance()
        effect.params["span"] = .number(Animated(0));effect.params["offset"] = .number(Animated(-0.2))
        var project=Self.scene(effect)
        var parent=project.makeLayer(name:"Animated parent",content:.solid,size:Vec2(1,1));parent.isNull=true
        var position=Animated(Vec2(80,80))
        position.insertKeyframe(Keyframe(time:0,value:Vec2(70,70)))
        position.insertKeyframe(Keyframe(time:1,value:Vec2(100,110)))
        parent.transform.position=position
        if let accent=project.layers.firstIndex(where:{$0.name=="Moving accent"}) {
            project.layers[accent].parentID=parent.id
            project.layers[accent].transform.position=Animated(Vec2(0,0))
        }
        project.layers.append(parent)
        let sampled=try render(project,time:0.4)
        project.layers.removeAll{$0.name=="Time effect"}
        XCTAssertLessThan(difference(sampled,try render(project,time:0.2)),0.05,"Use the original parent animation at the sampled time")
    }
    func testDifferenceReadsUpstreamEffectsAndExcludesDownstreamEffects() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.difference"))
        var project=Self.scene(definition.makeInstance())
        let fill=EffectRegistry.fill.makeInstance()
        project.layers[0].effects.insert(fill,at:0)
        let before=try render(project)
        let maxColor=stride(from:0,to:before.count,by:4).map { max(before[$0],before[$0+1],before[$0+2]) }.max() ?? 0
        XCTAssertLessThan(maxColor,3,"Identical upstream fill at both times has zero difference")
        project.layers[0].effects=[definition.makeInstance(),fill]
        let after=try render(project)
        XCTAssertGreaterThan(difference(before,after),20,"Downstream fill applies after the difference")
    }
    func testStackedOffsetsSampleUpstreamTimeEffect() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var first=definition.makeInstance(),second=definition.makeInstance()
        for key in ["span"] { first.params[key] = .number(Animated(0));second.params[key] = .number(Animated(0)) }
        first.params["offset"] = .number(Animated(-0.1));second.params["offset"] = .number(Animated(-0.1))
        var project=Self.scene(first);project.layers[0].effects.append(second)
        let result=try render(project,time:0.4)
        XCTAssertLessThan(difference(result,try render(Self.scene(nil),time:0.2)),0.08,"Two -0.1 s offsets must compose to -0.2 s")
    }
    func testRepeatedTemporalRendersDoNotReuseStaleFrames() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var project=Self.scene(definition.makeInstance())
        let first=try render(project)
        for index in project.layers.indices where project.layers[index].name=="Temporal subject" {
            project.layers[index].fill=Animated(RGBA(0.95,0.2,0.1))
        }
        XCTAssertGreaterThan(difference(first,try render(project)),1,"Frame cache must be cleared between root renders")
    }
    func testTimeSliceAfterBackdropDisplacementSamplesBeforeCurrentCoverage() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var effect=definition.makeInstance()
        effect.params["span"] = .number(Animated(0));effect.params["offset"] = .number(Animated(-0.2))
        var map=EffectRegistry.displacementMap18.makeInstance()
        map.params["h"] = .number(Animated(0));map.params["v"] = .number(Animated(0));map.params["target"] = .choice(1)
        var project=Self.scene(nil)
        var carrier=project.makeLayer(name:"Moving backdrop window",content:.solid,size:Vec2(40,100))
        carrier.fill=Animated(.white);carrier.effects=[map,effect]
        var position=Animated(Vec2(30,80))
        position.insertKeyframe(Keyframe(time:0,value:Vec2(30,80)))
        position.insertKeyframe(Keyframe(time:1,value:Vec2(130,80)))
        carrier.transform.position=position;project.layers.insert(carrier,at:0)
        let sampled=try render(project,time:0.4)
        project.layers.removeFirst()
        let earlier=try render(project,time:0.2)
        // Inside the current window, outside its earlier footprint. Sampling a
        // previously masked result would lose this region entirely.
        let index=(100*160+85)*4
        for channel in 0..<4 {
            XCTAssertEqual(Double(sampled[index+channel]),Double(earlier[index+channel]),accuracy:3)
        }
    }
    func testCameraTimeSliceReadsTheEarlierShot() throws {
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var effect=definition.makeInstance()
        effect.params["span"] = .number(Animated(0));effect.params["offset"] = .number(Animated(-0.2))
        var project=Self.scene(nil)
        var camera=project.makeLayer(name:"Shot camera",content:.camera,size:Vec2(1,1))
        camera.camera=CameraOptions();camera.effects=[effect];project.layers.insert(camera,at:0)
        let sampled=try render(project,time:0.4)
        project.layers[0].effects=[]
        XCTAssertLessThan(difference(sampled,try render(project,time:0.2)),0.05)
    }
    func testTimeSliceReadsEarlierDecodedVideoFrame() throws {
        guard Renderer.shared != nil else { throw XCTSkip("SKIP-GPU") }
        let url=try makeCutVideo()
        defer { try? FileManager.default.removeItem(at:url) }
        var project=Project.new(name:"Actual video time",width:64,height:64,fps:12,duration:1,background:.black)
        var video=project.makeLayer(name:"Video",content:.video(fileName:url.path,pixelWidth:64,pixelHeight:64,hasAudio:false),size:Vec2(64,64))
        let definition=try XCTUnwrap(EffectRegistry.definition("awi33.time.slice"))
        var effect=definition.makeInstance()
        effect.params["span"] = .number(Animated(0));effect.params["offset"] = .number(Animated(-0.5))
        video.effects=[effect];project.layers=[video]
        let earlier=try render(project,time:0.75),index=(32*64+32)*4
        XCTAssertGreaterThan(earlier[index],180,"Earlier source frame is red")
        XCTAssertLessThan(earlier[index+2],60)
        project.layers[0].effects=[]
        let current=try render(project,time:0.75)
        XCTAssertGreaterThan(current[index+2],180,"Current source frame is blue")
        XCTAssertLessThan(current[index],60)
    }
    private func makeCutVideo() throws -> URL {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("temporal-\(UUID().uuidString).mov")
        let writer=try AVAssetWriter(outputURL:url,fileType:.mov)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:64,AVVideoHeightKey:64])
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[
            kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String:64,kCVPixelBufferHeightKey as String:64])
        writer.add(input)
        XCTAssertTrue(writer.startWriting());writer.startSession(atSourceTime:.zero)
        for frame in 0..<12 {
            let deadline=Date().addingTimeInterval(5)
            while !input.isReadyForMoreMediaData {
                if Date()>deadline { throw NSError(domain:"Temporal test writer",code:1) }
                Thread.sleep(forTimeInterval:0.002)
            }
            var buffer:CVPixelBuffer?
            CVPixelBufferCreate(nil,64,64,kCVPixelFormatType_32BGRA,nil,&buffer)
            let pixels=try XCTUnwrap(buffer)
            CVPixelBufferLockBaseAddress(pixels,[])
            let base=try XCTUnwrap(CVPixelBufferGetBaseAddress(pixels)).assumingMemoryBound(to:UInt8.self)
            let stride=CVPixelBufferGetBytesPerRow(pixels)
            for y in 0..<64 { for x in 0..<64 {
                let index=y*stride+x*4
                base[index]=frame<6 ? 0:255;base[index+1]=0;base[index+2]=frame<6 ? 255:0;base[index+3]=255
            } }
            CVPixelBufferUnlockBaseAddress(pixels,[])
            XCTAssertTrue(adaptor.append(pixels,withPresentationTime:CMTime(value:CMTimeValue(frame),timescale:12)))
        }
        input.markAsFinished()
        let finished=expectation(description:"Temporal video fixture")
        writer.finishWriting{finished.fulfill()};wait(for:[finished],timeout:15)
        XCTAssertEqual(writer.status,.completed)
        return url
    }
}
