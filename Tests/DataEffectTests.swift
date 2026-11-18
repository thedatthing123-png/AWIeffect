import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class DataEffectTests:XCTestCase {
    private static let normalImageURL=FileManager.default.temporaryDirectory.appendingPathComponent("data-normal-\(UUID().uuidString).png")
    private static func prepareNormalImage() {
        if FileManager.default.fileExists(atPath:normalImageURL.path) { return }
        var bytes=[UInt8](repeating:255,count:160*160*4)
        for y in 0..<160 { for x in 0..<160 {
            let u=(Double(x)+0.5)/80-1,v=(Double(y)+0.5)/80-1
            var nx=0.86*sin(2.7*u+0.4*cos(5*v))+0.22*sin(9*v)
            var ny=0.86*sin(2.7*v+0.4*sin(4*u))+0.22*cos(8*u)
            let scale=max(1,hypot(nx,ny)/0.98);nx/=scale;ny/=scale
            let nz=sqrt(max(0,1-nx*nx-ny*ny)),index=(y*160+x)*4
            for (channel,value) in [nx,ny,nz].enumerated() { bytes[index+channel]=UInt8(((value*0.5+0.5)*255).rounded()) }
        }}
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),
              let image=CGImage(width:160,height:160,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:160*4,
                space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
                provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent),
              let destination=CGImageDestinationCreateWithURL(normalImageURL as CFURL,UTType.png.identifier as CFString,1,nil) else {
            XCTFail("Could not construct the analytic data fixture");return
        }
        CGImageDestinationAddImage(destination,image,nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
    static func scene(_ effect:EffectInstance?,onAdjustment:Bool=true) -> Project {
        prepareNormalImage()
        var project=Project.new(name:"Vector and normal fields",width:160,height:160,fps:30,duration:2,background:RGBA(0,0,0,0))
        var layer=project.makeLayer(name:"Normal field",content:.image(fileName:normalImageURL.path,pixelWidth:160,pixelHeight:160),size:Vec2(160,160))
        var selected=effect
        var environment:Layer?
        if let effect,EffectRegistry.layerRefIDs.contains(effect.typeID) {
            var reference=project.makeLayer(name:"Environment",content:.solid,size:Vec2(160,160))
            reference.effects=[EffectRegistry.fourColorGradient.makeInstance()]
            selected?.text=["layer":reference.id.uuidString];environment=reference
        }
        if let selected,!onAdjustment { layer.effects.append(selected) }
        project.layers=[layer]
        if let environment { project.layers.append(environment) }
        if let selected,onAdjustment {
            var adjustment=project.makeLayer(name:"Data operator",content:.adjustment,size:Vec2(160,160))
            adjustment.effects=[selected];project.layers.insert(adjustment,at:0)
        }
        return project
    }
    private func render(_ project:Project) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:project,time:0.4,preserveAlpha:true,
            mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    func testDataOperatorDefaultsFallbacksAndBlendBypass() throws {
        for adjustment in [false,true] {
            let original=try render(Self.scene(nil,onAdjustment:adjustment))
            for definition in EffectRegistry.data39 {
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
    func testVectorRotationZeroAndMissingReferencesAreIdentity() throws {
        let original=try render(Self.scene(nil))
        var rotation=try XCTUnwrap(EffectRegistry.definition("awi39.data.rotate")).makeInstance()
        rotation.params["angle"] = .number(Animated(0))
        let rotated=try render(Self.scene(rotation))
        XCTAssertLessThan(zip(original,rotated).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(original.count),0.01)
        for id in ["awi39.data.normalReflection","awi39.data.normalRefraction","awi39.data.normalCombine"] {
            var project=Self.scene(nil)
            project.layers[0].effects.append(try XCTUnwrap(EffectRegistry.definition(id)).makeInstance())
            XCTAssertEqual(original,try render(project),id)
        }
    }
    func testDataToolsHaveAnExplicitSectionAndReferencePickers() {
        for definition in EffectRegistry.data39 { XCTAssertEqual(EffectSection.of(definition),.data,definition.name) }
        for id in ["awi39.data.normalReflection","awi39.data.normalRefraction","awi39.data.normalCombine"] {
            XCTAssertTrue(EffectRegistry.layerRefIDs.contains(id))
        }
    }
}
