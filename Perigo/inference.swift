//
//  inference.swift
//  Perigo
//
//  Created by Liam on 8/15/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import Photos
import UIKit

extension ViewController{

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
                
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isSynchronous = false
                options.version = .original
                let manager = PHImageManager.default()
                let timer = Timer(timeInterval: 1.0, target: self, selector: #selector(self.timeout), userInfo: nil, repeats: false)
                
                manager.requestImageData(for: asset, options: options, resultHandler: //Start photo asset request
                    { data, _, _, _ in
                        if let data = data {
                            let pic = UIImage(data: data)!
                            self.locationScan(image: pic, date: date, location: location)
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
        let dateSummary = UIAccessibilityIsVoiceOverRunning() ? "" : "\n\n" + getDateSummary(date: date, context:true)
        
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
    
}
