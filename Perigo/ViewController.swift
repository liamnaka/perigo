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
import CoreImage


class ViewController: UIViewController, AVCapturePhotoCaptureDelegate,AVSpeechSynthesizerDelegate {
    
    //Flag for type of image inference, default is im2txt (experimental var)
    var natural = true
    var sight = vision() //Wrapper class for image captioning via im2txt
    
    var captureSession : AVCaptureSession!
    var sessionOutput : AVCapturePhotoOutput!
    var position : AVCaptureDevicePosition = .unspecified
    //let settings = AVCapturePhotoSettings()
    var previewLayer : AVCaptureVideoPreviewLayer!
    var previewView = UIView()
    private let sessionQueue = DispatchQueue(label: "session queue",
                                             attributes: [],
                                             target: nil)
    var blurView = UIVisualEffectView()
    var gallery : ImageGalleryView!
    var header = UIView()
    let geocoder = CLGeocoder()
    
    let libPointer = CAShapeLayer()
    let camPointer = CAShapeLayer()
    
    //Experimental vars for Inception, Coco, Facenet
    //var Net: Inception3Net? = nil //ImageNet
    //var Coco: CocoHelper? = nil
    //var device: MTLDevice!
    //var commandQueue: MTLCommandQueue!
    //var textureLoader : MTKTextureLoader!
    //var ciContext : CIContext!

    static var sharedInstance : ViewController?
    
    var open = false //Flag for neural net input
    
    let caption = UIDescription()//UILabel()
    let contrastView = UIView()
    
    //Audio and Speech Synthesis
    let voice = AVSpeechSynthesizer()
    var voiceStyle : AVSpeechSynthesisVoice!
    let audio = AVAudioSession.sharedInstance()
    let audioSettings : AVAudioSessionCategoryOptions  = [ .mixWithOthers,
                                                    .duckOthers,
                                                    .interruptSpokenAudioAndMixWithOthers]
    let audioCategory = AVAudioSessionCategoryPlayback
    
    //Date and Location context for gallery
    var lastDate : Date? = nil
    var lastLoc : String = ""
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ViewController.sharedInstance = self
        
        startNet()
        startPreview()
        startCam()
        //DispatchQueue.main.async { self.startCam() }
        startCaption()
        startGallery()
        //startHeader()
        startVoice()
        print("Hello :)")

        //Removed until more neural networks are added
        /*
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(self.switchNet))
        swipe.direction = UISwipeGestureRecognizerDirection.down
        self.view.addGestureRecognizer(swipe)*/
        
        previewView.isAccessibilityElement = true
        previewView.accessibilityLabel = "Tap once to Describe. Scroll through photos below."
        previewView.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        gallery.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        //redundant I guess, but this is an issue that must be avoided.
        
