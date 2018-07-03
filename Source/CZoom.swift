import UIKit

class CZoom: UIView {
    let viewSize:Float = 4  // -2 ... +2
    var scale:Float = 0
    var xc:CGFloat = 0
    var fastEdit = true
    var hasFocus = false

    func mapPoint(_ pt:CGPoint) -> float3 {
        var v = float3()
        v.x = Float(pt.x) * scale - viewSize/2 // centered on origin
        v.y = Float(pt.y) * scale - viewSize/2
        v.z = 0
        return v
    }
    
    func unMapPoint(_ p:float3) -> CGPoint {
        var v = CGPoint()
        v.x = xc + CGFloat(p.x / scale)
        v.y = xc + CGFloat(p.y / scale)
        return v
    }
    
    override func draw(_ rect: CGRect) {
        if scale == 0 {
            scale = viewSize / Float(bounds.width)
            xc = bounds.width / 2
            
            let tap1 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap1(_:)))
            tap1.numberOfTapsRequired = 1
            addGestureRecognizer(tap1)
            
            let tap2 = UITapGestureRecognizer(target: self, action: #selector(self.handleTap2(_:)))
            tap2.numberOfTapsRequired = 2
            addGestureRecognizer(tap2)
            
            isUserInteractionEnabled = true
        }
        
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(fastEdit ? nrmColorFast.cgColor : nrmColorSlow.cgColor)
        context?.addRect(bounds)
        context?.fillPath()
        
        context?.setLineWidth(1)
        context?.setStrokeColor(UIColor.darkGray.cgColor)
        context?.addRect(bounds)
        context?.move(to: CGPoint(x:0, y:bounds.height/2))
        context?.addLine(to: CGPoint(x:bounds.width, y:bounds.height/2))
        context?.strokePath()
        
        drawText(10,8,.lightGray,16,"Zoom")
        
        drawBorder(context!,bounds)
        
        let path = UIBezierPath(rect:bounds)
        context!.setStrokeColor(hasFocus ? UIColor.red.cgColor : UIColor.black.cgColor)
        context!.setLineWidth(1)
        context!.addPath(path.cgPath)
        context!.strokePath()
    }
    
    //MARK:-
    
    func tapCommon() {
        dx = 0
        dy = 0
        setNeedsDisplay()
    }
    
    @objc func handleTap1(_ sender: UITapGestureRecognizer) {
        vc.removeAllFocus()
        hasFocus = true
        tapCommon()
    }
    
    @objc func handleTap2(_ sender: UITapGestureRecognizer) {
        fastEdit = !fastEdit
        tapCommon()
    }

    // MARK: Touch --------------------------
    
    var touched:Bool = false
    var dx:Float = 0
    var dy:Float = 0
    
    func update() -> Bool {
        if touched { vc.alterZoom(dy * 0.2) }
        return touched
    }
    
    //MARK:-
    
    func focusMovement(_ pt:CGPoint) {
        if pt.x == 0 { touched = false; return }
        
        dy = Float(pt.y) / 30
        
        if !fastEdit {
            dy /= 10
        }
        
        touched = true
        setNeedsDisplay()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            dy = Float(pt.y - bounds.size.height/2) * 0.05
            touched = true
            
            if !fastEdit {
                dy /= 100
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesBegan(touches, with:event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with:event) }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touched = false
    }
}
