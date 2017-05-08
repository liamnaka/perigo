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



class ViewController: UIViewController, AVCapturePhotoCaptureDelegate,AVSpeechSynthesizerDelegate {

    var sight = vision()
    var captureSession : AVCaptureSession!
    var sessionOutput : AVCapturePhotoOutput!
    var previewLayer : AVCaptureVideoPreviewLayer!
    var previewView = UIView()
    
    static var sharedInstance : ViewController?
    
    //Flag for controlling neural net input
    var open = true
    
    let caption = UILabel()
    
    let voice = AVSpeechSynthesizer()
    let audio = AVAudioSession.sharedInstance()
    let audioSettings : AVAudioSessionCategoryOptions  = [ .mixWithOthers,
                                                    .duckOthers,
                                                    .interruptSpokenAudioAndMixWithOthers]
    let audioCategory = AVAudioSessionCategoryPlayback
    /*override func loadView() {
        
        super.loadView()
        //startNet()
    }*/
    
    
    override func viewDidLoad() {
        
        //Model loading should be called in AppDelegate, not viewDidLoad
        //startNet()
        
        super.viewDidLoad()
        
        ViewController.sharedInstance = self
        
        startNet()
        startCam()
        startCaption()
        startPicker()
        startVoice()
        print("Hello :)")
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.takePicture))
        previewView.addGestureRecognizer(tap)
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Capture a photo and generate a caption
    func takePicture(){
        
        //print("Tapped")
        
        if open { open = false
            
            if #available(iOS 10,*) {
                let feedbackGenerator = UISelectionFeedbackGenerator()
                feedbackGenerator.selectionChanged()
            }
            
            let pop: SystemSoundID = 1104
            AudioServicesPlaySystemSound (pop)
            
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
                scan(image: image)
            }
            else {
                NSLog("%@", "Failed to scan image")
                open = true
            }
            
        }
        
    }
    
    
    func scan(image: UIImage){ //Possible unwrap issues or nil in optional error source
        
        
        
        //Generate caption from image
        let description = self.sight.beam_search(image) ?? "Did not run properly"
        
        //Update caption text
        self.caption.text = description
        
        //Speak the new caption
        speak(words: description)
        NSLog("%@", description)
        //print(cap ?? "Did not run properly")
        open = true //Reset the scan flag

    }
    
    func picker_scan(image: UIImage, date: Date){
        
        if open {
            
            open = false
        
            //Generate caption from image
            let description = self.sight.beam_search(image) ?? "Did not run properly"
            
            print(image)
            //Update caption text
            self.caption.text = description
            
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
        let utterance = AVSpeechUtterance(string: words)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
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
        
        if AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) !=  AVAuthorizationStatus.authorized
        {
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { (granted :Bool) -> Void in
                if granted == true
                {
                    print("Accepted Camera Permission")
                }
                else
                {
                    print("Rejected Camera Permission")
                }
            });
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
      
    }
    
    
    func startCaption(){
        
        caption.text = "Tap to Describe"
        caption.textColor = UIColor.white
        caption.font = UIFont(name: "AvenirNext-DemiBold", size: 30.0)
        caption.textAlignment = NSTextAlignment.center
        
        let width = UIScreen.main.bounds.width - 16
        let height = CGFloat(UIScreen.main.bounds.height/2)
        caption.frame = CGRect(x: 8, y: UIScreen.main.bounds.width*(2/3)-(height/2), width: width, height: height)
        caption.numberOfLines = 0
        
        //Drop shadow
        caption.layer.shadowColor = UIColor.black.cgColor
        caption.layer.shadowOpacity = 1
        caption.layer.shadowOffset = CGSize.zero
        caption.layer.shadowRadius = 10
        caption.layer.shouldRasterize = true
        
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
        
        let top = previewView.frame.maxY
        let height = UIScreen.main.bounds.height - top
        let frame = CGRect(x: 0, y: top, width: UIScreen.main.bounds.width, height: height)
        
        let picker = ImageGalleryView(frame: frame)
        //picker.delegate = self
        //picker.configuration = Configuration()
        //picker.selectedStack = ImageStack()
        picker.collectionView.layer.anchorPoint = CGPoint(x: 0, y: 0)
        picker.imageLimit = 1
        picker.updateFrames()
        
        view.addSubview(picker)
    }
    
    func startVoice(){
        do {
            try audio.setCategory(audioCategory, with: audioSettings)
        }
        catch let error as NSError {
            print("Audio Setup Error: \(error)")
        }
        voice.delegate = self
    }
    
    
    func startNet(){
        sight.load_model()
        open = true
        //warmup()
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





