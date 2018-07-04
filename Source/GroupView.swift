import UIKit
import simd

class GroupView : UIView {
    var index = Int32()
    var rot = Widget()
    var trn = Widget()
    var scl = Widget()
    var legend:UILabel! = nil
    var active:Bool = true

    let functionName:UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = .darkGray
        btn.addTarget(self, action: #selector(functionNameTapped), for: .touchUpInside)
        return btn
    }()

    //MARK: -

    required init?(coder decoder: NSCoder) { super.init(coder: decoder) }
    
    func initialize(_ nIndex:Int) {
        index = Int32(nIndex)
        
        legend = UILabel()
        legend.textColor = .white
        legend.backgroundColor = nrmColorFast
        legend.text = String(format:"%d",index+1)
        
        addSubview(legend)
        addSubview(functionName)

        wList.append(rot)
        wList.append(trn)
        wList.append(scl)
        addSubview(rot)
        addSubview(trn)
        addSubview(scl)

        // ----------------------------------------------------------
        setControlPointer(&control);

        let pMin:Float = -3
        let pMax:Float = +3
        let pChg:Float = 0.25
        let sMin:Float = 0.1
        let sMax:Float = +4
        let sChg:Float = 0.25
        
        rot.initSingle(funcRotPointer(index),pMin,pMax,pChg,"R")
        trn.initDual(funcXtPointer(index),pMin,pMax,pChg,"T")
        trn.initDual2(funcYtPointer(index))
        scl.initDual(funcXsPointer(index),sMin,sMax,sChg,"S")
        scl.initDual2(funcYsPointer(index))        
        // ----------------------------------------------------------
        var x = CGFloat(), y = CGFloat()
        
        func frame(_ fxs:CGFloat, _ fys:CGFloat, _ dx:CGFloat, _ dy:CGFloat) -> CGRect {
            let r = CGRect(x:x, y:y, width:fxs, height:fys)
            x += dx; y += dy
            return r
        }

        let sWidth:CGFloat = 40
        let sGap:CGFloat = sWidth+5
        let sHeight:CGFloat = 35
        let fnWidth:CGFloat = 110

        x = 10
        y = 5
        legend.frame = frame(10,sHeight,20,0)
        functionName.frame = frame(fnWidth,sHeight,fnWidth+5,0)
        let q1 = [ trn,scl,rot ]
        for q in q1 { q.frame = frame(sWidth,sHeight,sGap,0) }
    }
    
    //MARK:-
    
    func refresh(_ isActive:Bool) {
        functionName.setTitle(varisNames[Int(funcIndex(index))], for: .normal)
        active = isActive
        setNeedsDisplay()
    }
    
    func update() -> Bool {
        var refresh:Bool = false
        for i in wList { if i.update() { refresh = true }}
        return refresh
    }

    func removeAllFocus() { for i in wList { if i.hasFocus { i.hasFocus = false; i.setNeedsDisplay() }}}
        
    func focusMovement(_ pt:CGPoint) -> Bool {
        for i in wList { if i.hasFocus { i.focusMovement(pt); return true }}
        return false
    }
    
    //MARK:-

    func controlLoaded() {
        functionName.setTitle(varisNames[Int(funcIndex(index))], for: .normal)
        for i in wList { i.setNeedsDisplay() }
    }
    
    @objc func functionNameTapped() { vc.launchFunctionIndexPopover(functionName,funcIndexPointer(index)) }

    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        let bkColor = active ? bsOn : bsOff
        legend.backgroundColor = bkColor

        context?.setFillColor(bkColor.cgColor)
        context?.addRect(bounds)
        context?.fillPath()
        
        drawBorder(context!,bounds)
    }
}
