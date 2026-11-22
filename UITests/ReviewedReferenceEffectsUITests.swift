import XCTest

final class ReviewedReferenceEffectsUITests: XCTestCase {
    func testNativeLightCoordinatesAndDotControlsFitTheExistingPanel() {
        continueAfterFailure=false
        for id in ["awi.amref.e7b0d60717ad7","awi.amref.ec88108d754e8","awi.ref.liquidLensWipe"] {
            let app=XCUIApplication()
            app.launchArguments=["-uiTesting","-uiTesting-referenceEffect","-uiTesting-referenceID",id]
            app.launch()
            XCTAssertTrue(app.buttons["effect-expand-"+id].firstMatch.waitForExistence(timeout:15))
            if id=="awi.amref.e7b0d60717ad7" {
                let x=app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Light X")).firstMatch
                XCTAssertTrue(x.waitForExistence(timeout:5))
                let value=x.value as? String ?? ""
                XCTAssertFalse(value.contains("%"))
                XCTAssertEqual(Double(value) ?? 0,-120,accuracy:0.001)
            }
            let shot=XCUIScreen.main.screenshot(),name="reference-controls-"+id
            let attachment=XCTAttachment(screenshot:shot);attachment.name=name;attachment.lifetime = .keepAlways;add(attachment)
            try? FileManager.default.createDirectory(atPath:"/tmp/awi-ui",withIntermediateDirectories:true)
            try? shot.pngRepresentation.write(to:URL(fileURLWithPath:"/tmp/awi-ui/"+name+".png"))
            app.terminate()
        }
    }
    func testReviewedTransitionAndCustomPalettePanels() {
        continueAfterFailure = false
        for palette in [false, true] {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting", "-uiTesting-referenceEffect"] + (palette ? ["-uiTesting-referencePalette"] : [])
            app.launch()
            let id = palette ? "awi.amref.e658cad5dcbff" : "awi.amref.eeab7e403ece5"
            XCTAssertTrue(app.buttons["effect-expand-" + id].firstMatch.waitForExistence(timeout: 15))
            let shot = XCUIScreen.main.screenshot()
            let name = palette ? "reviewed-custom-palette" : "reviewed-tile-break"
            let attachment = XCTAttachment(screenshot: shot); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            try? FileManager.default.createDirectory(atPath: "/tmp/awi-ui", withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/awi-ui/\(name).png"))
            app.terminate()
        }
    }
}
