import XCTest
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import AWIeffect

final class ProjectionEffectTests:XCTestCase {
    private static let directory=FileManager.default.temporaryDirectory.appendingPathComponent("projection-fixtures-\(UUID().uuidString)")
    private static func layout(_ id:String) -> Int {
        if id.hasSuffix("fromCube") { return 1 };if id.hasSuffix("fromOcta") { return 2 };if id.hasSuffix("fromDualFish") { return 3 };return 0
    }
    /// Analytic environment: direction-coded color and a latitude/longitude grid.
    /// The decoder fixtures are real cube/octahedral/fisheye layouts, not arbitrary artwork.
    private static func image(_ layout:Int) -> (URL,Int,Int) {
        let width=192,height=layout==1 ? 128:layout==2 ? 192:96
        let url=directory.appendingPathComponent("layout-\(layout).png")
        if FileManager.default.fileExists(atPath:url.path) { return (url,width,height) }
        try? FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        var bytes=[UInt8](repeating:255,count:width*height*4)
        for y in 0..<height { for x in 0..<width {
            let u=(Double(x)+0.5)/Double(width),v=(Double(y)+0.5)/Double(height)
            var ray=SIMD3<Double>(0,0,1),valid=true
            switch layout {
            case 1:
                let face=min(2,Int(u*3))+min(1,Int(v*2))*3,qx=(u*3-floor(u*3))*2-1,qy=(v*2-floor(v*2))*2-1
                switch face {
                case 0:ray=SIMD3(1,-qy,-qx);case 1:ray=SIMD3(-1,-qy,qx);case 2:ray=SIMD3(qx,1,qy)
                case 3:ray=SIMD3(qx,-1,-qy);case 4:ray=SIMD3(qx,-qy,1);default:ray=SIMD3(-qx,-qy,-1)
                }
            case 2:
                let qx=2*u-1,qy=1-2*v,z=1-abs(qx)-abs(qy)
                ray=z>=0 ? SIMD3(qx,qy,z):SIMD3((1-abs(qy))*(qx>=0 ? 1:-1),(1-abs(qx))*(qy>=0 ? 1:-1),z)
            case 3:
                let rear=u>=0.5,qx=(u*2-floor(u*2))*2-1,qy=1-v*2,r=hypot(qx,qy),angle=r*Double.pi/2
                valid=r<=1;ray=SIMD3((r>0 ? qx/r:0)*sin(angle)*(rear ? -1:1),(r>0 ? qy/r:0)*sin(angle),cos(angle)*(rear ? -1:1))
            default:
                let longitude=(u-0.5)*2*Double.pi,latitude=(0.5-v)*Double.pi
                ray=SIMD3(sin(longitude)*cos(latitude),sin(latitude),cos(longitude)*cos(latitude))
            }
            ray/=sqrt(ray.x*ray.x+ray.y*ray.y+ray.z*ray.z)
            let longitude=atan2(ray.x,ray.z),latitude=asin(min(1,max(-1,ray.y)))
            let grid=abs(sin(longitude*6))<0.065 || abs(sin(latitude*6))<0.065
            let colors=[ray.x*0.4+0.5,ray.y*0.4+0.5,ray.z*0.4+0.5],index=(y*width+x)*4
            for channel in 0..<3 { bytes[index+channel]=valid ? UInt8(((grid ? 0.08:colors[channel])*255).rounded()):0 }
            bytes[index+3]=valid ? 255:0
        }}
        guard let provider=CGDataProvider(data:Data(bytes) as CFData),let image=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,
            bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),
            provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent),
            let destination=CGImageDestinationCreateWithURL(url as CFURL,UTType.png.identifier as CFString,1,nil) else { XCTFail("Projection fixture failed");return(url,width,height) }
        CGImageDestinationAddImage(destination,image,nil);XCTAssertTrue(CGImageDestinationFinalize(destination));return(url,width,height)
    }
    static func scene(_ effect:EffectInstance?,onAdjustment:Bool=false,sourceID:String?=nil) -> Project {
        let (url,width,height)=image(layout(sourceID ?? effect?.typeID ?? ""))
        var project=Project.new(name:"Panorama projections",width:width,height:height,fps:30,duration:2,background:RGBA(0,0,0,0))
        var layer=project.makeLayer(name:"Spherical grid",content:.image(fileName:url.path,pixelWidth:width,pixelHeight:height),size:Vec2(Double(width),Double(height)))
        if let effect,!onAdjustment { layer.effects=[effect] };project.layers=[layer]
        if let effect,onAdjustment {
            var adjustment=project.makeLayer(name:"Projection",content:.adjustment,size:Vec2(Double(width),Double(height)))
            adjustment.effects=[effect];project.layers.insert(adjustment,at:0)
        }
        return project
    }
    private func render(_ effect:EffectInstance?,adjustment:Bool=false,sourceID:String?=nil) throws -> [UInt8] {
        guard let renderer=Renderer.shared else { throw XCTSkip("SKIP-GPU") }
        return try XCTUnwrap(renderer.renderPixels(project:Self.scene(effect,onAdjustment:adjustment,sourceID:sourceID),time:0.4,
            preserveAlpha:true,mediaURL:{URL(fileURLWithPath:$0)})).rgba
    }
    func testDefaultsFallbacksBypassAndPlacement() throws {
        XCTAssertEqual(EffectRegistry.projection42.count,12)
        for definition in EffectRegistry.projection42 {
            XCTAssertEqual(EffectSection.of(definition),.threeD)
            for adjustment in [false,true] {
                let original=try render(nil,adjustment:adjustment,sourceID:definition.id)
                var effect=definition.makeInstance();let output=try render(effect,adjustment:adjustment)
                XCTAssertGreaterThan(zip(original,output).filter{abs(Int($0.0)-Int($0.1))>2}.count,50,definition.name)
                XCTAssertEqual(output,try render(EffectInstance(typeID:definition.id,params:[:]),adjustment:adjustment),definition.name)
                effect.params["blend"] = .number(Animated(0))
                XCTAssertEqual(original,try render(effect,adjustment:adjustment),definition.name)
            }
        }
    }
    func testReorientationHasAnExactZeroPoseAndFullTurn() throws {
        let original=try render(nil)
        var effect=try XCTUnwrap(EffectRegistry.definition("awi42.projection.rotate")).makeInstance()
        for axis in ["yaw","pitch","roll"] { effect.params[axis] = .number(Animated(0)) }
        effect.params["sampling"] = .choice(0)
        let output=try render(effect)
        XCTAssertLessThan(zip(original,output).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(original.count),0.05)
        effect.params["yaw"] = .number(Animated(360))
        let fullTurn=try render(effect)
        XCTAssertLessThan(zip(original,fullTurn).reduce(0.0){$0+Double(abs(Int($1.0)-Int($1.1)))}/Double(original.count),0.05)
    }
    /// Decode three independently authored layouts to the same spherical image.
    /// Interior color fidelity checks catch swapped cube faces and rear-hemisphere flips.
    func testDecodersAgreeWithAnalyticSphericalEnvironment() throws {
        for id in ["fromCube","fromOcta","fromDualFish"] {
            var effect=try XCTUnwrap(EffectRegistry.definition("awi42.projection."+id)).makeInstance()
            for axis in ["yaw","pitch","roll"] { effect.params[axis] = .number(Animated(0)) }
            let project=Self.scene(effect),output=try render(effect)
            let width=project.width,height=project.height
            var error=0.0,count=0
            for y in stride(from:4,to:height-4,by:7) { for x in stride(from:4,to:width-4,by:7) {
                let longitude=((Double(x)+0.5)/Double(width)-0.5)*2*Double.pi
                let latitude=(0.5-(Double(y)+0.5)/Double(height))*Double.pi
                // Exclude the deliberately dark grid and its antialias footprint.
                if abs(sin(longitude*6))<0.3 || abs(sin(latitude*6))<0.3 { continue }
                let ray=[sin(longitude)*cos(latitude),sin(latitude),cos(longitude)*cos(latitude)],index=(y*width+x)*4
                for channel in 0..<3 { error+=abs(Double(output[index+channel])/255-(ray[channel]*0.4+0.5));count+=1 }
            }}
            XCTAssertGreaterThan(count,100)
            XCTAssertLessThan(error/Double(max(1,count)),0.06,id)
        }
    }
}
