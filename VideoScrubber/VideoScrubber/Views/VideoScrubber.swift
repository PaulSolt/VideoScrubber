//
//  VideoScrubber.swift
//  VideoScrubber
//
//  Created by Paul Solt on 11/30/20.
//

import UIKit
import AVFoundation

/// A custom control that loads video thumbnails from a video asset. The control expects
/// the video asset to be previously loaded for it's asynchronous keys.
///
/// It publishes UIControl events for touch scrolling:
/// - touchDragEnter - interaction has started
/// - touchDragExit - interaction has completed
/// - valueChanged - value changes as user is scrubbing video or decelerating
class VideoScrubber: UIControl {
    
    let height: CGFloat = 40
    let aspectRatio: CGFloat = 16.0 / 9.0
    
    // frame duration in seconds
    let targetFrameDuration: CMTimeValue = 5
    let timeScale: CMTimeScale = 600
    
    var frames: [Frame] = []
    var defaultImage: UIImage?
    
    // Use a private backing store so we can programmaticaly set without side effects
    private var _value: Double = 0
    var value: Double {
        set {
            _value = newValue
            scrollTo(newValue: _value)
            updateTimeLabel(time: _value)
        }
        get {
            _value
        }
    }
    
    var asset: AVAsset? {
        didSet {
            guard let asset = asset else { return }
            loadDefaultImageForAsset(asset: asset)
            
            loadImages(asset: asset)
        }
    }

    lazy var timeFormatter = VideoTimeFormatter()
        
    // MARK: - Views
    
    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(VideoFrameCell.self, forCellWithReuseIdentifier: VideoFrameCell.identifier)
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        return collectionView
    }()
    
    lazy var collectionViewLayout: UICollectionViewLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = .zero
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 1
        layout.itemSize = calculateItemSize()
        return layout
    }()
    
    lazy var timeDisplay: TimeDisplay = {
        let display = TimeDisplay()
        display.translatesAutoresizingMaskIntoConstraints = false
        return display
    }()
    
    lazy var playhead: UIImageView = {
        let image = UIImage(named: "playhead")!
        let imageView = UIImageView(image:image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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
        collectionView.contentInset = UIEdgeInsets(top: 0, left: halfScreenWidth - safeAreaInsets.left,
                                                   bottom: 0, right: halfScreenWidth - safeAreaInsets.right)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - create programmatically")
    }
    
    override var intrinsicContentSize: CGSize {
        return calculateItemSize()
    }

    func stopScrolling() {
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
    }
    
    private func calculateItemSize() -> CGSize {
        CGSize(width: height * aspectRatio, height: height)
    }

    var playheadCenterXConstraint: NSLayoutConstraint!
    var timeDisplayCenterXConstraint: NSLayoutConstraint!
    
    private func setUpViews() {
        addSubview(collectionView)
        addSubview(timeDisplay)
        addSubview(playhead)
        
        playheadCenterXConstraint = centerXAnchor.constraint(equalTo: playhead.centerXAnchor)
        timeDisplayCenterXConstraint = centerXAnchor.constraint(equalTo: timeDisplay.centerXAnchor)

        NSLayoutConstraint.activate([
            // Collection View spans width
            leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
            trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
            topAnchor.constraint(equalTo: collectionView.topAnchor),
            bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
            
            // Label is centered above collection view
            timeDisplayCenterXConstraint,
            collectionView.topAnchor.constraint(equalTo: timeDisplay.bottomAnchor, constant: 8),
            
            // Playhead is centered on collection view scrub bar
            playheadCenterXConstraint,
            playhead.topAnchor.constraint(equalTo: collectionView.topAnchor),
            playhead.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor),
        ])
    }
    
    /// Load a single default image to be used as the placeholder
    private func loadDefaultImageForAsset(asset: AVAsset) {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = calculateFrameSize()

        imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: CMTime.zero)]) { (time, cgImage, _, result, error) in
            guard let cgImage = cgImage else { return }
            self.defaultImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }
    
    /// Load a series of images using a fixed time step
    /// NOTE: this approach is not ideal if there is a long video, the timestep should be increased to limit
    /// the number of preview frames
    private func loadImages(asset: AVAsset) {
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = calculateFrameSize()

        var requestedFrameTimes = [NSValue]()
        var next = CMTime(value: 0, timescale: timeScale)
        let step = CMTime(value: targetFrameDuration * CMTimeValue(timeScale), timescale: timeScale)
        while next < asset.duration {
            requestedFrameTimes.append(NSValue(time: next))
            next = next + step
        }
            
        var counter = 0
        imageGenerator.generateCGImagesAsynchronously(forTimes: requestedFrameTimes) { (requestedTime, cgImage, _, result, error) in
            counter += 1
            guard let cgImage = cgImage else { return }
            
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
    
    private func calculateFrameSize(scale: CGFloat = UIScreen.main.scale) -> CGSize {
        let size = calculateItemSize()
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
    
    private func updateTimeLabel(time: Double) {
        timeDisplay.timeLabel.text = timeFormatter.string(for: time)
    }
    
    private func calculateValueFromScrollViewOffset(scrollView: UIScrollView) -> Double {
        let xOffset: CGFloat = scrollView.contentOffset.x + scrollView.contentInset.left
        let width = scrollView.contentSize.width
        let duration = asset?.duration.seconds ?? 0.0
        let normalizedXOffset = Double(min(max(xOffset / width, 0), 1))
        return normalizedXOffset * duration
    }
    
    private func scrollTo(newValue: Double) {
        let width = Double(collectionView.contentSize.width)
        let duration = asset?.duration.seconds ?? 0.0
        let normalizedXOffset = newValue / duration
        let xOffset = Double(min(max(normalizedXOffset * width, 0), width)) - Double(collectionView.contentInset.left)
        collectionView.contentOffset = CGPoint(x: xOffset, y: 0)
    }
    
    /// Moves the playhead and time display with the end range of the scrollview
    private func horizontallyBouncePlayhead(scrollView: UIScrollView) {
        let offset = scrollView.contentOffset.x + scrollView.contentInset.left
        let width = collectionView.contentSize.width
        if offset < 0 || offset > width {
            playheadCenterXConstraint.constant = offset
            timeDisplayCenterXConstraint.constant = offset
        }
        if offset > width {
            playheadCenterXConstraint.constant = offset - width
            timeDisplayCenterXConstraint.constant = offset - width
        }
    }
}

// MARK: - UICollectionViewDelegate

extension VideoScrubber: UICollectionViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // layoutSubviews can cause scrollViewDidScroll to be called, prevent invalid logic by
        // making sure the user actually scrolled the content
        if scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating {
            _value = calculateValueFromScrollViewOffset(scrollView: scrollView)
            updateTimeLabel(time: _value)
            sendActions(for: .valueChanged)
        }
        horizontallyBouncePlayhead(scrollView: scrollView)
    }
        
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        sendActions(for: .touchDragEnter)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            sendActions(for: .touchDragExit)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        sendActions(for: .touchDragExit)
    }
}

// MARK: - UICollectionViewDataSource

extension VideoScrubber: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        frames.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: VideoFrameCell.identifier, for: indexPath) as! VideoFrameCell
                
        let frame = frames[indexPath.item]
        if let image = frame.image {
            cell.imageView.image = image
        } else if let image = defaultImage {
            cell.imageView.image = image
        }
        
        return cell
    }
}
