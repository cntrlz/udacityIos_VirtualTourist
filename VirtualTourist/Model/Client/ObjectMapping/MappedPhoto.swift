//
//  File.swift
//  VirtualTourist
//
//  Created by benchmark on 7/31/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import ObjectMapper

// The full default response from Flickr's API
class MappedPhoto: Mappable {
	var farm: Int
	var id: String
	var isfamily: Bool
	var isfriend: Bool
	var ispublic: Bool
	var owner: String
	var secret: String
	var server: String
	var title: String
	
	required init?(map: Map) {
		farm = (try? map.value("farm")) ?? 0
		id = (try? map.value("id")) ?? ""
		isfamily = (try? map.value("isfamily")) ?? false
		isfriend = (try? map.value("isfriend")) ?? false
		ispublic = (try? map.value("ispublic")) ?? false
		owner = (try? map.value("owner")) ?? ""
		secret = (try? map.value("secret")) ?? ""
		server = (try? map.value("server")) ?? ""
		title = (try? map.value("title")) ?? ""
	}
	
	func mapping(map: Map) {
		farm		<- map["farm"]
		id			<- map["id"]
		isfamily	<- map["isfamily"]
		isfriend	<- map["isfriend"]
		ispublic	<- map["ispublic"]
		owner		<- map["owner"]
		secret		<- map["secret"]
		server		<- map["server"]
		title		<- map["title"]
	}
	
	func url() -> URL? {
		let string = "https://farm\(farm).staticflickr.com/\(server)/\(id)_\(secret).jpg"
		if let url = URL(string: string){
			return url
		} else {
			return nil
		}
	}
}
