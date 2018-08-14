//
//  FlickrAPIClient.swift
//  VirtualTourist
//
//  Created by benchmark on 7/31/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import Foundation
import Alamofire
import AlamofireObjectMapper
import UIKit

// Since the app is so simple atm, we really only have a few methods and things are
// hardcoded or defaulted. But if we ever want to add anything in the future, this is the place for it!
class FlickrAPIClient {
	// User-Specific (Flickr now requires some level of authentication to use their API)
	let api_key: String = "18ff1a787722fc3ad297e758880e2057" 	// <  enter your api key here
	let secret: String = "c3c518c7099f2802" 					// <  enter your secret here
	
	// Defaults
	let baseURL: String = "https://api.flickr.com/services/rest/"
	let method: String = "flickr.photos.search" // TODO: Add ability to use more methods if the need arises
	let format: String = "json"
	let per_page = 99
	let accuracy = 1
	let sortOptions = ["date-posted-asc", "date-posted-desc", "date-taken-asc", "date-taken-desc", "interestingness-desc", "interestingness-asc", "relevance"]
	var queued: [Photo] = []
	
	// MARK: - App-specific convenience methods
	func downloadPhotosForPin(_ pin: Pin, _ completion: @escaping ([MappedPhoto]?) -> Void = {_ in }){
		let bbox = getBboxCornersForPointWith(lat: pin.latitude, long: pin.longitude)
		self.getPhotosForBoundingBox(startingLatitude: bbox[0], startingLongitude: bbox[1], endingLatitude: bbox[2], endingLongitude: bbox[3], completion)
	}
	
	func downloadDataForPhoto(_ photo: Photo, _ completion: @escaping (Data?)-> Void = {_ in }) {
		// Discard any duplicate requests
		if queued.contains(photo) {
			return
		}
		if let url = photo.url {
			Alamofire.request(url).responseData { (response) in
				if response.error == nil {
					completion(response.data)
				} else {
					if let index = self.queued.index(of: photo) {
						self.queued.remove(at: index)
					}
				}
			}
			queued.append(photo)
		} else {
			if let index = queued.index(of: photo) {
				queued.remove(at: index)
			}
			print("FlickrAPIClient - photo \(photo) provided to \(#function) had no url property")
		}
	}
	
	// MARK: - Flickr methods
	
	// Since Flickr has made it require authentication to use the flickr.photos.geo.photosForLocation
	// we will use the public flickr.photos.search method with a geo bounding box (bbox)
	// Flickr has a lat/lon/radius search as well, but it requires "limiting parameters," like tags. Which we don't really want to pass.
	// Unfortunately this means that we will get the same images each time! Ye gods!
	// ... Unless we have a pseudo-randomizer!!
	// It will pick a random sort order from the sort options the Flickr API has to offer
	// and then shuffle the array it returns. Best we can do given changes in Flickr's API :(
	func getPhotosForBoundingBox(startingLatitude: Double, startingLongitude: Double, endingLatitude: Double, endingLongitude: Double, pseudoRandom: Bool = true, _ completion: @escaping ([MappedPhoto]?) -> Void = {_ in }) {
		var sortDescriptor = ""
		if (pseudoRandom) {
			let descriptor = sortOptions[Int(arc4random_uniform(UInt32(sortOptions.count - 1)))]
			sortDescriptor = "&sort=\(descriptor)"
		}
		
		let queryString = "\(baseURL)?method=\(method)&api_key=\(api_key)&format=\(format)&bbox=\(startingLongitude),\(startingLatitude),\(endingLongitude),\(endingLatitude)&accuracy=\(accuracy)&per_page=\(per_page)&nojsoncallback=1\(sortDescriptor)"
		
		Alamofire.request(queryString).responseObject { (response: DataResponse<MappedPhotos>) in
			print("FlickrAPIClient - \(#function) - Received response: \(response)")
			if let mapped = response.result.value {
				if !(mapped.photos.count > 0){
					print("FlickrAPIClient - \(#function) - No photos returned")
					completion(nil)
					return
				}
				print("FlickrAPIClient - \(#function) - Photos fetched successfully")
				if (pseudoRandom) {
					completion(mapped.photos.shuffled())
				} else {
					completion(mapped.photos)
				}
			} else {
				completion(nil)
				print("FlickrAPIClient - \(#function) - Error getting response from API")
			}
		}
	}
	
	// MARK: - Utility
	func appDelegate () -> AppDelegate {
		return UIApplication.shared.delegate as! AppDelegate
	}
	
	func getBboxCornersForPointWith(lat: Double, long: Double, radius: Double = 0.5 ) -> [Double]{
		// Earth's circumference at the equator divided by 360 degrees
		let latitudeToMiles = 24901.92 / 360 // Approx 69.2 mi
		let northSouthDistanceInDegrees = radius/latitudeToMiles
		let eastWestDistanceInDegrees = northSouthDistanceInDegrees / cos(lat * Double.pi / 180)
		let southernmostLatitude = lat - northSouthDistanceInDegrees
		let northernmostLatitude = lat + northSouthDistanceInDegrees
		let westernLongitude = long - eastWestDistanceInDegrees
		let easternLongitude = long + eastWestDistanceInDegrees
		
		// There might be an alternative CoreLocation implementation, which might look something like this
		//		let centerCoord = CLLocationCoordinate2DMake(lat, long);
		//		let metersLat = lat/0.00062137
		//		let metersLon = long/0.00062137
		//		let region = MKCoordinateRegionMakeWithDistance(centerCoord, metersLat, metersLon);
		//
		//		let latMin = region.center.latitude - 0.5 * region.span.latitudeDelta;
		//		let latMax = region.center.latitude + 0.5 * region.span.latitudeDelta;
		//		let lonMin = region.center.longitude - 0.5 * region.span.longitudeDelta;
		//		let lonMax = region.center.longitude + 0.5 * region.span.longitudeDelta;
		
		return [southernmostLatitude,westernLongitude,northernmostLatitude,easternLongitude]
	}
}

// Here are some handy extensions! Courtesy of Stack Overflow.
extension MutableCollection {
	mutating func shuffle() {
		let c = count
		guard c > 1 else { return }
		
		for (firstUnshuffled, unshuffledCount) in zip(indices, stride(from: c, to: 1, by: -1)) {
			let d: Int = numericCast(arc4random_uniform(numericCast(unshuffledCount)))
			let i = index(firstUnshuffled, offsetBy: d)
			swapAt(firstUnshuffled, i)
		}
	}
}

extension Sequence {
	func shuffled() -> [Element] {
		var result = Array(self)
		result.shuffle()
		return result
	}
}
