#if DEBUG
import UIKit

enum RigMotionFixture {
    static func image() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 512 / 220
        return UIGraphicsImageRenderer(size: CGSize(width: 220, height: 220), format: format).image { _ in
            let ink = UIColor(red: 0.09, green: 0.11, blue: 0.18, alpha: 1)
            let arm = UIBezierPath()
            arm.move(to: CGPoint(x: 11, y: 103))
            arm.addQuadCurve(to: CGPoint(x: 48, y: 92), controlPoint: CGPoint(x: 25, y: 87))
            arm.addQuadCurve(to: CGPoint(x: 94, y: 105), controlPoint: CGPoint(x: 72, y: 97))
            arm.addQuadCurve(to: CGPoint(x: 164, y: 112), controlPoint: CGPoint(x: 123, y: 93))
            arm.addQuadCurve(to: CGPoint(x: 176, y: 107), controlPoint: CGPoint(x: 170, y: 111))
            arm.addQuadCurve(to: CGPoint(x: 195, y: 103), controlPoint: CGPoint(x: 181, y: 101))
            arm.addQuadCurve(to: CGPoint(x: 207, y: 110), controlPoint: CGPoint(x: 203, y: 104))
            arm.addQuadCurve(to: CGPoint(x: 205, y: 124), controlPoint: CGPoint(x: 211, y: 120))
            arm.addQuadCurve(to: CGPoint(x: 166, y: 131), controlPoint: CGPoint(x: 197, y: 135))
            arm.addQuadCurve(to: CGPoint(x: 95, y: 140), controlPoint: CGPoint(x: 122, y: 141))
            arm.addQuadCurve(to: CGPoint(x: 17, y: 145), controlPoint: CGPoint(x: 52, y: 150))
            arm.close()
            UIColor(red: 0.98, green: 0.73, blue: 0.53, alpha: 1).setFill()
            arm.fill()
            ink.setStroke()
            arm.lineWidth = 3.2
            arm.stroke()

            let sleeve = UIBezierPath()
            sleeve.move(to: CGPoint(x: 11, y: 103))
            sleeve.addQuadCurve(to: CGPoint(x: 51, y: 92), controlPoint: CGPoint(x: 25, y: 87))
            sleeve.addLine(to: CGPoint(x: 74, y: 100))
            sleeve.addQuadCurve(to: CGPoint(x: 73, y: 145), controlPoint: CGPoint(x: 62, y: 124))
            sleeve.addQuadCurve(to: CGPoint(x: 17, y: 145), controlPoint: CGPoint(x: 47, y: 150))
            sleeve.close()
            UIColor(red: 0.29, green: 0.37, blue: 0.57, alpha: 1).setFill()
            sleeve.fill()
            sleeve.lineWidth = 3.2
            sleeve.stroke()

            func line(_ x: CGFloat, _ y: CGFloat, to end: CGPoint, through control: CGPoint) {
                let detail = UIBezierPath()
                detail.move(to: CGPoint(x: x, y: y))
                detail.addQuadCurve(to: end, controlPoint: control)
                detail.lineWidth = 1.7
                detail.lineCapStyle = .round
                detail.stroke()
            }
            line(69, 128, to: CGPoint(x: 96, y: 116), through: CGPoint(x: 85, y: 131))
            line(97, 126, to: CGPoint(x: 154, y: 122), through: CGPoint(x: 128, y: 132))
            line(169, 118, to: CGPoint(x: 195, y: 111), through: CGPoint(x: 181, y: 105))
            line(185, 120, to: CGPoint(x: 205, y: 115), through: CGPoint(x: 200, y: 116))
            line(186, 125, to: CGPoint(x: 203, y: 122), through: CGPoint(x: 197, y: 124))
            line(21, 112, to: CGPoint(x: 51, y: 107), through: CGPoint(x: 39, y: 100))
        }
    }
}
#endif
