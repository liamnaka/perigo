//
//  location.swift
//  Perigo
//
//  Created by Liam on 8/15/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

extension ViewController {
    
    func locationScan(image: UIImage, date: Date, location: CLLocation?){
        getLocationString(location: location) { locString in
            self.describeAsset(image: image, date: date, location: locString)
        }
    }

    
    //Prepare yourself, this gets ugly
    func getLocationString(location: CLLocation?, completion: @escaping (String) -> Void) {
        let prefix = ", in "
        if let location = location { //location recieved
            self.geocoder.reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
                //Geocoder req
                
                print(location)
                
                if error != nil { //Called when geocoder times out or encounters error
                    completion("")
                    self.geocoder.cancelGeocode()
                }
                else { //Geocoder recieved placemarks
                    if let placemarks = placemarks { //Safe unwrap
                        if placemarks.count > 0 { //Describes location with greatest possile specificity
                            let pm = placemarks[0]
                            if let locality = pm.locality {
                                if let subloc = pm.subLocality {
                                    if let address = pm.thoroughfare {
                                        completion(prefix + address + ", " + subloc)
                                    }
                                    else{
                                        completion(prefix + subloc + " " + locality)
                                    }
                                }
                                else{
                                    completion(prefix + locality)
                                }
                            }
                            else if let admin = pm.administrativeArea {
                                completion(prefix + admin)
                            }
                            else if let country = pm.country {
                                completion(prefix + country)
                            }
                            else { completion("") }
                        }
                        else { completion("") }
                    }
                    else { completion("") }
                }
            }) //End geocoder
        }
        else { //No location received
            completion("")
        }
    }
    
    
}
