//
//  VideoFrameCell.swift
//  VideoScrubber
//
//  Created by Paul Solt on 11/30/20.
//

import UIKit

class VideoFrameCell: UICollectionViewCell {
    static var identifier: String = "VideoFrameCell"
    
    var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .orange
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // Debug label
    var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented - create programmatically")
    }
    
    func setUpViews() {
        contentView.addSubview(imageView)
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            // Image edge to edge
            contentView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: imageView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            
            // debug label centered
            contentView.centerXAnchor.constraint(equalTo: label.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: label.centerYAnchor),
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        reset()
    }
    
    private func reset() {
        imageView.image = nil
        label.text = ""
    }
}
