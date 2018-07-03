import UIKit
import Metal
import simd

let kludgeAutoLayout:Bool = false
let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait
let scrnIndex = 0
let scrnLandscape:Bool = false

var control = Control()
var vc:ViewController! = nil
var wList:[Widget]! = nil

let bsOff = UIColor(red:0.25, green:0.25, blue:0.25, alpha: 1)
let bsOn  = UIColor(red:0.1, green:0.3, blue:0.1, alpha: 1)

class ViewController: UIViewController {
    var controlBuffer:MTLBuffer! = nil
    var colorBuffer:MTLBuffer! = nil
    var texture1: MTLTexture!
    var texture2: MTLTexture!
    var pipeline1: MTLComputePipelineState!
    var pipeline2: MTLComputePipelineState!
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    var shadowFlag:Bool = false
    var hiResFlag:Bool = false
    var gList:[GroupView]! = nil
    
    let threadGroupCount = MTLSizeMake(20,20,1)
    var threadGroups = MTLSize()
    
    @IBOutlet var background: Background!
    @IBOutlet var cMove: CMove!
    @IBOutlet var cZoom: CZoom!
    @IBOutlet var metalTextureView: MetalTextureView!
    @IBOutlet var saveLoadButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var shadowButton: UIButton!
    @IBOutlet var grammarButton: UIButton!
    @IBOutlet var randomButton: UIButton!
    @IBOutlet var rndGButton: UIButton!
    @IBOutlet var resButton: UIButton!
    @IBOutlet var sStripeDensity: Widget!
    @IBOutlet var sEscapeRadius: Widget!
    @IBOutlet var sMultiplier: Widget!
    @IBOutlet var sR: Widget!
    @IBOutlet var sG: Widget!
    @IBOutlet var sB: Widget!
    @IBOutlet var sContrast: Widget!
    @IBOutlet var g1: GroupView!
    @IBOutlet var g2: GroupView!
    @IBOutlet var g3: GroupView!
    @IBOutlet var g4: GroupView!

    @IBAction func rndGButtonPressed(_ sender: UIButton) {
        controlRandomGrammar()
        loadedData()
    }

    @IBAction func resButtonPressed(_ sender: UIButton) {
        hiResFlag = !hiResFlag
        setImageViewResolutionAndThreadGroups()
        refresh()
    }
    
    @IBAction func randomButtonPressed(_ sender: UIButton) { randomize() }

    func updateWidgets() {
        shadowButton.backgroundColor = shadowFlag ? bsOn : bsOff
        resButton.backgroundColor = hiResFlag ? bsOn : bsOff
        for i in 0 ..< gList.count { gList[i].refresh(isFunctionActive(Int32(i)) > 0) }
        for i in wList { i.setNeedsDisplay() }
    }
    
    @IBAction func shadowChanged(_ sender: UIButton) {
        shadowFlag = !shadowFlag
        metalTextureView.initialize(shadowFlag ? texture2 : texture1)
        refresh()
    }
    
    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        
        wList = [ sStripeDensity,sEscapeRadius,sMultiplier,sR,sG,sB,sContrast ] as! [Widget]
        gList = [ g1,g2,g3,g4 ]
        for i in 0 ..< gList.count { gList[i].initialize(i) }
        
        sStripeDensity.initSingle(&control.stripeDensity, -10,10,2, "Stripe")
        sEscapeRadius.initSingle(&control.escapeRadius, 0.01,80,3, "Escape")
        sMultiplier.initSingle(&control.multiplier, -1,1,0.1, "Multiplier")
        sR.initSingle(&control.R, 0,1,0.15, "Color R")
        sG.initSingle(&control.G, 0,1,0.15, "Color G")
        sB.initSingle(&control.B, 0,1,0.15, "Color B")
        sContrast.initSingle(&control.contrast, 0.1,5,0.5, "Contrast")
        
        do {
            let defaultLibrary:MTLLibrary! = self.device.makeDefaultLibrary()
            guard let kf1 = defaultLibrary.makeFunction(name: "fractalShader")  else { fatalError() }
            pipeline1 = try device.makeComputePipelineState(function: kf1)
            
            guard let kf2 = defaultLibrary.makeFunction(name: "shadowShader")  else { fatalError() }
            pipeline2 = try device.makeComputePipelineState(function: kf2)
        }
        catch { fatalError("error creating pipelines") }
        
        controlBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<Control>.stride, options: MTLResourceOptions.storageModeShared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Timer.scheduledTimer(withTimeInterval:0.02, repeats:true) { timer in self.timerHandler() }
        randomize()
    }
    
    //MARK: -
    
    @objc func timerHandler() {
        var refresh:Bool = false
        for i in wList { if i.update() { refresh = true }}
        if cMove.update() { refresh = true }
        if cZoom.update() { refresh = true }
        if refresh { updateImage() }
    }
    
    //MARK: -
    
    func refresh() {
        updateWidgets()
        updateImage()
    }
    
    func loadedData() {
        updateGrammarString()
        refresh()
    }
    
    func randomize() {
        controlRandom()
        loadedData()
    }

    func updateGrammarString() {
        var chars:[UInt8] = []
        for i in 0 ..< MAX_GRAMMER { chars.append(UInt8(getGrammarCharacter(Int32(i)))) }
        chars.append(UInt8(0))
        
        let str = String(data:Data(chars), encoding: .utf8)
        grammarButton.setTitle(str, for: .normal)
        
        refresh()
    }
    
    //MARK: -
    
    var bPtr:UIButton! = nil
    var groupIndex:Int = 0
    var indexPointer:UnsafeMutableRawPointer! = nil
    
    func launchFunctionIndexPopover(_ b:UIButton, _ v:UnsafeMutableRawPointer) {
        bPtr = b
        indexPointer = v
        functionIndex = Int(indexPointer.load(as: Int32.self))
        performSegue(withIdentifier: "FListSegue", sender: self)
    }
    
    func functionNameChanged() {
        indexPointer.storeBytes(of:Int32(functionIndex), as:Int32.self)
        refresh()
    }
    
    //MARK: -
    
    func removeAllFocus() {
        for s in wList { if s.hasFocus { s.hasFocus = false; s.setNeedsDisplay() }}
        if cMove.hasFocus { cMove.hasFocus = false; cMove.setNeedsDisplay() }
        if cZoom.hasFocus { cZoom.hasFocus = false; cZoom.setNeedsDisplay() }
    }
    
    func focusMovement(_ pt:CGPoint) {
        for s in wList { if s.hasFocus { s.focusMovement(pt); return }}
        if cMove.hasFocus { cMove.focusMovement(pt); return }
        if cZoom.hasFocus { cZoom.focusMovement(pt); return }
    }
    
    //MARK: -
    
    @objc func rotated() {
        let vxs = view.bounds.width
        let vys = view.bounds.height
        let gxs = CGFloat(285)
        let gys = CGFloat(47)
        let cxs = CGFloat(100)
        let xc = vxs/2
        let bys = CGFloat(35)
        let gap = bys+5
        var x = CGFloat()
        var y = CGFloat()
        
        func frame(_ xs:CGFloat, _ ys:CGFloat, _ dx:CGFloat, _ dy:CGFloat) -> CGRect {
            let r = CGRect(x:x, y:y, width:xs, height:ys)
            x += dx; y += dy
            return r
        }
        
        metalTextureView.frame = view.bounds
        let bkxs:CGFloat = 505
        let bkys:CGFloat = 270
        background.frame = CGRect(x:(vxs-bkxs)/2, y:vys-bkys-20, width:bkxs, height:bkys)
        
        x = 5
        y = 5
        grammarButton.frame = frame(150,bys,155,0)
        rndGButton.frame = frame(65,bys,75,0)
        resButton.frame = frame(50,bys,0,0)
        x = 5
        y += gap
        for i in gList { i.frame = frame(gxs,gys,0,gys+3) }
        
        x = 10 + gxs
        y = 5
        let t2List = [ sMultiplier,sEscapeRadius,sStripeDensity,sContrast,shadowButton ] as [UIView]
        for t in t2List { t.frame = frame(cxs,bys,0,gap) }
        cMove.frame = frame(70,60,75,0)
        cZoom.frame = frame(70,60,0,0)

        x = gxs + cxs + 15
        y = 5
        let t3List = [ randomButton,sR,sG,sB,saveLoadButton ] as [UIView]
        for t in t3List { t.frame = frame(cxs,bys,0,gap) }

        x += 55
        y += 10
        helpButton.frame = frame(bys,bys,0,0)
        
        setImageViewResolutionAndThreadGroups()
    }
    
    //MARK: -
    
    func setImageViewResolutionAndThreadGroups() {
        let scale:CGFloat = hiResFlag ? 1.0 : 0.5
        control.xSize = Int32(view.bounds.size.width * scale)
        control.ySize = Int32(view.bounds.size.height * scale)
        let xsz = Int(control.xSize)
        let ysz = Int(control.ySize)
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: xsz,
            height: ysz,
            mipmapped: false)
        texture1 = self.device.makeTexture(descriptor: textureDescriptor)!
        texture2 = self.device.makeTexture(descriptor: textureDescriptor)!
        
        metalTextureView.initialize(texture1)

        let maxsz = max(xsz,ysz) + Int(threadGroupCount.width-1)
        threadGroups = MTLSizeMake(
            maxsz / threadGroupCount.width,
            maxsz / threadGroupCount.height,1)
    }
    
    //MARK: -
    
    func alterPosition(_ dx:Float, _ dy:Float) {
        let mx = (control.xmax - control.xmin) * dx / 500
        let my = (control.ymax - control.ymin) * dy / 500
        
        control.xmin -= mx;  control.xmax -= mx
        control.ymin -= my;  control.ymax -= my
        
        updateImage()
    }
    
    func alterZoom(_ dz:Float) {
        let deltaZoom:Float = 0.5 + dz / 50
        let xsize = (control.xmax - control.xmin) * deltaZoom
        let ysize = (control.ymax - control.ymin) * deltaZoom
        let xc = (control.xmin + control.xmax) / 2
        let yc = (control.ymin + control.ymax) / 2
        
        control.xmin = xc - xsize;  control.xmax = xc + xsize
        control.ymin = yc - ysize;  control.ymax = yc + ysize
        
        updateImage()
    }
    
    //MARK: -
    
    func calcFractal() {
        control.dx = (control.xmax - control.xmin) / Float(control.xSize)
        control.dy = (control.ymax - control.ymin) / Float(control.ySize)
        controlBuffer.contents().copyMemory(from: &control, byteCount:MemoryLayout<Control>.stride)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline1)
        commandEncoder.setTexture(texture1, index: 0)
        commandEncoder.setBuffer(controlBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(colorBuffer, offset: 0, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if shadowFlag { applyShadow() }
    }
    
    func applyShadow() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline2)
        commandEncoder.setTexture(texture1, index: 0)
        commandEncoder.setTexture(texture2, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }

    //MARK: -
    
    var isBusy:Bool = false

    func updateImage() {
        if !isBusy {
            isBusy = true
            calcFractal()
            metalTextureView.display(metalTextureView.layer)
            isBusy = false
        }
    }
}
