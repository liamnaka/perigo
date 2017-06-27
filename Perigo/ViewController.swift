//
//  ViewController.swift
//  Perigo
//
//  Created by Liam on 1/6/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import UIKit
import AudioToolbox
import Photos
import Metal
import MetalKit
import MetalPerformanceShaders


class ViewController: UIViewController, AVCapturePhotoCaptureDelegate,AVSpeechSynthesizerDelegate {
    
    //If true, Perigo captions the image. Otherwise object detection.
    var natural = true

    var sight = vision()
    var captureSession : AVCaptureSession!
    var sessionOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var previewView = UIView()
    var blurView = UIVisualEffectView()
    var picker : ImageGalleryView!
    var header = UIView()
    
    // some properties used to control the app and store appropriate values
    var Net: Inception3Net? = nil //ImageNet
    var Coco: CocoHelper? = nil
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var textureLoader : MTKTextureLoader!
    var ciContext : CIContext!

    
    static var sharedInstance : ViewController?
    
    //Flag for controlling neural net input
    var open = false
    
    let caption = UIDescription()//UILabel()
    
    let voice = AVSpeechSynthesizer()
    var voiceStyle : AVSpeechSynthesisVoice!
    let audio = AVAudioSession.sharedInstance()
    let audioSettings : AVAudioSessionCategoryOptions  = [ .mixWithOthers,
                                                    .duckOthers,
                                                    .interruptSpokenAudioAndMixWithOthers]
    let audioCategory = AVAudioSessionCategoryPlayback
    /*override func loadView() {
        
        super.loadView()
        //startNet()
    }*/
    
    //Convenience for going through gallery
    var lastDate : Date? = nil
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        
        //Model loading should be called in AppDelegate, not viewDidLoad
        //startNet()
        
        super.viewDidLoad()
        
        ViewController.sharedInstance = self
        
        startNet()
        //startImageNet()
        startCam()
        startCaption()
        startPicker()
        startHeader()
        
