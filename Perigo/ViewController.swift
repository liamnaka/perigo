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


class ViewController: UIViewController {
    
    //Flag for type of image inference, default is im2txt (experimental var)
    var natural = true
    var sight = vision() //Wrapper class for image captioning via im2txt
    
    var captureSession : AVCaptureSession!
    var sessionOutput : AVCapturePhotoOutput!
    //var position : AVCaptureDevicePosition = .unspecified
    var torch = false
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
    
    var instructions = UIButton()

    static var sharedInstance : ViewController?
    
    var instructionText : String = "dog"
    
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
        startCaption()
        startGallery()
        startInstructions()
        //startHeader()
        startVoice()

        //Mode switcher - unused until more features are added
        /*let swipe = UISwipeGestureRecognizer(target: self, action: #selector(self.switchNet))
        swipe.direction = UISwipeGestureRecognizerDirection.down
        self.view.addGestureRecognizer(swipe)*/
        
        previewView.isAccessibilityElement = true
        previewView.accessibilityTraits = UIAccessibilityTraitButton
        previewView.accessibilityLabel = "Take a picture"
       
        //Create rounded edges
        self.view.backgroundColor = UIColor.black
        self.view.makeCorner(withRadius: 6)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async { [unowned self] in
            if self.captureSession.isRunning {
                self.captureSession.stopRunning() //Ending captureSession
            }
        }
        super.viewWillDisappear(animated)
    }

} 


