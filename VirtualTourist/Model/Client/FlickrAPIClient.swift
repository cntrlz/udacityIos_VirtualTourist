//
//  FlickrAPIClient.swift
//  VirtualTourist
//
//  Created by benchmark on 7/31/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//
// Since Flickr has made it require authentication to use the flickr.photos.geo.photosForLocation
// we will use the public flickr.photos.search method with a geo bounding box (bbox)

import Foundation
import Alamofire
import AlamofireObjectMapper
//import SwiftyJSON // unneeded
//import ObjectMapper

// Since the app is so simple atm, we really only have a few methods and things are
// hardcoded or defaulted. But if we ever want to add anything in the future, this is the place for it!
class FlickrAPIClient {
	// Defaults
	let baseURL: String = "https://api.flickr.com/services/rest/"
	let api_key: String = "18ff1a787722fc3ad297e758880e2057" 	// <  enter your api key here
	let secret: String = "c3c518c7099f2802" 					// <  enter your secret here
	let method: String = "flickr.photos.search"
	let format: String = "json"
	let per_page = 100
	let accuracy = 1
	var startLat = 46.35308398800007 	// get rid of this when done
	var startLong = -123.8587455078125	// get rid of this when done
	var endLat = 48.587958419830336		// get rid of this when done
	var endLong = -120.5518607421875	// get rid of this when done

	func test() {
		self.getPhotosForBoundingBox(startingLatitude: startLat, startingLongitude: startLong, endingLatitude: endLat, endingLongitude: endLong)
	}
	
	func getPhotosForBbox(_ bbox: [Double], _ completion: @escaping ([MappedPhoto]?) -> Void = {_ in }){
		self.getPhotosForBoundingBox(startingLatitude: bbox[0], startingLongitude: bbox[1], endingLatitude: bbox[2], endingLongitude: bbox[3], completion)
	}
	
	func getPhotosForLatitude(_ latitude: Double, longitude: Double, radius: Double = 0.5, _ completion: @escaping ([MappedPhoto]?) -> Void = {_ in }) {
		self.getPhotosForBbox(getBboxCornersForPointWith(lat: latitude, long: longitude, radius: radius), completion)
	}

	func getPhotosForBoundingBox(startingLatitude: Double, startingLongitude: Double, endingLatitude: Double, endingLongitude: Double, _ completion: @escaping ([MappedPhoto]?) -> Void = {_ in }) {
		print("FlickrAPIClient - Getting Photos for Bbox - [\(startingLatitude)/\(startingLongitude)] - [\(endingLatitude)/\(endingLongitude)]")
		Alamofire.request("\(baseURL)?method=\(method)&api_key=\(api_key)&format=\(format)&bbox=\(startingLongitude),\(startingLatitude),\(endingLongitude),\(endingLatitude)&accuracy=\(accuracy)&per_page=\(per_page)&nojsoncallback=1").responseObject { (response: DataResponse<MappedPhotos>) in
			print("FlickrAPIClient - Received response: \(response)")
			if let mapped = response.result.value {
				if !(mapped.photos.count > 0){
					print("FlickrAPIClient - No photos returned")
					completion(nil)
					return
				}
//				for photo in mapped.photos {
//					let photoMirror = Mirror(reflecting: photo)
//					print("a photo: ")
//					for (name, value) in photoMirror.children {
//						guard let name = name else { continue }
//						print("\t\(name): '\(value)'") // \(type(of: value))
//					}
//					print("link: \(photo.url()?.absoluteString ?? "no link")")
//				}
				print("FlickrAPIClient - Photos fetched successfully")
				completion(mapped.photos)
			} else {
				completion(nil)
				print("FlickrAPIClient - Error getting response from API")
			}
		}
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
		
		// There might be an alternative CoreLocation implementation
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
	
	// See: https://www.flickr.com/services/api/misc.urls.html
	func generateUrlForPhoto(photo: MappedPhoto) -> URL? {
		let string = "https://farm\(photo.farm).staticflickr.com/\(photo.server)/\(photo.id)_\(photo.secret).jpg"
		if let url = URL(string: string){
			return url
		} else {
			print("Error creating URL from string \(string) using photo \(photo)")
			return nil
		}
	}
	
	func getDataFromUrl(url: URL, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
		URLSession.shared.dataTask(with: url) { data, response, error in
			completion(data, response, error)
			}.resume()
	}
	
	func downloadImage(url: URL) {
		print("Download Started")
		getDataFromUrl(url: url) { data, response, error in
			guard let data = data, error == nil else { return }
			print(response?.suggestedFilename ?? url.lastPathComponent)
			print("Download Finished \(data)")
//			DispatchQueue.main.async() {
//				self.imageView.image = UIImage(data: data)
//			}
		}
	}
}
