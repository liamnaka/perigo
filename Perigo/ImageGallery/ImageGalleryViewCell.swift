//Made by Hyper in Oslo -> https://github.com/hyperoslo/ImagePicker

import UIKit
import CoreLocation
import Photos

class ImageGalleryViewCell: UICollectionViewCell {
    
    lazy var imageView = UIImageView()
    lazy var selectedImageView = UIImageView()
    private var videoInfoView: VideoInfoView
    lazy var blurView = UIVisualEffectView()
    var loc : CLLocation? = nil
    var photo : PHAsset? = nil
    
    private let videoInfoBarHeight: CGFloat = 15
    var duration: TimeInterval? {
        didSet {
            if let duration = duration, duration > 0 {
                self.videoInfoView.duration = duration
                self.videoInfoView.isHidden = false
            } else {
                self.videoInfoView.isHidden = true
            }
        }
    }
    
    func blur(){
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                self.blurView.effect = UIBlurEffect(style: UIBlurEffectStyle.light)
            }, completion: { (value: Bool) in
                UIView.animate(withDuration: 0.2, animations: {
                    self.blurView.effect = nil
                })
            })
            
        }
    }
    
    override init(frame: CGRect) {
        let videoBarFrame = CGRect(x: 0, y: frame.height - self.videoInfoBarHeight,
                                   width: frame.width, height: self.videoInfoBarHeight)
        videoInfoView = VideoInfoView(frame: videoBarFrame)
        super.init(frame: frame)
        
        for view in [imageView, selectedImageView, videoInfoView, blurView] as [UIView] {
            view.contentMode = .scaleAspectFill
            view.translatesAutoresizingMaskIntoConstraints = false
            view.clipsToBounds = true
            contentView.addSubview(view)
        }
        
        //isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityTraits = UIAccessibilityTraitButton
        
        if UIAccessibilityIsVoiceOverRunning(){
            let tap = UITapGestureRecognizer(target: self, action: #selector(self.scan))
            self.addGestureRecognizer(tap)
        }
        
        
        //imageView.isAccessibilityElement = true
        //accessibilityLabel = imageView.accessibilityLabel
        //accessibilityTraits = UIAccessibilityTraitImage
        //accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        
        //accesibility
        
        
        
        setupConstraints()
    }
    
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func scan(){
        blur()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        options.version = .original
        let manager = PHImageManager.default()
        manager.requestImageData(for: photo!, options: options, resultHandler: //Start photo asset request
            { data, _, _, _ in
                if let data = data {
                    let pic = UIImage(data: data)!
                    ViewController.sharedInstance?.locationScan(image: pic, date: Date(), location: self.loc)
                    
            }
        })
        
    }
    
    // MARK: - Configuration
    
    func configureCell(_ image: UIImage, asset: PHAsset) {
        imageView.image = image
        if UIAccessibilityIsVoiceOverRunning() {
           
            if let caption = ViewController.sharedInstance?.getDateSummary(date: asset.creationDate ?? Date.distantPast, context: false) {
                accessibilityLabel = "Image " + caption
            }
            loc = asset.location
            photo = asset
            
        }
        
        //self.accessibilityLabel = imageView.accessibilityLabel
        
        //accessibilityLabel = image.accessibilityLabel
    }
}

