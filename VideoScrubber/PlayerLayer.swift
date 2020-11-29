//
//  PlayerLayer.swift
//  VideoScrubber
//
//  Created by Paul Solt on 11/29/20.
//

import UIKit
import AVFoundation

/// A video playback view that uses the AVPLayerLayer as its
/// backing layer
class PlayerLayer: UIView {
    
    var player: AVPlayer? {
        set { playerLayer.player = newValue }
        get { playerLayer.player }
    }
    
    var playerLayer: AVPlayerLayer {
        self.layer as! AVPlayerLayer
    }
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
