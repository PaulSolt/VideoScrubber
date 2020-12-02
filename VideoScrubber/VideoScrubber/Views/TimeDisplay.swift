//
//  TimeDisplay.swift
//  VideoScrubber
//
//  Created by Paul Solt on 12/2/20.
//

import UIKit

/// Displays time on a small background
class TimeDisplay: UIView {
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .label
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.text = "00:00"
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        configureViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureViews() {
        configureBackground()
        addSubview(timeLabel)

        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: timeLabel.centerXAnchor),
            self.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            self.widthAnchor.constraint(equalTo: timeLabel.widthAnchor, constant: 16),
            self.heightAnchor.constraint(equalTo: timeLabel.heightAnchor, constant: 1),
        ])
    }
    
    private func configureBackground() {
        backgroundColor = .systemGray6
        alpha = 0.7
        layer.cornerCurve = .continuous
        layer.cornerRadius = 3
    }
}
