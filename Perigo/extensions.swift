//
//  extensions.swift
//  Perigo
//
//  Created by Liam on 8/14/17.
//  Copyright © 2017 Perigo. All rights reserved.
//

import Foundation
import UIKit

public extension UIImage {
    
    //Generate image with given UIColor
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
    
    func pixelData() -> [UInt8]? { //Currently not used
        let size = self.size
        let dataSize = size.width * size.height * 4
        var pixelData = [UInt8](repeating: 0, count: Int(dataSize))
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: 4 * Int(size.width),
                                space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        guard let cgImage = self.cgImage else { return nil }
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return pixelData
    }
}



@IBDesignable
class UIDescription: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func drawText(in rect: CGRect) {
        let yMargin : CGFloat = 16 //Distance from text to bottom of label frame
        let height = self.sizeThatFits(rect.size).height
        let y = rect.origin.y + rect.height - height - yMargin
        super.drawText(in: CGRect(x: rect.origin.x, y: y, width: rect.width, height: height))
    }
}



extension UILabel {
    func pushTransition(_ duration:CFTimeInterval) {
        let animation:CATransition = CATransition()
        animation.timingFunction = CAMediaTimingFunction(name:
            kCAMediaTimingFunctionEaseInEaseOut)
        animation.type = kCATransitionPush
        animation.subtype = kCATransitionFromRight
        animation.duration = duration
        layer.add(animation, forKey: kCATransitionPush)
    }
}



extension UIView {
    func makeCorner(withRadius radius: CGFloat) {
        self.layer.cornerRadius = radius
        self.layer.masksToBounds = true
        self.layer.isOpaque = false
    }
}


//UNUSED ViewController Methods
extension ViewController {
    
    //Experimental vars for Inception, Coco, Facenet
    //var Net: Inception3Net? = nil //ImageNet
    //var Coco: CocoHelper? = nil
    //var device: MTLDevice!
    //var commandQueue: MTLCommandQueue!
    //var textureLoader : MTKTextureLoader!
    //var ciContext : CIContext!
    
    //UNUSED: Inception proving to be unuseful/inaccurate
    func scanImageNet(image: UIImage){
        /*
         open = false
         var texture : MTLTexture? = nil
         
         do {
         texture = try textureLoader.newTexture(with: image.cgImage!, options: [:])
         }
         catch let error as NSError {
         fatalError("Unexpected error ocurred: \(error.localizedDescription).")
         }
         
         // to deliver optimal performance we leave some resources used in MPSCNN to be released at next call of autoreleasepool,
         // so the user can decide the appropriate time to release this
         autoreleasepool{
         // encoding command buffer
         let commandBuffer = commandQueue.makeCommandBuffer()
         // encode all layers of network on present commandBuffer, pass in the input image MTLTexture
         Net!.forward(commandBuffer: commandBuffer, sourceTexture: texture)
         // commit the commandBuffer and wait for completion on CPU
         commandBuffer.commit()
         commandBuffer.waitUntilCompleted()
         // display top-5 predictions for what the object should be labelled
         let description = Net!.getLabel()
         caption.font = UIFont(name: "AvenirNext-DemiBold", size: 25.0)
         //self.caption.text = description
         self.changeCaption(text: description)
         speak(words: description)
         NSLog("%@", description)
         open = true //Reset the scan flag
         }
         */
    }
    
    //TODO - COCO not yet implemented due to TF Missing op "equals", possibly more as of 6/25
    func scanCoco(image: UIImage){
        /*
         //Generate MSCOCO object segmentation from image
         autoreleasepool{
         let results = self.sight.coco_search(image)!;
         let description = Coco!.getLabel(ID: (results[2] as! NSArray)[0] as! NSNumber)
         caption.font = UIFont(name: "AvenirNext-DemiBold", size: 35.0)
         self.changeCaption(text: description)
         
         //Speak the new caption
         speak(words: description)
         NSLog("%@", description)
         open = true //Reset the scan flag
         }
         */
    }
    
    func switchNet(){
        //Switch from captioning to object detection and vice versa -- Currently unused
        natural = natural ? false : true
        print("Switched!")
    }
    
    //Test-run model to avoid long initial scanning time -- not currently in use
    func warmup(){
        open = false
        let blank = UIImage(color: UIColor.black, size: CGSize(width: 299,height: 299))
        self.sight.beam_search(blank)
        open = true
    }
}
