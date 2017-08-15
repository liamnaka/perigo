//
//  date.swift
//  Perigo
//
//  Created by Liam on 8/15/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation

extension ViewController {
    
    func getDateSummary(date: Date, context: Bool) -> String {
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
            if !Calendar.current.isDate(date, inSameDayAs:lastDate ?? Date.distantFuture) || !context {//Isolating components of date
                
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
    
}
