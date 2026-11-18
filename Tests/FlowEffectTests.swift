import XCTest
import Metal
@testable import AWIeffect

final class FlowEffectTests:XCTestCase {
    /// Stable texture moves; illumination does not change. Brightness animation
    /// is a useful time-effect fixture but violates a flow solver's assumptions.
    static func scene(_ effect:EffectInstance?,onAdjustment:Bool=true) -> Project {
        var project=Project.new(name:"Measured motion",width:160,height:160,fps:30,duration:2,background:RGBA(0.04,0.07,0.12))
        var layer=project.makeLayer(name:"Moving texture",content:.solid,size:Vec2(150,150))
        layer.fill=Animated(RGBA(0.12,0.2,0.35))
        var checker=EffectRegistry.checkerboard.makeInstance()
        checker.params["size"] = .number(Animated(31))
        layer.effects=[checker]
        var position=Animated(Vec2(16,80))
        position.insertKeyframe(Keyframe(time:0,value:Vec2(16,80)))
        position.insertKeyframe(Keyframe(time:1,value:Vec2(176,80)))
        layer.transform.position=position
        if let effect,!onAdjustment { layer.effects.append(effect) }
        project.layers=[layer]
        if let effect,onAdjustment {
            var adjustment=project.makeLayer(name:"Measured flow",content:.adjustment,size:Vec2(160,160))
            adjustment.effects=[effect];project.layers.insert(adjustment,at:0)
        }
        return project
    }

    private func field(dx:Double,dy:Double,width:Int=96,height:Int=96) throws -> (Int,Int,[Float]) {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        func texture(_ shiftX:Double,_ shiftY:Double) throws -> MTLTexture {
            let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:width,height:height,mipmapped:false)
            descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
            let texture=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
            var values=[UInt16](repeating:0,count:width*height*4)
            for y in 0..<height { for x in 0..<width {
                let u=Double(x)-shiftX,v=Double(y)-shiftY
                let value=0.5+0.14*sin(0.19*u+0.07*v)+0.12*cos(0.09*u-0.22*v)+0.09*sin(0.035*u*v)
                let index=(y*width+x)*4
                for channel in 0..<3 { values[index+channel]=Float16(value).bitPattern }
                values[index+3]=Float16(1).bitPattern
            }}
            values.withUnsafeBytes { texture.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,
                withBytes:$0.baseAddress!,bytesPerRow:width*8) }
            return texture
        }
        let previous=try texture(0,0),current=try texture(dx,dy)
        let pool=TexturePool(device:renderer.device),command=try XCTUnwrap(renderer.queue.makeCommandBuffer())
        let effect=try XCTUnwrap(EffectRegistry.definition("awi31.flowWarp")).makeInstance()
        let context=EffectContext(gpu:renderer.fx,cb:command,input:current,effect:effect,time:0.4,unit:1,pool:pool)
        let flow=EffectRegistry.measuredFlow31(context,previous:previous)
        let descriptor=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba16Float,width:flow.width,height:flow.height,mipmapped:false)
        descriptor.storageMode = .shared;descriptor.usage=[.shaderRead,.shaderWrite]
        let readback=try XCTUnwrap(renderer.device.makeTexture(descriptor:descriptor))
        let blit=try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:flow,sourceSlice:0,sourceLevel:0,sourceOrigin:MTLOrigin(x:0,y:0,z:0),
            sourceSize:MTLSize(width:flow.width,height:flow.height,depth:1),to:readback,
            destinationSlice:0,destinationLevel:0,destinationOrigin:MTLOrigin(x:0,y:0,z:0))
        blit.endEncoding();command.commit();command.waitUntilCompleted();XCTAssertNil(command.error)
        var values=[UInt16](repeating:0,count:flow.width*flow.height*4)
        values.withUnsafeMutableBytes { readback.getBytes($0.baseAddress!,bytesPerRow:flow.width*8,
            from:MTLRegionMake2D(0,0,flow.width,flow.height),mipmapLevel:0) }
        return (flow.width,flow.height,values.map{Float(Float16(bitPattern:$0))})
    }
    func testStaticTextureProducesZeroMotion() throws {
        let (width,height,values)=try field(dx:0,dy:0)
        for index in 0..<(width*height) {
            XCTAssertEqual(values[index*4],0,accuracy:0.001)
            XCTAssertEqual(values[index*4+1],0,accuracy:0.001)
        }
    }
    func testFlowEffectsFallbacksAndBlendBypass() throws {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        func render(_ project:Project) throws -> [UInt8] {
            try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,
                mediaURL:{URL(fileURLWithPath:$0)})).rgba
        }
        for adjustment in [false,true] {
            let original=try render(Self.scene(nil,onAdjustment:adjustment))
            for definition in EffectRegistry.flow31 {
                var effect=definition.makeInstance()
                let result=try render(Self.scene(effect,onAdjustment:adjustment))
                let changed=zip(original,result).filter{abs(Int($0.0)-Int($0.1))>2}.count
                XCTAssertGreaterThan(changed,50,definition.name)
                XCTAssertEqual(result,try render(Self.scene(EffectInstance(typeID:definition.id,params:[:]),onAdjustment:adjustment)),definition.name)
                effect.params["blend"] = .number(Animated(0))
                XCTAssertEqual(original,try render(Self.scene(effect,onAdjustment:adjustment)),definition.name)
            }
        }
    }
    func testKnownTranslationHasCorrectDirectionAndScale() throws {
        let (width,height,values)=try field(dx:4,dy:-3)
        var error:Float=0,count=0
        for y in 16..<(height-16) { for x in 16..<(width-16) {
            let index=(y*width+x)*4
            guard values[index+2]>0.15 else { continue }
            error+=hypot(values[index]-4,values[index+1]+3);count+=1
        }}
        XCTAssertGreaterThan(count,500,"The solver must find actual texture, not reject every sample")
        XCTAssertLessThan(error/Float(max(1,count)),1.5,"Signed flow must recover the known translation")
    }
    func testSolveResolutionIsBoundedIndependentlyOfOutput() throws {
        let (width,height,values)=try field(dx:0,dy:0,width:256,height:192)
        XCTAssertEqual(width,128);XCTAssertEqual(height,96)
        XCTAssertTrue(values.allSatisfy{$0.isFinite})
    }
}
