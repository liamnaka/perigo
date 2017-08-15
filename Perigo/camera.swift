//
//  camera.swift
//  Perigo
//
//  Created by Liam on 8/15/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import UIKit

extension ViewController : AVCapturePhotoCaptureDelegate {

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
    
    func getSettings() -> AVCapturePhotoSettings {
        let settings = AVCapturePhotoSettings()
        //Set capture seetings
        //let position = self.captureSession.input.device.position
        
        settings.flashMode = torch ? .auto : .off
        
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

}
