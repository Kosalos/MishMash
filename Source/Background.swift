import UIKit

class Background: UIView {
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let g:CGFloat = 0.2
        UIColor(red:g, green:g, blue:g, alpha:1).setFill()
        UIBezierPath(rect:bounds).fill()
    }
}
