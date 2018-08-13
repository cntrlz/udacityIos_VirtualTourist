//
//  PhotoAlbumCell.swift
//  VirtualTourist
//
//  Created by benchmark on 8/2/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//


import UIKit

class PhotoAlbumCell: UICollectionViewCell {
	@IBOutlet weak var imageView: UIImageView!
	@IBOutlet weak var containerView: UIView!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	var indexPath: IndexPath? = nil
	
	override func awakeFromNib() {
		super.awakeFromNib()
		containerView.layer.cornerRadius = 8
		containerView.layer.masksToBounds = true
	}
	
	func setImageData(data: Data?){
		if let data = data {
			let image: UIImage? = UIImage(data: data)
			
			if image != nil {
				imageView.image = image
				self.activityIndicator.stopAnimating()
			} else {
				print("PhotoAlbumCell - Cell could not make image with data provided")
			}
		} else {
			print("PhotoAlbumCell - \(#function) was not provided data")
		}
	}
	
	override func prepareForReuse() {
		super.prepareForReuse()
		imageView.image = UIImage()
		self.activityIndicator.startAnimating()
	}
}
