//
//  VideoScrubber.swift
//  VideoScrubber
//
//  Created by Paul Solt on 11/30/20.
//

import UIKit
import AVFoundation

struct Frame {
    let image: UIImage?
    let time: CMTime
}

class VideoScrubber: UIView {
    
    var asset: AVAsset? {
        didSet {
            guard let asset = asset else { return }
            loadDefaultImageForAsset(asset: asset)
            
            // TODO: calculate # frames and request first batch of frames
        }
    }
    
    func loadDefaultImageForAsset(asset: AVAsset) {
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime.zero)]) { (time, cgImage, _, result, error) in
            guard let cgImage = try? imageGenerator.copyCGImage(at: .zero,
                                                                actualTime: nil) else {
                // TODO: Failed to load default image (asset may be invalid, hide UI?)
                return
            }
            self.defaultImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    var defaultImage: UIImage?
    
    let height: CGFloat = 40
    let aspectRatio: CGFloat = 16.0 / 9.0

    var frames: [Frame] = []
    
    var frameCache: [String: UIImage] = [:]
    
    // MARK: - Views
    
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(VideoFrameCell.self, forCellWithReuseIdentifier: VideoFrameCell.identifier)
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.backgroundColor = .green
        return collectionView
    }()
    
    lazy var collectionViewLayout: UICollectionViewLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .zero
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 2
        layout.itemSize = calculateItemSize()
        return layout
    }()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.text = "00:00"
        return label
    }()
    
    lazy var timeLabelBackground: UIView = {
        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = .white
        background.alpha = 0.7
        background.layer.cornerCurve = .continuous
        background.layer.cornerRadius = 3
        return background
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setUpViews()
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Add padding to left and right edges to center the start position
        let screenWidth: CGFloat = superview?.bounds.size.width ?? 0
        let halfScreenWidth = screenWidth / 2
        collectionView.contentInset = UIEdgeInsets(top: 0, left: halfScreenWidth - safeAreaInsets.left, bottom: 0, right: halfScreenWidth - safeAreaInsets.right)
        
        // TODO: set scroll position if rotated based on current time?
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - create programmatically")
    }
    
    override var intrinsicContentSize: CGSize {
        return calculateItemSize()
    }
    
    func calculateItemSize() -> CGSize {
        CGSize(width: height * aspectRatio, height: height)
    }
    
    func setUpViews() {
        addSubview(collectionView)
        
        addSubview(timeLabelBackground)
        timeLabelBackground.addSubview(timeLabel)
        
        
        NSLayoutConstraint.activate([
            // Collection View spans width
            leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            topAnchor.constraint(equalTo: collectionView.topAnchor),
            bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
            
            // Label is centered above collection view
            centerXAnchor.constraint(equalTo: timeLabelBackground.centerXAnchor),
            collectionView.topAnchor.constraint(equalTo: timeLabelBackground.bottomAnchor, constant: 8),
            
            timeLabelBackground.centerXAnchor.constraint(equalTo: timeLabel.centerXAnchor),
            timeLabelBackground.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            timeLabelBackground.widthAnchor.constraint(equalTo: timeLabel.widthAnchor, constant: 16),
            timeLabelBackground.heightAnchor.constraint(equalTo: timeLabel.heightAnchor, constant: 1),
            
        ])
    }
    
}

extension VideoScrubber: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        var offset: CGFloat = scrollView.contentOffset.x
        // TODO: use the offset to send change events back to target/action

    }

}

extension VideoScrubber: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        5 // frames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoFrameCell.identifier, for: indexPath) as! VideoFrameCell
        
        cell.label.text = "\(indexPath.item)"
        
        if let image = defaultImage {
            cell.imageView.image = image
        }
        return cell
    }
    
    
}