        self.view.backgroundColor = UIColor.black
        self.view.makeCorner(withRadius: 6)
    }

    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    //Capture a photo and generate a caption
    func takePicture(){
        if open { open = false
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.2, animations: { //Capture animation
                    self.blurView.effect = UIBlurEffect(style: UIBlurEffectStyle.light)
                }, completion: { (value: Bool) in
                    UIView.animate(withDuration: 0.2, animations: {
                        self.blurView.effect = nil
                    })
                })
            }
            
            if #available(iOS 10,*) { //On iPhone 7 +, use haptic feedback
                let feedbackGenerator = UISelectionFeedbackGenerator()
                feedbackGenerator.selectionChanged()
            }
            
            //Reinitialize asset context
            lastDate = nil
            lastLoc = ""
    
            NSLog("%@", "Tap Received")
            
            
            sessionOutput.capturePhoto(with: getSettings(), delegate: self)
        }
    }
    
    
    
    //AVKit delegate method for photo capture
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        }
        if let sampleBuffer = photoSampleBuffer, let previewBuffer = previewPhotoSampleBuffer,
           let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer,
                                                                            previewPhotoSampleBuffer: previewBuffer) {
            if let image = UIImage(data: dataImage){
                NSLog("%@", "Took Picture")
                if natural { scan(image: image) } //Switch for different modes of inference
                else { }            }
            else {
                NSLog("%@", "Failed to scan image")
                open = true
            }
        }
    }
    
    
    
    func capture(_ captureOutput: AVCapturePhotoOutput, willBeginCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.isFlashEnabled {
            speak(words: "camera flash on")
        }
    }
    
    
    
    func beam_search(image: UIImage) -> String {
        let description = self.sight.beam_search(image) ?? "Did not run properly"
        return description
    }
    
    
    
    func scan(image: UIImage){
        let description = beam_search(image: image)//Generate caption from image
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
        self.changeCaption(text: description)
        self.setPointers(cam: true, library: false) //Configure the pointer
        speak(words: description) //Speak the new caption
        NSLog("%@", description)
        open = true //Reset the scan flag
    }
    
    
    
    func timeout(){
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }
    }
    
    
    
    func libraryScan(){ //Method retrieves asset and processes location data
        if open {
            open = false //Set scan flag to closed
            if let asset = gallery.getPicture() {
                let date = asset.creationDate ?? Date.distantPast
                let location = asset.location
                var locstring = ""
                
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = false
                options.version = .original
                let manager = PHImageManager.default()
                let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(self.timeout), userInfo: nil, repeats: false)
                 
                manager.requestImageData(for: asset, options: options, resultHandler: //Start photo asset request
                { data, _, _, _ in
                    
                    if let location = location { //location recieved
                        self.geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in //Geocoder req
                            
                            print(location)
                            if error != nil { //Called when geocoder times out or encounters error
                                if let data = data {
                                    self.geocoder.cancelGeocode()
                                    let pic = UIImage(data: data)!
                                    self.describeAsset(image: pic, date: date, location: locstring)
                                }
                            }
                            else { //Geocoder recieved placemarks
                                if let placemarks = placemarks { //Safe unwrap
                                    if placemarks.count > 0 { //Describes location with greatest possile specificity
                                        let pm = placemarks[0]
                                        if let locality = pm.locality {
                                            if let subloc = pm.subLocality {
                                                if let address = pm.thoroughfare {
                                                    locstring = ", in " + address + ", " + subloc
                                                }
                                                else{
                                                    locstring = ", in " + subloc + " " + locality
                                                }
                                            }
                                            else{
                                                locstring = ", in " + locality
                                            }
                                        }
                                        else if let admin = pm.administrativeArea {
                                            locstring = ", in " + admin
                                        }
                                        else if let country = pm.country {
                                            locstring = ", in " + country
                                        }
                                    }
                                }
                                if let data = data {
                                    let pic = UIImage(data: data)!
                                    self.describeAsset(image: pic, date: date, location: locstring)
                                }
                            }
                            
                        }) //End geocoder
                    }
                    else { //No location received
                        if let data = data {
                            let pic = UIImage(data: data)!
                            self.describeAsset(image: pic, date: date, location: locstring)
                        }
                    }
                    
                }) //End retrieve asset
                
                //Add timer to prevent overly extended geocoder calls
                RunLoop.current.add(timer, forMode: RunLoopMode.defaultRunLoopMode)
                //Play Pop
                AudioServicesPlaySystemSound(1057)
            }
        }
    }
    
    
    
    //Generating captions for photo library assets
    func describeAsset(image: UIImage,date: Date,location: String)
    {
        let description = beam_search(image: image)
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
        self.changeCaption(text: description) //Update caption text
        self.setPointers(cam: false, library: true) //Configure pointer
        print(image)
        let dateSummary = "\n\n" + getDateSummary(date: date)
        
        //Set location context
        var loc : String = ""
        if location == lastLoc && location != "" {
            loc = ", in the same place"
        }
        else{
            loc = location
            lastLoc = location
        }
        
        speak(words: description + dateSummary + loc) //Speak the new caption
        NSLog("%@", description + dateSummary + loc)
        open = true //Reset the scan flag
    }
    
    
    
    func getDateSummary(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        let calendar = Calendar.autoupdatingCurrent
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        let timeString = " at " + timeFormatter.string(from: date)
        
        if Calendar.current.isDate(date, inSameDayAs:Date()){
            return "From today" + timeString
        }
        else {
            let timeStamp = "From " + formatter.string(from: date)
            if !Calendar.current.isDate(date, inSameDayAs:lastDate ?? Date.distantFuture) {//Isolating components of date
                
                let now = calendar.dateComponents([.year], from: Date())
                let currentYear = now.year
                let then = calendar.dateComponents([.year], from: date)
                let photoYear = then.year
                lastDate = date//Set time context
                if currentYear == photoYear {
                    let index = timeStamp.index(timeStamp.endIndex, offsetBy: -6)
                    return timeStamp.substring(to: index) + timeString
                }
                else {
                    return timeStamp + timeString
                }
            }
            else {
                return "From the same day" + timeString
            }
        }
        
        
        
        
    }
    
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        do   { try audio.setActive(false) }
        catch{}
    }
    
    
    
    func speak(words:String) {
        if UIAccessibilityIsVoiceOverRunning(){
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, NSLocalizedString(words, comment: ""))
        }
        else{
            voice.stopSpeaking(at: .word)
            let utterance = AVSpeechUtterance(string: words)
            utterance.voice = voiceStyle
            voice.speak(utterance)
        }
    }

    
    
    //Test-run model to avoid long initial scanning time -- not currently in use
    func warmup(){
        open = false
        let blank = UIImage(color: UIColor.black, size: CGSize(width: 299,height: 299))
        self.sight.beam_search(blank)
        open = true
    }
    
    func startPreview(){
        //Intializing previewView, which contains the camera preview
        let width = UIScreen.main.bounds.width
        previewView.frame = CGRect(x: 0, y: 0, width: width, height: (4/3)*width)
        self.view.addSubview(previewView)
        
        
    }

    
    func startCam(){
        let AVStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        
        if  AVStatus ==  AVAuthorizationStatus.notDetermined {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                
                if granted == true
                {
                    print("Accepted Camera Permission")
                }
                else
                {
                    print("Rejected Camera Permission")
                    self.previewView.accessibilityLabel = "No Camera Permission"
                    //self.caption.text = "No Camera Permission"
                    self.changeCaption(text: "No Camera Permission")
                    self.previewView.isUserInteractionEnabled = false
                }
    
            });
        }
        else if AVStatus == AVAuthorizationStatus.denied || AVStatus == AVAuthorizationStatus.restricted {
            print("Rejected Camera Permission")
            self.previewView.accessibilityLabel = "No Camera Permission"
            self.changeCaption(text: "No Camera Permission \n")
            self.previewView.isUserInteractionEnabled = false
        }
        
   
        //Initialize AVCaptureSession and output
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        sessionOutput = AVCapturePhotoOutput()
        sessionOutput.isHighResolutionCaptureEnabled = true
        
        //Add input device and intialize previewLayer
        //let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        do {
            var defaultVideoDevice: AVCaptureDevice?
            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            if #available(iOS 10.2, *) {
                if let dualCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInDualCamera, mediaType: AVMediaTypeVideo, position: .back) {
                    defaultVideoDevice = dualCameraDevice
                    position = .back
                } else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    defaultVideoDevice = backCameraDevice
                    position = .back
                } else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                    /*
                     In some cases where users break their phones, the back wide angle camera is not available.
                     In this case, we should default to the front wide angle camera.
                     */
                    defaultVideoDevice = frontCameraDevice
                    position = .front
                }
            } else {
                if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                                                        mediaType: AVMediaTypeVideo, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    defaultVideoDevice = backCameraDevice
                    position = .back
                } else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                    /*
                     In some cases where users break their phones, the back wide angle camera is not available.
                     In this case, we should default to the front wide angle camera.
                     */
                    defaultVideoDevice = frontCameraDevice
                    position = .front
                }// Fallback on earlier versions
            }
            
            let input = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            //let input = try AVCaptureDeviceInput(device: device)
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                if (captureSession.canAddOutput(sessionOutput)) {
                    print("Loading Preview Layer")
                    captureSession.addOutput(sessionOutput)
                    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                    previewLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
                    previewLayer.frame = previewView.bounds
                    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                    previewView.layer.addSublayer(previewLayer)
                    
                    
                    //Begin capture session
                    captureSession.startRunning()
                    
                    //Add view for blur animation
                    blurView.frame = previewView.frame
                    blurView.effect = nil
                    previewView.addSubview(blurView)
                    
                    //Add header gradient
                    startHeader()
                    
                    //Add tap gesture to PreviewView
                    let tap = UITapGestureRecognizer(target: self, action: #selector(self.takePicture))
                    previewView.addGestureRecognizer(tap)
                }
            }
        }
        catch{
            print("exception!");
        }
        
       
    }
    
    func getSettings() -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        //Set capture seetings
        //let position = self.captureSession.input.device.position
        
        settings.flashMode = position == .front || position == .unspecified ? .off : .auto

        //settings.flashMode = .auto
        settings.isAutoStillImageStabilizationEnabled = true
        settings.isHighResolutionPhotoEnabled = true
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
                             kCVPixelBufferWidthKey as String: 160,
                             kCVPixelBufferHeightKey as String: 160,
                             ]
        settings.previewPhotoFormat = previewFormat
        return settings
    }
    
    
    func startCaption(){
        contrastView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        contrastView.isUserInteractionEnabled = false
        self.view.addSubview(contrastView)
        
        caption.text = "Tap to Describe"
        caption.textColor = UIColor.white
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
        caption.textAlignment = NSTextAlignment.center
        caption.frame = CGRect(x: 8, y: 64, width: previewView.frame.width - 16, height: previewView.frame.height - 64)
        caption.numberOfLines = 0
        
        //Drop shadow
        caption.layer.shadowColor = UIColor.black.cgColor
        caption.layer.shadowOpacity = 1.0
        caption.layer.shadowOffset = CGSize.zero
        caption.layer.shadowRadius = 40
        caption.layer.shouldRasterize = true
        
        caption.isAccessibilityElement = false
        
        
        self.view.addSubview(caption)
        updateCaptionContrast()
    }
    
    func startGallery(){
        
        let top = previewView.frame.maxY + 2
        let height = UIScreen.main.bounds.height - top
        let frame = CGRect(x: 0, y: top, width: UIScreen.main.bounds.width, height: height)
        
        gallery = ImageGalleryView(frame: frame)
        gallery.collectionView.layer.anchorPoint = CGPoint(x: 0, y: 0)
        gallery.imageLimit = 1
        gallery.updateFrames()
   
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.libraryScan))
        gallery.addGestureRecognizer(tap)
        gallery.isAccessibilityElement = true
        gallery.clipsToBounds = false
        gallery.accessibilityLabel = "Swipe left and right through your photo library here. If one finger scrolling doesn't work, try double tapping and then dragging your finger."
        gallery.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        //gallery.accessibilityNavigationStyle = .combined
        
        view.addSubview(gallery)
        
        /* Gradient layer in gallery -- Curently unused due to UI implications
        //let gradLayer = CAGradientLayer()
        let gradw = UIScreen.main.bounds.width
        let gradh = gallery.frame.height
        let dark = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7).cgColor
        gradLayer.frame = CGRect(x: 0, y: 0, width: gradw, height: gradh)
        gradLayer.colors = [dark, UIColor.clear.cgColor, UIColor.clear.cgColor, dark]
        gradLayer.startPoint = CGPoint(x: -0.01, y: 0.5)
        gradLayer.endPoint = CGPoint(x: 1.01, y: 0.5)
        
        let firstLoc = (gradw-gradh)/(2*gradw) as NSNumber
        let secondLoc = (1 - (gradw-gradh)/(2*gradw)) as NSNumber
        
        gradLayer.locations = [0.0,firstLoc,secondLoc,1.0]
        self.gallery.layer.addSublayer(gradLayer)
        */
        
        let trianglew = UIScreen.main.bounds.width/20
        let width  = UIScreen.main.bounds.width
        
        let botPath = CGMutablePath()
        botPath.move(to: CGPoint(x: (width-trianglew)/2, y: -1))
        botPath.addLine(to: CGPoint(x: width/2, y: sqrt(3.0)*trianglew/2))
        botPath.addLine(to: CGPoint(x: (width+trianglew)/2, y: 0))
        botPath.addLine(to: CGPoint(x: (width-trianglew)/2, y: 0))
        libPointer.path = botPath
        libPointer.fillColor = UIColor.black.cgColor
        libPointer.strokeColor = UIColor.black.cgColor
        libPointer.lineWidth = trianglew/4
        
        let topPath = CGMutablePath()
        topPath.move(to: CGPoint(x: (width-trianglew)/2, y: -1))
        topPath.addLine(to: CGPoint(x: width/2, y: -(sqrt(3.0)*trianglew/2)-2))
        topPath.addLine(to: CGPoint(x: (width+trianglew)/2, y: -2))
        topPath.addLine(to: CGPoint(x: (width-trianglew)/2, y: -2))
        camPointer.path = topPath
        camPointer.fillColor = UIColor.black.cgColor
        camPointer.strokeColor = UIColor.black.cgColor
        camPointer.lineWidth = trianglew/4
       
        self.gallery.layer.addSublayer(libPointer)
        self.gallery.layer.addSublayer(camPointer)
        
        if (PHPhotoLibrary.authorizationStatus() == .notDetermined){
            PHPhotoLibrary.requestAuthorization({(status:PHAuthorizationStatus) in
                switch status{
                case .authorized:
                    self.reloadgallery()
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
        
    }
    
    
    
    func setPointers(cam: Bool?, library: Bool?){ //Updating camera/gallery pointer/indicators
        let white = UIColor.white.cgColor
        let black = UIColor.black.cgColor
        
        if cam != nil && library != nil {
            camPointer.fillColor = cam! ? white : black
            libPointer.fillColor = library! ? white : black
        }
        else if let cam = cam {
            camPointer.fillColor = cam ? white : black
        }
        else if let library = library {
            libPointer.fillColor = library ? white : black
        }
    }
    
    
    
    func startHeader() {
        let headerHeight: CGFloat = 44
        header.frame = CGRect(x: 0,y: UIApplication.shared.statusBarFrame.height,width: UIScreen.main.bounds.width,height: headerHeight)
        header.isAccessibilityElement = false
        
        //Perigo Logo -- Currently unused
        let title = UILabel()
        /*
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
        */
        
        //Dark Gradient to give status & header contrast
        let gradLayer = CAGradientLayer()
        let topColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3).cgColor
        gradLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIApplication.shared.statusBarFrame.height + 44)
        gradLayer.colors = [topColor, UIColor.clear.cgColor]
        gradLayer.locations = [0.0,0.5]
        self.previewView.layer.addSublayer(gradLayer)
        
        self.previewView.addSubview(header)
    }
    
    
    
    func reloadgallery(){
        gallery.fetchPhotos()
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
        open = true
        //Coco = CocoHelper() //-- COCO not yet implemented due to lack of TF Ops
    }
    
    
    
    //UNUSED: Inception proving to be unuseful/inaccurate
    func startImageNet(){
        /*
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
        */
    }
    
    
    
    //UNUSED: Inception proving to be unuseful/inaccurate
    func scanImageNet(image: UIImage){
        /*
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
            //self.caption.text = description
            self.changeCaption(text: description)
            speak(words: description)
            NSLog("%@", description)
            open = true //Reset the scan flag
        }
        */
    }
    
    
    
    //TODO - COCO not yet implemented due to TF Missing op "equals", possibly more as of 6/25
    func scanCoco(image: UIImage){
        /*
        //Generate MSCOCO object segmentation from image
        autoreleasepool{
            let results = self.sight.coco_search(image)!;
            let description = Coco!.getLabel(ID: (results[2] as! NSArray)[0] as! NSNumber)
            caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
            self.changeCaption(text: description)
            
            //Speak the new caption
            speak(words: description)
            NSLog("%@", description)
            open = true //Reset the scan flag
        }
        */
    }
    
    
    
    func switchNet(){
        //Switch from captioning to object detection and vice versa -- Currently unused
        natural = natural ? false : true
        print("Switched!")
    }
    
    
    
    func delay(delay: Double, closure: (Void) -> Void) {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Void()
        }
    }
    
    
    
    func changeCaption(text: String){
        caption.text = text
        updateCaptionContrast()
    }
    
    
    
    func updateCaptionContrast(){ //Changes the frame of contrast view to match label frame
        let yMargin : CGFloat = 16
        //let xMargin : CGFloat = 8
        let rect = caption.frame
        
        let height = caption.sizeThatFits(rect.size).height
        let y = rect.origin.y + rect.height - height - yMargin
        
        contrastView.frame = CGRect(x: 0, y: y-yMargin, width: UIScreen.main.bounds.width, height: height+(2*yMargin))
    }
    
    
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.captureSession.isRunning {
                self.captureSession.stopRunning() //Ending captureSession
            }
        }
        super.viewWillDisappear(animated)
    }
    

    
} //End ViewController

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

    func pixelData() -> [UInt8]? { //Currently not used
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return pixelData
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
        let yMargin : CGFloat = 16 //Distance from text to bottom of label frame
        let height = self.sizeThatFits(rect.size).height
        let y = rect.origin.y + rect.height - height - yMargin
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


