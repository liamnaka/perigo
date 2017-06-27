import UIKit
import Photos
fileprivate func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}


protocol ImageGalleryPanGestureDelegate: class {
    
    func panGestureDidStart()
    func panGestureDidChange(_ translation: CGPoint)
    func panGestureDidEnd(_ translation: CGPoint, velocity: CGPoint)
}

open class ImageGalleryView: UIView {

    
    //The last index path swiped to.
    var last : IndexPath? = nil
    
    public func getPicture() -> PHAsset?   {
        if let indexPath = getCenter(){
            guard let cell = collectionView.cellForItem(at: indexPath) as? ImageGalleryViewCell else { return nil }
            cell.blur()
            
            return assets[indexPath.row]
            
            /*
             let time = asset.creationDate ?? Date.distantPast
             let options = PHImageRequestOptions()
             options.deliveryMode = .highQualityFormat
             options.isSynchronous = false
             options.version = .original
             
             let manager = PHImageManager.default()
             
             return (asset,time,options,manager)
             
             
             manager.requestImageData(for: asset, options: options, resultHandler:
             { data, _, _, _ in
             
             if let data = data {
             let pic = UIImage(data: data)
             return (pic, time)
             }})
             */
            
        }
        return nil
        
    }
    
    struct Dimensions {
        static let galleryHeight: CGFloat = 160
        static let galleryBarHeight: CGFloat = 24
    }
    
    var configuration = Configuration()
    
    lazy open var collectionView: UICollectionView = { [unowned self] in
        let collectionView = UICollectionView(frame: CGRect.zero,
                                              collectionViewLayout: self.collectionViewLayout)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = self.configuration.mainColor
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        
        return collectionView
        }()
    
    lazy var collectionViewLayout: UICollectionViewLayout = { [unowned self] in
        let layout = ImageGalleryLayout()
        
        let totalWidth = UIScreen.main.bounds.width
        let totalHeight = self.frame.height
        let inset = (totalWidth-totalHeight)/2
        
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = self.configuration.cellSpacing
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsetsMake(0, inset, 0, inset)
        
        return layout
        }()
    
    /*
     lazy var topSeparator: UIView = { [unowned self] in
     let view = UIView()
     view.translatesAutoresizingMaskIntoConstraints = false
     view.addGestureRecognizer(self.panGestureRecognizer)
     view.backgroundColor = self.configuration.gallerySeparatorColor
     
     return view
     }()
     */
    
    lazy var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
        let gesture = UIPanGestureRecognizer()
        gesture.addTarget(self, action: #selector(handlePanGestureRecognizer(_:)))
        
        return gesture
        }()
    
    open lazy var noImagesLabel: UILabel = { [unowned self] in
        let label = UILabel()
        label.font = self.configuration.noImagesFont
        label.textColor = self.configuration.noImagesColor
        label.text = self.configuration.noImagesTitle
        label.alpha = 0
        label.sizeToFit()
        self.addSubview(label)
        
        return label
        }()
    
    open lazy var selectedStack = ImageStack()
    lazy var assets = [PHAsset]()
    
    weak var delegate: ImageGalleryPanGestureDelegate?
    var collectionSize: CGSize?
    var shouldTransform = false
    var imagesBeforeLoading = 0
    var fetchResult: PHFetchResult<AnyObject>?
    var imageLimit = 0
    
    // MARK: - Initializers
    
    public init(configuration: Configuration? = nil) {
        if let configuration = configuration {
            self.configuration = configuration
        }
        super.init(frame: .zero)
        configure()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure() {
        //Tick Sound even when Muted
  
        backgroundColor = configuration.mainColor
        
        
        
        collectionView.register(ImageGalleryViewCell.self,
                                forCellWithReuseIdentifier: CollectionView.reusableIdentifier)
        
        //collectionView.isPagingEnabled = true
        
        collectionView.bounces = false
        
        
        collectionView.isAccessibilityElement = false
        //collectionView.accessibilityLabel = "Tap once to describe your photos. Scroll sideways for more."
        //collectionView.acces
        collectionView.accessibilityTraits = UIAccessibilityTraitAllowsDirectInteraction
        //[collectionView, topSeparator].forEach { addSubview($0) }
        addSubview(collectionView)
        
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        //let inset = (totalWidth-totalHeight)/2
        //collectionView.contentInset = UIEdgeInsetsMake(0, inset, 0, inset)
        
        //topSeparator.addSubview(configuration.indicatorView)
        
        imagesBeforeLoading = 0
        fetchPhotos()
        //collectionView.accessibilityT = UIAccessibilityTraitAllowsDirectInteraction
    }
    
    
    // MARK: - Layout
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        updateNoImagesLabel()
    }
    
