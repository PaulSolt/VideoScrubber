//
//  ViewController.swift
//  VideoScrubber
//
//  Created by Paul Solt on 11/29/20.
//

import UIKit
import AVFoundation

// Video player logic based on Apple's AVFoudnationSimplePlayer sample code

class VideoViewController: UIViewController {

    var player: AVPlayer = AVPlayer()
    
    let playButtonSymbol = "play.fill"
    let pauseButtonSymbol = "pause.fill"
    
    private var playerTimeControlStatusObserver: NSKeyValueObservation?
    private var playerCurrentItemStatusObserver: NSKeyValueObservation?
    private var timeObserverToken: Any?
    
    lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        return formatter
    }()
    
    lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: playButtonSymbol), for: .normal)
        button.addTarget(self, action: #selector(playPauseButtonPressed(_:)), for: .touchUpInside)
        return button
    }()
    
    @IBOutlet var playerView: PlayerView!
    
    lazy var videoScrubber: VideoScrubber = {
        let videoScrubber = VideoScrubber()
        videoScrubber.translatesAutoresizingMaskIntoConstraints = false
        videoScrubber.backgroundColor = .yellow
        videoScrubber.addTarget(self, action: #selector(didScrollVideoScrubber(sender:)), for: .valueChanged)
        return videoScrubber
    }()
    
    @objc func didScrollVideoScrubber(sender: VideoScrubber) {
        let time = CMTime(seconds: Double(videoScrubber.value), preferredTimescale: 600)
        stopPlayingAndSeekSmoothlyToTime(time: time)
    }
    
    // Smooth seeking based on Apple Technical Note: https://developer.apple.com/library/archive/qa/qa1820/_index.html#//apple_ref/doc/uid/DTS40016828
    // It will ignore seek requests if the player is still busy seeking
    private var seekTime = CMTime.zero
    private var isSeekInProgress = false
    
    func stopPlayingAndSeekSmoothlyToTime(time: CMTime) {
        player.pause() // resume playback if it was playing when completed
        
        // Try to seek if there is not a seek in progress
        if time != seekTime {
            seekTime = time
            if !isSeekInProgress {
                tryToSeekToSeekTime()
            }
        }
    }
    
    private func tryToSeekToSeekTime() {
        guard let status = player.currentItem?.status else { return }
        if status == .readyToPlay {
            actuallySeekToSeekTime()
        }
    }
    
    private func actuallySeekToSeekTime() {
        isSeekInProgress = true
        let seekTimeInProgress = seekTime
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { (isFinished) in
            if seekTimeInProgress == self.seekTime {
                self.isSeekInProgress = false
            } else {
                // If another seek request occured during our seek, seek to the most recent seek time
                self.tryToSeekToSeekTime()
            }
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureToolBar()
        configureVideoScrubber()
        disableUI()
        
        let url = Bundle.main.url(forResource: "BrewCoffeeVideo720", withExtension: "mp4")!
        loadVideo(url: url)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        player.pause()
        
        removePeriodicTimeObserver()
        
        super.viewWillDisappear(animated)
    }
    
    private func configureToolBar() {
        let playBarButton = UIBarButtonItem(customView: playPauseButton)
        toolbarItems = [.flexibleSpace(), playBarButton, .flexibleSpace()]
    }
    
    private func configureVideoScrubber() {
        view.addSubview(videoScrubber)
        
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: videoScrubber.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: videoScrubber.trailingAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: videoScrubber.bottomAnchor),
        ])
    }
    
    @IBAction func playPauseButtonPressed(_ sender: UIButton) {
        switch player.timeControlStatus {
        case .playing:
            player.pause()
        case .paused:
            player.play()
        default:
            player.pause()
        }
    }

    func loadVideo(url: URL) {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey : true])
        loadPropertyValues(forAsset: asset)
    }
    
    // AVAsset may block the main thread until the asset is loaded as properties like isPlayable
    // block until the asset is buffered. An asset may not be playable if it has protected content
    func loadPropertyValues(forAsset asset: AVURLAsset) {
        let assetKeysRequiredForPlayback = [ "playable", "hasProtectedContent", "duration" ]
        
        asset.loadValuesAsynchronously(forKeys: assetKeysRequiredForPlayback) {
            DispatchQueue.main.async {
                if self.validateAssetValues(forKeys: assetKeysRequiredForPlayback, asset: asset) {
                    // Prepare for playback
                    self.setUpPlaybackObservers()
                    
                    self.playerView.player = self.player
                    
                    self.player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                    
                    self.videoScrubber.asset = asset
                }
            }
        }
    }
    
    func validateAssetValues(forKeys keys: [String], asset: AVAsset) -> Bool {
        // Check keys for failures
        for key in keys {
            var error: NSError?
            if asset.statusOfValue(forKey: key, error: &error) == .failed {
                print("Error: The video failed to load the key: \(key)")
                
                let stringFormat = NSLocalizedString("The video failed to load the key \"%@\"", comment: "The asset cannot be loaded")
                let message = String.localizedStringWithFormat(stringFormat, key)
                handleErrorWithMessage(message, error: error)
                return false
            }
        }

        if !asset.isPlayable || asset.hasProtectedContent {
            print("Error: the video is not playable or has protected content")
            let message = NSLocalizedString("The video is not playable or has protected content", comment: "You cannot play this video")
            handleErrorWithMessage(message)
            return false
        }
        return true
    }
    
    func setUpPlaybackObservers() {
        // Listen for if the media can be played (not protected and valid media)
        playerTimeControlStatusObserver = player.observe(\AVPlayer.timeControlStatus,
                                                         options: [.initial, .new]) { [weak self] _, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updatePlayButton()
            }
        }
        
        // Listen for when the current item is ready to play
        playerCurrentItemStatusObserver = player.observe(\AVPlayer.currentItem?.status,
                                                         options: [.new, .initial]) { [weak self] (_, _) in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateViewsForCurrentItemStatus()
            }
        }
        
        // Listen for changes in the playback
        let interval = CMTime(value: 1, timescale: 30)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.updateViews(time: time)
        }
    }
    
    private func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
        }
    }
        
    private func updateViews(time: CMTime) {
        let timeElapsed = Float(time.seconds)
        
        // TODO: Update the slider UI for time
//        print("time: \(createTimeString(time: timeElapsed))")
    }
    
    private func createTimeString(time: Float) -> String {
        // truncate for expected behavior 00:00.5 = 00:00
        let components = DateComponents(second: Int(time))
        return timeFormatter.string(for: components)!
    }
    
    
    private func updatePlayButton() {
        var buttonImage: UIImage?
        switch player.timeControlStatus {
        case .playing:
            buttonImage = UIImage(systemName: pauseButtonSymbol)
        case .paused, .waitingToPlayAtSpecifiedRate:
            buttonImage = UIImage(systemName: playButtonSymbol)
        @unknown default:
            buttonImage = UIImage(systemName: playButtonSymbol)
        }
        guard let image = buttonImage else { return }
        self.playPauseButton.setImage(image, for: .normal)
    }

    private func updateViewsForCurrentItemStatus() {
        guard let currentItem = player.currentItem else {
            disableUI()
            return
        }
        
        switch currentItem.status {
        case .readyToPlay:
            enableUI()
        case .failed:
            disableUI()
            handleErrorWithMessage(currentItem.error?.localizedDescription ?? "", error: currentItem.error)
        default:
            disableUI()
        }
    }
    
    func disableUI() {
        playPauseButton.isEnabled = false
    }
    
    func enableUI() {
        playPauseButton.isEnabled = true
    }
    
    func handleErrorWithMessage(_ message: String, error: Error? = nil) {
        if let error = error {
            print("Error: \(message), error: \(error)")
        }
        let alertTitle = NSLocalizedString("Video Error", comment: "Alert title for video errors")
        let alert = UIAlertController(title: alertTitle, message: message, preferredStyle: .alert)
        let actionTitle = NSLocalizedString("OK", comment: "OK on video error alert")
        let alertAction = UIAlertAction(title: actionTitle, style: .default)
        alert.addAction(alertAction)
        present(alert, animated: true)
    }
}