        startVoice()
        print("Hello :)")
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.takePicture))
        previewView.addGestureRecognizer(tap)
        
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(self.switchNet))
            
        swipe.direction = UISwipeGestureRecognizerDirection.down
        
        self.view.addGestureRecognizer(swipe)
        
        previewView.isAccessibilityElement = true
        previewView.accessibilityLabel = "Tap once to Describe. Scroll through photos below."
        previewView.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        //previewView.accessib
        
        self.view.backgroundColor = UIColor.black
        
        self.view.makeCorner(withRadius: 8)
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Capture a photo and generate a caption
    func takePicture(){
        
        //print("Tapped")
        
        if open { open = false
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.blurView.effect = UIBlurEffect(style: UIBlurEffectStyle.light)
                }, completion: { (value: Bool) in
                    UIView.animate(withDuration: 0.2, animations: {
                        self.blurView.effect = nil
                    })
                })
                
            }
            
            if #available(iOS 10,*) {
                let feedbackGenerator = UISelectionFeedbackGenerator()
                feedbackGenerator.selectionChanged()
            }
            
            //let pop: SystemSoundID = 1104
            //AudioServicesPlaySystemSound (pop)
            
            //print("Making Caption")
            NSLog("%@", "Tap Received")
            
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .auto
            settings.isAutoStillImageStabilizationEnabled = true
            settings.isHighResolutionPhotoEnabled = true
            let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
            let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                                 kCVPixelBufferWidthKey as String: 160,
                                 kCVPixelBufferHeightKey as String: 160,
                                 ]
            settings.previewPhotoFormat = previewFormat
            sessionOutput.capturePhoto(with: settings, delegate: self)
            
        }
    }
    
    //AVKit delegate method for photo capture
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        
      
        if let error = error {
            print(error.localizedDescription)
        }
        
        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer, let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer, previewPhotoSampleBuffer: previewBuffer) {
            
            
            
            if let image = UIImage(data: dataImage){
                NSLog("%@", "Took Picture")
                if natural { scan(image: image) }
                else { }//scanCoco(image: image) }//scanImageNet(image: image) }
            }
            else {
                NSLog("%@", "Failed to scan image")
                open = true
            }
            
            
            
        }
        
    }
    
    
    func scan(image: UIImage){ //Possible unwrap issues or nil in optional error source
        
        
        
        //Generate caption from image
        autoreleasepool{
            let description = self.sight.beam_search(image) ?? "Did not run properly"
        
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
        self.caption.text = description
       // self.caption.pushTransition(0.2)
        //Update caption text
        
        //self.caption.text = description
        
        //Speak the new caption
        speak(words: description)
        NSLog("%@", description)
        //print(cap ?? "Did not run properly")
        //reloadCaption(newText: description)
        open = true //Reset the scan flag
        }

    }
    
    func picker_scan(){
        
        if open {
            
            open = false
            
            if let asset = picker.getPicture() {
                
                let date = asset.creationDate ?? Date.distantPast

                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = false
                options.version = .original
                 
                let manager = PHImageManager.default()

                 
                manager.requestImageData(for: asset, options: options, resultHandler:
                { data, _, _, _ in
                 
                if let data = data {
                    let pic = UIImage(data: data)!
                    self.describeWithTime(image: pic, date: date)
                }
                
                })
                
            }
        }
    }
    
    func describeWithTime(image: UIImage,date: Date)
    {
        //Generate caption from image
        autoreleasepool{
        var description = self.sight.beam_search(image) ?? "Did not run properly"
        
        
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
        self.caption.text = description
        //self.caption.pushTransition(0.2)
        //self.caption.text = description
        
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        
        //reloadCaption(newText: description)
        
        if Calendar.current.isDate(date, inSameDayAs:Date()){
            description += "\n\nFrom today."
        }
        else {
            let timeStamp = "From " + formatter.string(from: date)
            
            if !Calendar.current.isDate(date, inSameDayAs:lastDate ?? Date.distantFuture) {
                
                description += "\n\n" + timeStamp
                
                let calendar = Calendar.autoupdatingCurrent
                let now = calendar.dateComponents([.year], from: Date())
                let currentYear = now.year
                let then = calendar.dateComponents([.year], from: date)
                let photoYear = then.year
                
                if currentYear == photoYear {
                    let index = description.index(description.endIndex, offsetBy: -6)
                    description = description.substring(to: index)
                }
            }
            else {
                description += "\n\nFrom the same day."
            }
        }
        
        lastDate = date
        print(image)
        //Update caption text
        
        
        //Speak the new caption
        speak(words: description)
        NSLog("%@", description)
        //print(cap ?? "Did not run properly")
        open = true //Reset the scan flag
        
        }
    }
    
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        do   { try audio.setActive(false) }
        catch{}
    }
    
    func speak(words:String) {
        voice.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: words)
        utterance.voice = voiceStyle
        voice.speak(utterance)
    }
    
    
    //Test-run model to avoid long initial scanning time
    func warmup(){
        open = false
        let blank = UIImage(color: UIColor.black, size: CGSize(width: 299,height: 299))
        self.sight.beam_search(blank)
        open = true
    }

    
    func startCam(){
        let AVStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        if  AVStatus ==  AVAuthorizationStatus.notDetermined
        {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                if granted == true
                {
                    print("Accepted Camera Permission")
                }
                else
                {
                    print("Rejected Camera Permission")
                    self.previewView.accessibilityLabel = "No Camera Permission"
                    self.caption.text = "No Camera Permission"
                    self.previewView.isUserInteractionEnabled = false
                }
            });
        }
        else if AVStatus == AVAuthorizationStatus.denied || AVStatus == AVAuthorizationStatus.restricted {
           
                print("Rejected Camera Permission")
                self.previewView.accessibilityLabel = "No Camera Permission"
                self.caption.text = "No Camera Permission \n"
                self.previewView.isUserInteractionEnabled = false
            
        }
        
        
        
        let width = UIScreen.main.bounds.width
        previewView.frame = CGRect(x: 0, y: 0, width: width, height: (4/3)*width)
    
    
     

        
        
        self.view.addSubview(previewView)
     
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        sessionOutput = AVCapturePhotoOutput()
        sessionOutput.isHighResolutionCaptureEnabled = true
        
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                if (captureSession.canAddOutput(sessionOutput)) {
                    print("Loading Preview Layer")
                    captureSession.addOutput(sessionOutput)
                    //captureSession.startRunning()
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    //previewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
                    previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                    previewLayer.frame = previewView.bounds
                    
                    
                    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                    previewView.layer.addSublayer(previewLayer)
                    
                }
            }
        }
        catch{
            print("exception!");
        }
        
        
        
        captureSession.startRunning()
        
        previewView.makeCorner(withRadius: 8)
        blurView.frame = previewView.frame
        blurView.effect = nil
        previewView.addSubview(blurView)
      
    }
    
    
    func startCaption(){
        
        caption.text = "Tap to Describe"
        caption.textColor = UIColor.white
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
        caption.textAlignment = NSTextAlignment.center

        
        //let width = UIScreen.main.bounds.width - 16
        //let height = CGFloat(UIScreen.main.bounds.height/2)
        caption.frame = CGRect(x: 8, y: 64, width: previewView.frame.width - 16, height: previewView.frame.height - 64)
        
        //CGRect(x: 8, y: UIScreen.main.bounds.width*(2/3)-(height/2), width: width, height: height)
        caption.numberOfLines = 0
        
        //Drop shadow
        caption.layer.shadowColor = UIColor.black.cgColor
        caption.layer.shadowOpacity = 1
        caption.layer.shadowOffset = CGSize.zero
        caption.layer.shadowRadius = 20
        caption.layer.shouldRasterize = true
        
        caption.isAccessibilityElement = false
        
        self.view.addSubview(caption)
    }
    
    func startPicker(){
        
        
        
        if (PHPhotoLibrary.authorizationStatus() != .authorized){
            PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                switch status{
                case .authorized:
                    print("Authorized")
                    break
                case .denied:
                    print("Denied")
                    break
                default:
                    print("Default")
                    break
                }
            })
        }
        
        let top = previewView.frame.maxY + 2
        let height = UIScreen.main.bounds.height - top
        let frame = CGRect(x: 0, y: top, width: UIScreen.main.bounds.width, height: height)
        
        picker = ImageGalleryView(frame: frame)
        //picker.delegate = self
        //picker.configuration = Configuration()
        //picker.selectedStack = ImageStack()
        picker.collectionView.layer.anchorPoint = CGPoint(x: 0, y: 0)
        picker.imageLimit = 1
        picker.updateFrames()
        picker.makeCorner(withRadius: 8)
        //picker.isAccessibilityElement = true
        
        //picker.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.picker_scan))
        picker.addGestureRecognizer(tap)
        picker.isAccessibilityElement = true
        picker.accessibilityLabel = "Scroll through your photo library here"
        picker.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        
        view.addSubview(picker)
        
        //Dark Gradient to give status & header contrast
        let gradLayer = CAGradientLayer()
        let gradw = UIScreen.main.bounds.width
        let gradh = picker.frame.height
        let dark = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7).cgColor
        gradLayer.frame = CGRect(x: 0, y: 0, width: gradw, height: gradh)
        gradLayer.colors = [dark, UIColor.clear.cgColor, UIColor.clear.cgColor, dark]
        //gradLayer.startPoint = CGPoint(x: 0, y: 0)
        //gradLayer.endPoint = CGPoint(x: 0, y: UIApplication.shared.statusBarFrame.height + 44)
        gradLayer.startPoint = CGPoint(x: -0.01, y: 0.5)
        gradLayer.endPoint = CGPoint(x: 1.01, y: 0.5)
        
        let firstLoc = (gradw-gradh)/(2*gradw) as NSNumber
        let secondLoc = (1 - (gradw-gradh)/(2*gradw)) as NSNumber
        
        gradLayer.locations = [0.0,firstLoc,secondLoc,1.0]
        self.picker.layer.addSublayer(gradLayer)

    }
    
    func startHeader() {
        let headerHeight: CGFloat = 44
        header.frame = CGRect(x: 0,y: UIApplication.shared.statusBarFrame.height,width: UIScreen.main.bounds.width,height: headerHeight)
        header.isAccessibilityElement = false
        
        
        
        let title = UILabel()
        title.text = "Perigo Sight"
        title.adjustsFontSizeToFitWidth = true
        title.textColor = UIColor.white
        title.font = UIFont(name: "AvenirNext-Regular", size: 30.0)
        title.textAlignment = NSTextAlignment.center
        title.frame = CGRect(x: UIScreen.main.bounds.width/4, y: header.bounds.minY, width: UIScreen.main.bounds.width/2, height: header.bounds.height) //header.bounds//CGRect(x: 8, y: 8, width: UIScreen.main.bounds.width/2, height: 42)
        title.numberOfLines = 1
        //Drop shadow
        title.layer.shadowColor = UIColor.black.cgColor
        title.layer.shadowOpacity = 1
        title.layer.shadowOffset = CGSize.zero
        title.layer.shadowRadius = 20
        title.layer.shouldRasterize = true
        title.isAccessibilityElement = false
        title.clipsToBounds = false
        title.baselineAdjustment = .alignCenters
        
        //Dark Gradient to give status & header contrast
        let gradLayer = CAGradientLayer()
        let topColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor
        gradLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIApplication.shared.statusBarFrame.height + 44)
        gradLayer.colors = [topColor, UIColor.clear.cgColor]
        //gradLayer.startPoint = CGPoint(x: 0, y: 0)
        //gradLayer.endPoint = CGPoint(x: 0, y: UIApplication.shared.statusBarFrame.height + 44)
        
        gradLayer.locations = [0.0,1.0]
        self.previewView.layer.addSublayer(gradLayer)
        
        
        
        
     
        
        self.previewView.addSubview(header)
        self.header.addSubview(title)
        
    }
    
    func reloadPicker(){
        picker.fetchPhotos()
    }
    
    func reloadCaption(newText: String?){
        //if let cap = self.caption {
            //self.caption.pushTransition(0.2, text: desc)
        //self.caption.text = desc
        //}
        
    }
    
    func startVoice(){
        do {
            try audio.setCategory(audioCategory, with: audioSettings)
        }
        catch let error as NSError {
            print("Audio Setup Error: \(error)")
        }
        
        voiceStyle = AVSpeechSynthesisVoice(language: "en-US")
        if voiceStyle.quality == AVSpeechSynthesisVoiceQuality.enhanced {
            print("Yay! Enhanced voice quality")
        }
        
        voice.delegate = self
        
    }
    
    
    func startNet(){
        sight.load_model()
        Coco = CocoHelper()
        open = true
        //warmup()
    }
    
    func startImageNet(){
        // Load default device.
        device = MTLCreateSystemDefaultDevice()
        
        // Make sure the current device supports MetalPerformanceShaders.
        guard MPSSupportsMTLDevice(device) else {
            print("Metal Performance Shaders not Supported on current Device")
            return
        }
        
        // Load any resources required for rendering.
        
        // Create new command queue.
        commandQueue = device!.makeCommandQueue()
        
        // make a textureLoader to get our input images as MTLTextures
        textureLoader = MTKTextureLoader(device: device!)
        
        // Load the appropriate Network
        Net = Inception3Net(withCommandQueue: commandQueue)
        
        // we use this CIContext as one of the steps to get a MTLTexture
        ciContext = CIContext.init(mtlDevice: device)
        
       
    }
    
 
    func scanImageNet(image: UIImage){
        
        open = false
        
        var texture : MTLTexture? = nil
        
        do {
            texture = try textureLoader.newTexture(with: image.cgImage!, options: [:])
        }
        catch let error as NSError {
            fatalError("Unexpected error ocurred: \(error.localizedDescription).")
        }
        
        // to deliver optimal performance we leave some resources used in MPSCNN to be released at next call of autoreleasepool,
        // so the user can decide the appropriate time to release this
        autoreleasepool{
            // encoding command buffer
            let commandBuffer = commandQueue.makeCommandBuffer()
            
            // encode all layers of network on present commandBuffer, pass in the input image MTLTexture
            Net!.forward(commandBuffer: commandBuffer, sourceTexture: texture)
            
            // commit the commandBuffer and wait for completion on CPU
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            // display top-5 predictions for what the object should be labelled
            let description = Net!.getLabel()
            
            caption.font = UIFont(name: "AvenirNext-DemiBold", size: 25.0)
            self.caption.text = description
     
            speak(words: description)
            NSLog("%@", description)

            open = true //Reset the scan flag
            
            
           
        }
        
    }
    
    //TODO - COCO not yet implemented due to TF Missing op "equals", possibly more as of 6/25
    func scanCoco(image: UIImage){
       
            //Generate caption from image
            autoreleasepool{
                //let description = self.sight.beam_search(image) ?? "Did not run properly"
                
                let results = self.sight.coco_search(image)!;
                
                let description = Coco!.getLabel(ID: (results[2] as! NSArray)[0] as! NSNumber)
                
                caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
                self.caption.text = description
                // self.caption.pushTransition(0.2)
                //Update caption text
                
                //self.caption.text = description
                
                //Speak the new caption
                speak(words: description)
                NSLog("%@", description)
                //print(cap ?? "Did not run properly")
                //reloadCaption(newText: description)
                open = true //Reset the scan flag
            }

    
    }
    
    func switchNet(){
        //Switch from captioning to object detection and vice versa
        natural = natural ? false : true
        
        
        print("Switched!")
    }
    
    func delay(delay: Double, closure: (Void) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Void()
        }
    }
    

    
}

public extension UIImage {
    //Helper method for generating warmup image
    public convenience init?(color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) {
        let rect = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        color.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        guard let cgImage = image?.cgImage else { return nil }
        self.init(cgImage: cgImage)
    }
}

@IBDesignable
class UIDescription: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func drawText(in rect: CGRect) {
        let height = self.sizeThatFits(rect.size).height
        let y = rect.origin.y + rect.height - height - 16
        super.drawText(in: CGRect(x: rect.origin.x, y: y, width: rect.width, height: height))
    }
}

extension UILabel {
    func pushTransition(_ duration:CFTimeInterval) {
        let animation:CATransition = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
            kCAMediaTimingFunctionEaseInEaseOut)
        animation.type = kCATransitionPush
        animation.subtype = kCATransitionFromRight
        animation.duration = duration
        layer.add(animation, forKey: kCATransitionPush)
    }
}

extension UIView {
    func makeCorner(withRadius radius: CGFloat) {
        self.layer.cornerRadius = radius
        self.layer.masksToBounds = true
        self.layer.isOpaque = false
    }
}




