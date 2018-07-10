import UIKit
import Metal
import MetalKit
import simd

var control = Control()
var vc:ViewController! = nil
var wList:[Widget]! = nil

let view3D = View3D()
var is3D:Bool = false

let bsOff = UIColor(red:0.25, green:0.25, blue:0.25, alpha: 1)
let bsOn  = UIColor(red:0.1, green:0.3, blue:0.1, alpha: 1)

class ViewController: UIViewController {
    var rendererL: Renderer!
    var rendererR: Renderer!
    var controlBuffer:MTLBuffer! = nil
    var colorBuffer:MTLBuffer! = nil
    var texture1: MTLTexture!
    var texture2: MTLTexture!
    var pipeline1: MTLComputePipelineState!
    var pipeline2: MTLComputePipelineState!
    var pipeline3: MTLComputePipelineState!
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    var shadowFlag:Bool = false
    var hiResFlag:Bool = false
    var autoMoveFlag:Bool = false
    var gList:[GroupView]! = nil
    var isStereo:Bool = false
    
    @IBOutlet var d2View: MetalTextureView!
    @IBOutlet var d3ViewL: MTKView!
    @IBOutlet var d3ViewR: MTKView!
    @IBOutlet var widgetBackground: Background!
    
    let threadGroupCount = MTLSizeMake(20,20,1)
    var threadGroups = MTLSize()
    
    @IBOutlet var cMove: CMove!
    @IBOutlet var cZoom: CZoom!
    @IBOutlet var saveLoadButton: UIButton!
    @IBOutlet var loadNextButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var shadowButton: UIButton!
    @IBOutlet var grammarButton: UIButton!
    @IBOutlet var randomButton: UIButton!
    @IBOutlet var rndGButton: UIButton!
    @IBOutlet var resButton: UIButton!
    @IBOutlet var emailButton: UIButton!
    @IBOutlet var autoButton: UIButton!
    @IBOutlet var is3DButton: UIButton!
    @IBOutlet var isStereoButton: UIButton!
    @IBOutlet var sHeight: Widget!
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

    @IBAction func is3DButtonPressed(_ sender: UIButton) {
        is3D = !is3D
        initRenderViews()
        refresh()
    }
    
    @IBAction func isStereoButtonPressed(_ sender: UIButton) {
        isStereo = !isStereo
        setImageViewResolutionAndThreadGroups()
        initRenderViews()
        refresh()
    }

    @IBAction func loadNextButtonPressed(_ sender: UIButton) {
        let ss = SaveLoadViewController()
        ss.loadNext()
    }
    
    @IBAction func autoButtonPressed(_ sender: UIButton) {
        autoMoveFlag = !autoMoveFlag
        if autoMoveFlag { controlInitAutoMove() }
        updateWidgets()
    }
    
    @IBAction func emailButtonPressed(_ sender: UIButton) { sendEmail() }

    @IBAction func rndGButtonPressed(_ sender: UIButton) {
        controlRandomGrammar()
        loadedData()
    }
    
    @IBAction func resButtonPressed(_ sender: UIButton) {
        hiResFlag = !hiResFlag
        setImageViewResolutionAndThreadGroups()
        initRenderViews()
        refresh()
        
        if hiResFlag && is3D && isStereo {
            let hk = d3ViewL.bounds
            arcBall.initialize(Float(hk.size.width*2),Float(hk.size.height*2))
        }
    }
    
    @IBAction func randomButtonPressed(_ sender: UIButton) { randomize() }
    
    func updateWidgets() {
        shadowButton.backgroundColor = shadowFlag ? bsOn : bsOff
        resButton.backgroundColor = hiResFlag ? bsOn : bsOff
        autoButton.backgroundColor = autoMoveFlag ? bsOn : bsOff
        is3DButton.backgroundColor = is3D ? bsOn : bsOff
        isStereoButton.backgroundColor = isStereo ? bsOn : bsOff
        for i in 0 ..< gList.count { gList[i].refresh(isFunctionActive(Int32(i)) > 0) }
        for i in wList { i.setNeedsDisplay() }
    }
    
    @IBAction func shadowChanged(_ sender: UIButton) {
        shadowFlag = !shadowFlag
        d2View.initialize(shadowFlag ? texture2 : texture1)
        refresh()
    }
    
    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        setControlPointer(&control);
        
        wList = [ sStripeDensity,sEscapeRadius,sMultiplier,sR,sG,sB,sContrast,sHeight] as! [Widget]
        gList = [ g1,g2,g3,g4 ]
        for i in 0 ..< gList.count { gList[i].initialize(i) }
        
        sStripeDensity.initSingle(&control.stripeDensity, -10,10,2, "Stripe")
        sEscapeRadius.initSingle(&control.escapeRadius, 0.01,80,3, "Escape")
        sMultiplier.initSingle(&control.multiplier, -1,1,0.1, "Multiplier")
        sR.initSingle(&control.R, 0,1,0.15, "Color R")
        sG.initSingle(&control.G, 0,1,0.15, "Color G")
        sB.initSingle(&control.B, 0,1,0.15, "Color B")
        sContrast.initSingle(&control.contrast, 0.1,5,0.5, "Contrast")
        
