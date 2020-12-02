//
//  TimeFormatter.swift
//  VideoScrubber
//
//  Created by Paul Solt on 12/2/20.
//

import Foundation

/// Formats time in 00:00 format
class VideoTimeFormatter {

    lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        return formatter
    }()

    func string(for time: Double) -> String {
        // truncate for expected behavior 00:00.5 => 00:00
        let components = DateComponents(second: Int(time))
        return timeFormatter.string(for: components)!
    }
}
