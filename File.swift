////
////  File.swift
////  VirtualTourist
////
////  Created by benchmark on 7/31/18.
////  Copyright © 2018 Viktor Lantos. All rights reserved.
////
//
//import Foundation
////
////  FlickrAPIClient.swift
////  VirtualTourist
////
////  Created by benchmark on 7/31/18.
////  Copyright © 2018 Viktor Lantos. All rights reserved.
////
//// Since Flickr has made it require authentication to use the flickr.photos.geo.photosForLocation
//// we will use the public flickr.photos.search method with a geo bounding box (bbox)
//
//import Foundation
//import Alamofire
//import AlamofireObjectMapper
//import SwiftyJSON
//import ObjectMapper
//
//class FlickrAPIClient {
//	let baseURL: String = "https://api.flickr.com/services/rest/"
//	let api_key: String = "18ff1a787722fc3ad297e758880e2057"
//	let secret: String = "c3c518c7099f2802"
//	let method: String = "flickr.photos.search"
//	let format: String = "json"
//	let per_page = 3
//	let accuracy = 1
//	var startLat = -123.8587455078125
//	var startLong = 46.35308398800007
//	var endLat = -120.5518607421875
//	var endLong = 48.587958419830336
//	
//	class Photos: Mappable {
//		var photos: [Photo]
//		var testMapPhoto: [MinimalPhoto]
//		
//		required init?(map: Map) {
//			photos = (try? map.value("photos.photo")) ?? []
//			testMapPhoto = (try? map.value("photos.photo")) ?? []
//		}
//		
//		func mapping(map: Map) {
//			photos	<- map["photos"]
//			testMapPhoto <- map["testMapPhotos"]
//		}
//	}
//	
//	class Photo: Mappable {
//		var farm: Int
//		var id: String
//		var isfamily: Bool
//		var isfriend: Bool
//		var ispublic: Bool
//		var owner: String
//		var secret: String
//		var server: String
//		var title: String
//		
//		required init?(map: Map) {
//			farm = (try? map.value("farm")) ?? 0
//			id = (try? map.value("id")) ?? ""
//			isfamily = (try? map.value("isfamily")) ?? false
//			isfriend = (try? map.value("isfriend")) ?? false
//			ispublic = (try? map.value("ispublic")) ?? false
//			owner = (try? map.value("owner")) ?? ""
//			secret = (try? map.value("secret")) ?? ""
//			server = (try? map.value("server")) ?? ""
//			title = (try? map.value("title")) ?? ""
//		}
//		
//		// Mappable
//		func mapping(map: Map) {
//			farm		<- map["farm"]
//			id			<- map["id"]
//			isfamily	<- map["isfamily"]
//			isfriend	<- map["isfriend"]
//			ispublic	<- map["ispublic"]
//			owner		<- map["owner"]
//			secret		<- map["secret"]
//			server		<- map["server"]
//			title		<- map["title"]
//		}
//	}
//	
//	class MinimalPhoto: Mappable {
//		var farm: Int
//		var server: String
//		var id: String
//		var secret: String
//		
//		required init?(map: Map) {
//			farm = (try? map.value("farm")) ?? 0
//			server = (try? map.value("server")) ?? ""
//			id = (try? map.value("id")) ?? ""
//			secret = (try? map.value("secret")) ?? ""
//		}
//		
//		func mapping(map: Map) {
//			farm <- map["farm"]
//			server <- map["server"]
//			id <- map["id"]
//			secret <- map["secret"]
//		}
//	}
//	
//	
//	
//	func test() {
//		self.getPhotosForBoundingBox(startingLatitude: startLat, startingLongitude: startLong, endingLatitude: endLat, endingLongitude: endLong)
//	}
//	
//	func getPhotosForBoundingBox(startingLatitude: Double, startingLongitude: Double, endingLatitude: Double, endingLongitude: Double) {
//		Alamofire.request("\(baseURL)?method=\(method)&api_key=\(api_key)&format=\(format)&bbox=\(startingLatitude),\(startingLongitude),\(endingLatitude),\(endingLongitude)&accuracy=\(accuracy)&per_page=\(per_page)&nojsoncallback=1").responseObject { (response: DataResponse<Photos>) in
//			if let mapped = response.result.value {
//				for photo in mapped.photos {
//					let photoMirror = Mirror(reflecting: photo)
//					print("a photo: ")
//					for (name, value) in photoMirror.children {
//						guard let name = name else { continue }
//						print("\t\(name): '\(value)'") // \(type(of: value))
//					}
//					print("link: \(self.generateUrlForPhoto(photo: photo)?.absoluteString ?? "no link")")
//				}
//			}
//			
//		}
//	}
//	
//	func generateUrlForPhoto(photo: Photo) -> URL? {
//		let string = "https://farm\(photo.farm).staticflickr.com/\(photo.server)/\(photo.id)_\(photo.secret).jpg"
//		if let url = URL(string: string){
//			return url
//		} else {
//			print("Error creating URL from string \(string) using photo \(photo)")
//			return nil
//		}
//	}
//}