    func updateFrames() {
        
        let totalWidth = UIScreen.main.bounds.width
        let totalHeight = frame.height
        frame.size.width = totalWidth
        
        collectionView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: frame.height)
        collectionSize = CGSize(width: collectionView.frame.height, height: collectionView.frame.height)
        
        
        
        
        collectionView.reloadData()
    }
    
    func updateNoImagesLabel() {
        let height = bounds.height
        let threshold = Dimensions.galleryBarHeight * 2
        
        UIView.animate(withDuration: 0.25, animations: {
            if threshold > height || self.collectionView.alpha != 0 {
                self.noImagesLabel.alpha = 0
            } else {
                self.noImagesLabel.center = CGPoint(x: self.bounds.width / 2, y: height / 2)
                self.noImagesLabel.alpha = (height > threshold) ? 1 : (height - Dimensions.galleryBarHeight) / threshold
            }
        })
    }
    
    // MARK: - Photos handler
    
    func fetchPhotos(_ completion: (() -> Void)? = nil) {
        AssetManager.fetch(withConfiguration: configuration) { assets in
            self.assets.removeAll()
            self.assets.append(contentsOf: assets)
            self.collectionView.reloadData()
            
            completion?()
        }
    }
    
    // MARK: - Pan gesture recognizer
    
    func handlePanGestureRecognizer(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        
        let translation = gesture.translation(in: superview)
        let velocity = gesture.velocity(in: superview)
        
        switch gesture.state {
        case .began:
            delegate?.panGestureDidStart()
        case .changed:
            delegate?.panGestureDidChange(translation)
        case .ended:
            delegate?.panGestureDidEnd(translation, velocity: velocity)
        default: break
        }
    }
    
    func displayNoImagesMessage(_ hideCollectionView: Bool) {
        collectionView.alpha = hideCollectionView ? 0 : 1
        updateNoImagesLabel()
    }
}

// MARK: CollectionViewFlowLayout delegate methods

extension ImageGalleryView: UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView,
                               layout collectionViewLayout: UICollectionViewLayout,
                               sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let collectionSize = collectionSize else { return CGSize.zero }
        
        return collectionSize
    }
}

// MARK: CollectionView delegate methods

extension ImageGalleryView: UICollectionViewDelegate {
    
    
    
    //public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
    
    //   centerView()
    
    //}
    
    //public func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
    //    centerView()
    //}
    
    
    
    //public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
    //if collectionView.isDecelerating == false {
    // centerView()
    //}
    //}
    
    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        let minWidth : CGFloat = 2
        
        let cellWidth = collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: IndexPath(item: 0, section: 0)).width + minWidth
        
        let page: CGFloat
        let proposedPage = targetContentOffset.pointee.x / max(1,cellWidth)
        page = floor(proposedPage + 0.5)
        
        targetContentOffset.pointee = CGPoint(x: cellWidth * page, y: targetContentOffset.pointee.y)
 
        
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if last != getCenter() {
            AudioServicesPlaySystemSound(1104)
            last = getCenter()
        }
        
        
        
    }
    
    
    func centerView()
    {
        let center = getCenter()
        //if let last = last {
        //let cell = collectionView.cellForItem(at: last)
        //cell?.contentView.alpha = 0.4
        //}
        
        if let center = center {
            //let cell = collectionView.cellForItem(at: center)
            //cell?.contentView.alpha = 1
            self.collectionView.scrollToItem(at: center, at: .centeredHorizontally, animated: true)
            
            //last = center
        }
    }
    
    public func getCenter() -> IndexPath?
    {
        let half = self.collectionView.frame.width/2
        
        if  collectionView.visibleCells.count == 0 {
            return collectionView.indexPathForItem(at: CGPoint(x: half,y: 0))
        }
        else{
            
            var closestCell : UICollectionViewCell = collectionView.visibleCells[0];
            for cell in collectionView.visibleCells as [UICollectionViewCell] {
                let closestCellDelta = abs(closestCell.center.x - collectionView.bounds.size.width/2.0 - collectionView.contentOffset.x)
                let cellDelta = abs(cell.center.x - collectionView.bounds.size.width/2.0 - collectionView.contentOffset.x)
                if (cellDelta < closestCellDelta){
                    closestCell = cell
                }
            }
            
            let indexPath = collectionView.indexPath(for: closestCell)
            
            return indexPath
            
        }
    }
    
    /*public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath){
     guard let cell = collectionView.cellForItem(at: indexPath) as? ImageGalleryViewCell else { return }
     cell.blur()
     
     let asset = assets[(indexPath as NSIndexPath).row]
     var pic = UIImage()
     let time = asset.creationDate ?? Date.distantPast
     let options = PHImageRequestOptions()
     options.deliveryMode = .highQualityFormat
     options.isSynchronous = false
     options.version = .original
     
     let manager = PHImageManager.default()
     
     manager.requestImageData(for: asset, options: options, resultHandler:
     { data, _, _, _ in
     
     if let data = data {
     pic = UIImage(data: data)!
     ViewController.sharedInstance?.picker_scan(image: pic, date: time)
     }})
     }*/
}
