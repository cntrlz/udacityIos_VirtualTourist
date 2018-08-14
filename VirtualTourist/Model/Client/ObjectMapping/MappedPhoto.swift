//
//  File.swift
//  VirtualTourist
//
//  Created by benchmark on 7/31/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import ObjectMapper

// The full default response from Flickr's API
// Technically, we only really need:
// farm
// server
// id
// secret
// Which is all we need for building url strings
class MappedPhoto: Mappable {
	var farm: Int
	var server: String
	var id: String
	var secret: String
	
	var isfamily: Bool
	var isfriend: Bool
	var ispublic: Bool
	var owner: String
	var title: String
	
	required init?(map: Map) {
		farm = (try? map.value("farm")) ?? 0
		server = (try? map.value("server")) ?? ""
		id = (try? map.value("id")) ?? ""
		secret = (try? map.value("secret")) ?? ""
		
		isfamily = (try? map.value("isfamily")) ?? false
		isfriend = (try? map.value("isfriend")) ?? false
		ispublic = (try? map.value("ispublic")) ?? false
		owner = (try? map.value("owner")) ?? ""
		title = (try? map.value("title")) ?? ""
	}
	
	func mapping(map: Map) {
		farm		<- map["farm"]
		server		<- map["server"]
		id			<- map["id"]
		secret		<- map["secret"]
		
		isfamily	<- map["isfamily"]
		isfriend	<- map["isfriend"]
		ispublic	<- map["ispublic"]
		owner		<- map["owner"]
		title		<- map["title"]
	}
	
	// Computed convenience property for building a url
	// See: https://www.flickr.com/services/api/misc.urls.html
	func url() -> URL? {
		let string = "https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret).jpg"
		if let url = URL(string: string){
			return url
		} else {
			return nil
		}
	}
}
