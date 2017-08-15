//
//  speach.swift
//  Perigo
//
//  Created by Liam on 8/15/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import UIKit

extension ViewController : AVSpeechSynthesizerDelegate {
    
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
    
    func speakInstructions(){
        if !UIAccessibilityIsVoiceOverRunning(){
            speak(words: instructionText)
        }
    }

}
