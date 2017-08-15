//
//  initializations.swift
//  Perigo
//
//  Created by Liam on 8/14/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

//Xcode is pesky about dependencies
import UIKit
import Foundation
import Photos

extension ViewController {
    
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
                    //position = .back
                } else if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    defaultVideoDevice = backCameraDevice
                    //position = .back
                } else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                    /*
                     In some cases where users break their phones, the back wide angle camera is not available.
                     In this case, we should default to the front wide angle camera.
                     */
                    defaultVideoDevice = frontCameraDevice
                    //position = .front
                }
            } else {
                if let backCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera,
                                                                        mediaType: AVMediaTypeVideo, position: .back) {
                    // If the back dual camera is not available, default to the back wide angle camera.
                    defaultVideoDevice = backCameraDevice
                    //position = .back
                } else if let frontCameraDevice = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front) {
                    /*
                     In some cases where users break their phones, the back wide angle camera is not available.
                     In this case, we should default to the front wide angle camera.
                     */
                    defaultVideoDevice = frontCameraDevice
                    //position = .front
                }// Fallback on earlier versions
            }
            
            if let device = defaultVideoDevice {
                //Set torch value
                torch = device.hasFlash
                
                let input = try AVCaptureDeviceInput(device: device)
                
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
        }
        catch{
            print("exception!");
        }
        
        
    }
    
    func startCaption(){
        contrastView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        contrastView.isUserInteractionEnabled = false
        self.view.addSubview(contrastView)
        
        caption.text = "Tap to hear a description"
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
        
        if !UIAccessibilityIsVoiceOverRunning() {
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.libraryScan))
            gallery.addGestureRecognizer(tap)
        }
        gallery.isAccessibilityElement = false
        gallery.clipsToBounds = false
        //Unused description
        gallery.accessibilityLabel = "Swipe left and right through your photo library here. If one finger scrolling doesn't work, try double tapping and then dragging your finger."
        //gallery.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
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
    
    func startHeader() {
        let headerHeight: CGFloat = 44
        header.frame = CGRect(x: 0,y: UIApplication.shared.statusBarFrame.height,width: UIScreen.main.bounds.width,height: headerHeight)
        header.isAccessibilityElement = false
        
        //Perigo Logo -- Currently unused
        /*
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
    
    func startInstructions(){
        instructions.setBackgroundImage(UIImage(named: "HelpButton"), for: .normal)
        let width = UIScreen.main.bounds.width
        let size = width/10
        let startX : CGFloat = 8
        let startY = UIApplication.shared.statusBarFrame.height + 2
        instructions.frame = CGRect(x: startX, y: startY, width: size, height: size)
        instructions.layer.cornerRadius = size/2
        instructions.isAccessibilityElement = true
        instructions.accessibilityTraits = UIAccessibilityTraitNone
        let double = UIAccessibilityIsVoiceOverRunning() ? " double " : " "
        instructionText = "Perigo uses artificial intelligence to quickly speak aloud a description of your surroundings and photos. On the top part of the screen," + double + "tap for a description of the scene you are pointing your camera at. On the lower part of the screen, swipe left and right through your photo library and" + double + "tap for a description of your photos."
        instructions.accessibilityLabel = "Instructions: \n\n" + instructionText
        
        
        instructions.setTitle("", for: .normal)
        instructions.layer.shadowColor = UIColor.black.cgColor
        instructions.layer.shadowOpacity = 1.0
        instructions.layer.shadowRadius = size
        instructions.addTarget(self, action: #selector(self.speakInstructions), for: .touchUpInside)
        self.view.addSubview(instructions)
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
    
}