        sHeight.initSingle(&control.height,-40,40,4, "Height")
        sHeight.highlight(0)

        gDevice = MTLCreateSystemDefaultDevice()
        
        initRenderViews()
        view3D.initialize()
        
        d3ViewL.device = gDevice
        d3ViewR.device = gDevice

        guard let newRenderer = Renderer(metalKitView: d3ViewL, 0) else { fatalError("Renderer cannot be initialized") }
        rendererL = newRenderer
        rendererL.mtkView(d3ViewL, drawableSizeWillChange: d3ViewL.drawableSize)
        d3ViewL.delegate = rendererL
        
        guard let newRenderer2 = Renderer(metalKitView: d3ViewR, 1) else { fatalError("Renderer cannot be initialized") }
        rendererR = newRenderer2
        rendererR.mtkView(d3ViewR, drawableSizeWillChange: d3ViewR.drawableSize)
        d3ViewR.delegate = rendererR

        do {
            let defaultLibrary:MTLLibrary! = self.device.makeDefaultLibrary()
            guard let kf1 = defaultLibrary.makeFunction(name: "fractalShader")  else { fatalError() }
            pipeline1 = try device.makeComputePipelineState(function: kf1)
            
            guard let kf2 = defaultLibrary.makeFunction(name: "shadowShader")  else { fatalError() }
            pipeline2 = try device.makeComputePipelineState(function: kf2)
            
            guard let kf3 = defaultLibrary.makeFunction(name: "heightMapShader")  else { fatalError() }
            pipeline3 = try device.makeComputePipelineState(function: kf3)
        }
        catch { fatalError("error creating pipelines") }
        
