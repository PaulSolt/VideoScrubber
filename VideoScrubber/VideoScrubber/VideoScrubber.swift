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

class VideoScrubber: UIControl {
    
    lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        return formatter
    }()
    
    
    private func createTimeString(time: Float) -> String {
        // truncate for expected behavior 00:00.5 = 00:00
        let components = DateComponents(second: Int(time))
        return timeFormatter.string(for: components)!
    }
    
    var value: Double = 0 {
        didSet {
            scrollTo(newValue: value)
        }
    }
    
    var asset: AVAsset? {
        didSet {
            guard let asset = asset else { return }
            loadDefaultImageForAsset(asset: asset)
            
            // TODO: calculate # frames and request first batch of frames
            loadImages(asset: asset)
        }
    }
    
    func loadDefaultImageForAsset(asset: AVAsset) {
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = calculateFrameSize()

        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime.zero)]) { (time, cgImage, _, result, error) in
            guard let cgImage = cgImage else {
                // TODO: Failed to load default image (asset may be invalid, hide UI?)
                return
            }
            self.defaultImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    let timeScale: CMTimeScale = 600
    
    let targetFrameDuration: CMTimeValue = 5
    
    
    func frameIndexForTime(_ time: CMTime) -> Int {
        return Int(time.value / Int64(time.timescale) / targetFrameDuration)
    }
    
    func timeForIndex(_ index: Int) -> CMTime {
        CMTime(value: CMTimeValue(index) * targetFrameDuration * CMTimeValue(timeScale), timescale: timeScale)
    }
    
    
    func loadImages(asset: AVAsset) {

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        var requestedFrameTimes = [NSValue]()
        var next = CMTime(value: 0, timescale: timeScale)
        let step = CMTime(value: targetFrameDuration * CMTimeValue(timeScale), timescale: timeScale)
        print("duration: \(asset.duration)")
        while next < asset.duration {
            requestedFrameTimes.append(NSValue(time: next))
            next = next + step
        }
            
//        imageGenerator.maximumSize = calculateFrameSize()
        var counter = 0
        imageGenerator.generateCGImagesAsynchronously(forTimes: requestedFrameTimes) { (requestedTime, cgImage, _, result, error) in
            counter += 1
            guard let cgImage = cgImage else {
                // TODO: failed to load more frames
                return
            }
            // Use the requested time so we have a predictable lookup
            let image = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                let frame = Frame(image: image, time: requestedTime)
                self.frames.append(frame)
                // update the views after all the requested images are loaded
                if counter == requestedFrameTimes.count {
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    func calculateFrameSize(scale: CGFloat = UIScreen.main.scale) -> CGSize {
        let size = calculateItemSize()
        return CGSize(width: size.width * scale, height: size.height * scale)
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
        label.textColor = .label
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.text = "00:00"
        return label
    }()
    
    lazy var timeLabelBackground: UIView = {
        let background = UIView()
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = .systemGray6
        background.alpha = 0.7
        background.layer.cornerCurve = .continuous
        background.layer.cornerRadius = 3
        return background
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setUpViews()
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
        if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
            print("scrollViewDidScroll() - not tracking, dragging, or decelerating")

            value = calculateValueFromScrollViewOffset(scrollView: scrollView)
            sendActions(for: .valueChanged)
        } else {
            print("scrollViewDidScroll()")
        }
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        print("scrollViewDidEndScrollingAnimation()")
    }

    private func calculateValueFromScrollViewOffset(scrollView: UIScrollView) -> Double {
        let xOffset: CGFloat = scrollView.contentOffset.x + scrollView.contentInset.left
        let width = scrollView.contentSize.width
        let duration = asset?.duration.seconds ?? 0.0
        let normalizedXOffset = Double(min(max(xOffset / width, 0), width))
        return normalizedXOffset * duration
    }
    
    private func scrollTo(newValue: Double) {
        let width = Double(collectionView.contentSize.width)
        let duration = asset?.duration.seconds ?? 0.0
        let normalizedXOffset = newValue / duration
        let xOffset = Double(min(max(normalizedXOffset * width, 0), width)) - Double(collectionView.contentInset.left)
        

        collectionView.contentOffset = CGPoint(x: xOffset, y: 0)

    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        print("scrollViewWillBeginDragging()")

        sendActions(for: .touchDragEnter)
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        print("scrollViewWillEndDragging().velocity: \(velocity)")
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        print("scrollViewDidEndDragging().willDecelerate: \(decelerate)")
        if !decelerate {
            sendActions(for: .touchDragExit)
        }
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        print("scrollViewDidEndDecelerating")
        sendActions(for: .touchDragExit)
    }
}

extension VideoScrubber: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        frames.count // 5 // frames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoFrameCell.identifier, for: indexPath) as! VideoFrameCell
        
        cell.label.text = "\(indexPath.item)"
        
        let frame = frames[indexPath.item]
        
        if let image = frame.image {
            cell.imageView.image = image
        } else if let image = defaultImage {
            cell.imageView.image = image
        }
        return cell
    }
}
