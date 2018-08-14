//
//  Onboarding.swift
//  VirtualTourist
//
//  Created by benchmark on 8/14/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import Foundation
import UIKit

// TODO: Eventually we want to make the alerts less alert-y and more visually pleasing.
class Onboarding {
	static let defaults = UserDefaults.standard
	
	class func dropPinOnMe() {
		let hasRead = defaults.bool(forKey: "hasReadDropPinsOnMeMessage")
		if (!hasRead) {
			showAlertWith(title: "Drop a Pin on Me!", message: "You can use this button to drop pins at your current location!", action: UIAlertAction(title: "Got it", style: UIAlertActionStyle.default) { action in
				self.defaults.set(true, forKey: "hasReadDropPinsOnMeMessage")
			})
		}
	}
	
	class func myPlaces() {
		let hasRead = defaults.bool(forKey: "hasReadMyPlacesMessage")
		if (!hasRead) {
			showAlertWith(title: "My Places", message: "You can use this to toggle viewing pins between: ones you've dropped using your location data, ones you've added manually, and all pins.", action: UIAlertAction(title: "Got it", style: UIAlertActionStyle.default) { action in
				self.defaults.set(true, forKey: "hasReadMyPlacesMessage")
			})
		}
	}
	
	class func photoAlbum() {
		let hasRead = defaults.bool(forKey: "hasReadPhotoAlbumMessage")
		if (!hasRead) {
			showAlertWith(title: "Photo Album", message: "These are photos associated with your pin! You can select photos and remove them with the trash button, or long-press to enlarge a photo.", action: UIAlertAction(title: "Got it", style: UIAlertActionStyle.default) { action in
				self.defaults.set(true, forKey: "hasReadPhotoAlbumMessage")
			})
		}
	}
	
	class private func showAlertWith(title: String = "Alert", message: String = "Message", action: UIAlertAction) {
		let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
		alert.addAction(action)
		UIApplication.shared.keyWindow?.rootViewController?.present(alert, animated: true, completion: nil)
	}
}