        controlBuffer = device.makeBuffer(bytes: &control, length: MemoryLayout<Control>.stride, options: MTLResourceOptions.storageModeShared)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.rotated), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        Timer.scheduledTimer(withTimeInterval:0.05, repeats:true) { timer in self.timerHandler() }
        randomize()
        
        if remoteLaunchOptionsLoad() { Timer.scheduledTimer(withTimeInterval:1, repeats:false) { timer in self.timerKick() }}
    }
    
    func initRenderViews() {
        if !is3D {
            d2View.isHidden = false
            d3ViewL.isHidden = true
            d3ViewR.isHidden = true
            d2View.frame = self.view.bounds
            
            sHeight.isHidden = true
            isStereoButton.isHidden = true
        }
        else {
            d2View.isHidden = true
            d3ViewL.isHidden = false
            sHeight.isHidden = false
            isStereoButton.isHidden = false

            var vr = self.view.bounds
            d3ViewL.frame = vr

            if isStereo {
                vr.size.width /= 2 
                d3ViewL.frame = vr

                d3ViewR.isHidden = false
                vr.origin.x += vr.width
                d3ViewR.frame = vr
            }
            else {
                d3ViewR.isHidden = true
            }
            
            let hk = d3ViewL.bounds
            arcBall.initialize(Float(hk.size.width),Float(hk.size.height))            
        }
        
        view.bringSubview(toFront: widgetBackground)
    }
    
    //MARK: -

    @objc func timerKick() { loadedData() }
    
    //MARK: -
    /*
     sending and receiving data via email
     1. launchOptions captured in AppDelegate didFinishLaunchingWithOptions()
     2. these routines just below to handle Loading data from launchOptions, and using docController to send the data
     3. edit project settings:  Target <Info> section, note the items added to "Document Types", "Imported UTIs" and "Exported UTIs"

     how to send:
     1.use the program as usual to display an image you like
     2.press "E" to launch airDrop popup.  Select 'Mail' icon.  Send email..
     
     how to receive:
     1. Launch the iPads built in Mail app.
     2. select the email with MishMash attachment.
     3. Tap attachment, then "Copy to MishMash" icon
     4. TODO:  image is loaded okay, but sometimes the app needs to be touched for force correct redraw.
    */
    
    // https://stackoverflow.com/questions/29399341/uidocumentinteractioncontroller-swift
    var fileURL:URL! = nil
    var docController:UIDocumentInteractionController!

    func sendEmail() {
        var fileURL:URL! = nil
        let name = "MishMash.msh"
        fileURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(name)

        do {
            control.version = Int32(versionNumber)
            let sz = MemoryLayout<Control>.size
            let data = NSData(bytes:&control, length: sz)
            try data.write(to: fileURL, options: .atomic)
        } catch { print(error); return }

        docController = UIDocumentInteractionController(url: fileURL)
        _ = docController.presentOptionsMenu(from: emailButton.frame, in:emailButton, animated:true) // !!  this must be a button
    }
    
    func remoteLaunchOptionsLoad() -> Bool {
        if remoteLaunchOptions == nil { return false }
        
        let hk:URL = remoteLaunchOptions[UIApplicationLaunchOptionsKey.url] as! URL
        let sz = MemoryLayout<Control>.size
        let data = NSData(contentsOf:hk)
        data?.getBytes(&control, length:sz)
        
        return true
    }
    
    //MARK: -

    @objc func timerHandler() {
        if isBusy { return }
        
        var refresh:Bool = false
        for i in wList { if i.update() { refresh = true }}
        if cMove.update() { refresh = true }
        if cZoom.update() { refresh = true }
        
        if autoMoveFlag {
            controlAutoMove();
            for i in wList { i.setNeedsDisplay() }
            refresh = true
        }
        
        if refresh { updateImage() }
        
        if is3D {
            rotate(paceRotate.x,paceRotate.y)
        }
    }
    
    //MARK: -
    
    func refresh() {
        updateWidgets()
        updateImage()
    }
    
    func loadedData() {
        updateGrammarString()
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
        
        d2View.frame = view.bounds
        let bkxs:CGFloat = 610
        let bkys:CGFloat = 270
        widgetBackground.frame = CGRect(x:(vxs-bkxs)/2, y:vys-bkys-20, width:bkxs, height:bkys)
        
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
        sMultiplier.frame = frame(cxs,bys,cxs+5,0)
        autoButton.frame = frame(cxs/2-3,bys,cxs/2,0)
        emailButton.frame = frame(cxs/2,bys,0,0)

        x = 10 + gxs
        y += gap
        let t2List = [ sEscapeRadius,sStripeDensity,sContrast,shadowButton ] as [UIView]
        for t in t2List { t.frame = frame(cxs,bys,0,gap) }
        cMove.frame = frame(70,60,75,0)
        cZoom.frame = frame(70,60,0,0)
        
        x = gxs + cxs + 15
        y = gap + 5
        let t3List = [ sR,sG,sB,loadNextButton ] as [UIView]
        for t in t3List { t.frame = frame(cxs,bys,0,gap) }

        x += cxs + 5
        y = 5
        let t4List = [ randomButton,saveLoadButton,is3DButton,sHeight,isStereoButton] as [UIView]
        for t in t4List { t.frame = frame(cxs,bys,0,gap) }

        x += 35
        y += 12
        helpButton.frame = frame(bys,bys,0,0)
        
        setImageViewResolutionAndThreadGroups()
        initRenderViews()
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
        
        d2View.initialize(texture1)
        
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
    
    //MARK: -
    
    func alterZoomCommon(_ dz:Float) {
        let xsize = (control.xmax - control.xmin) * dz
        let ysize = (control.ymax - control.ymin) * dz
        let xc = (control.xmin + control.xmax) / 2
        let yc = (control.ymin + control.ymax) / 2
        
        control.xmin = xc - xsize;  control.xmax = xc + xsize
        control.ymin = yc - ysize;  control.ymax = yc + ysize
        
        updateImage()
    }
    
    func alterZoom(_ dz:Float) {
        alterZoomCommon(0.5 + dz / 50)
    }
    
    var pace:Int = 0
    
    func alterZoomViaPinch(_ dz:Float) {  // 0.1 ... 6.0
        pace += 1; if pace < 5 { return }
        pace = 0
        
        let amt:Float = 1 - (dz - 1.0) * 0.1
        alterZoomCommon(amt / 2)
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
            
            if !is3D {
                d2View.display(d2View.layer)
                isBusy = false
            }
            else {
                update3DRendition()
            }
        }
    }
    
    func update3DRendition() {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        commandEncoder.setComputePipelineState(pipeline3)
        commandEncoder.setTexture(shadowFlag ? texture2 : texture1, index: 0)
        commandEncoder.setBuffer(vBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(controlBuffer, offset: 0, index: 1)
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        isBusy = false
    }

    //MARK:-
    
    var oldPt = CGPoint()
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) { // alter focused widget values
        var pt = sender.translation(in: self.view)
        
        switch sender.state {
        case .began :
            oldPt = pt
        case .changed :
            pt.x -= oldPt.x
            pt.y -= oldPt.y
            vc.focusMovement(pt)
        default :
            pt.x = 0
            pt.y = 0
            vc.focusMovement(pt)
        }
    }

    //MARK:-

    var paceRotate = CGPoint()
    
    func rotate(_ x:CGFloat, _ y:CGFloat) {
        let center = CGFloat(control.xSize / 2)
        arcBall.mouseDown(CGPoint(x: center, y: center))
        arcBall.mouseMove(CGPoint(x: center - x, y: center - y))
    }
    
    @IBAction func pan2Gesture(_ sender: UIPanGestureRecognizer) { // rotate 3D image
        let pt = sender.translation(in: self.view)
        let scale:CGFloat = 0.05
        paceRotate.x = pt.x * scale
        paceRotate.y = pt.y * scale
    }

    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        let min:Float = 1       // close
        let max:Float = 1000    // far
        
        translation.z *= Float(1 + (1 - sender.scale) / 10 )
        if translation.z < min { translation.z = min }
        if translation.z > max { translation.z = max }
    }
    
    //MARK:-

    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        paceRotate.x = 0
        paceRotate.y = 0
    }

    @IBAction func tap2Gesture(_ sender: UITapGestureRecognizer) {
        widgetBackground.isHidden = !widgetBackground.isHidden
    }

}
