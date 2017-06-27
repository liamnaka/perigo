//
//  Faces.swift
//  Perigo
//
//  Created by Liam on 6/26/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import UIKit
import CoreImage

class faces {

    public func detect(image: UIImage) {
        
        guard let personciImage = CIImage(image: image) else {
            return
        }
        
        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        let faces = faceDetector!.features(in: personciImage)
        
        for face in faces as! [CIFaceFeature] {
            
            print("Found bounds are \(face.bounds)")
            
            let faceBox = UIView(frame: face.bounds)
            
            faceBox.layer.borderWidth = 3
            faceBox.layer.borderColor = UIColor.red.cgColor
            faceBox.backgroundColor = UIColor.clear
            //personPic.addSubview(faceBox)
            
            if face.hasLeftEyePosition {
                print("Left eye bounds are \(face.leftEyePosition)")
            }
            
            if face.hasRightEyePosition {
                print("Right eye bounds are \(face.rightEyePosition)")
            }
        }
    }
    
    public func startNet() {
        do{
            let structure = try NeuralNet.Structure(nodes: [784, 500, 10],
                                                    hiddenActivation: .rectifiedLinear, outputActivation: .softmax,
                                                    batchSize: 100, learningRate: 0.8, momentum: 0.9)
            
            
            let net = try NeuralNet(structure: structure)
            
        }
        catch {
            print(error)
        }
    
    
    }
    
    
    
    

}
