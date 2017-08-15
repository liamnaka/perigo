//
//  gallery.swift
//  Perigo
//
//  Created by Liam on 8/15/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import UIKit

extension ViewController {

    func changeCaption(text: String){
        caption.text = text
        updateCaptionContrast()
    }
    
    //Changes the frame of contrast view to match label frame
    func updateCaptionContrast(){
        let yMargin : CGFloat = 16
        //let xMargin : CGFloat = 8
        let rect = caption.frame
        
        let height = caption.sizeThatFits(rect.size).height
        let y = rect.origin.y + rect.height - height - yMargin
        
        contrastView.frame = CGRect(x: 0, y: y-yMargin, width: UIScreen.main.bounds.width, height: height+(2*yMargin))
    }
    
    //Updating camera/gallery pointer/indicators
    func setPointers(cam: Bool?, library: Bool?){
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
    
    func reloadgallery(){
        gallery.fetchPhotos()
    }
    
}
