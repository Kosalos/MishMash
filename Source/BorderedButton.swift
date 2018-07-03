import UIKit

class BorderedButton: UIButton {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        drawBorder(context!,bounds)
    }
}

