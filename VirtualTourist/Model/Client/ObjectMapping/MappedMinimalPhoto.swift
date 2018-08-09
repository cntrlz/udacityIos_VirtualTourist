//
//  MinimalPhoto.swift
//  VirtualTourist
//
//  Created by benchmark on 7/31/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import ObjectMapper

// Only the data we need to generate an image URL
class MappedMinimalPhoto: Mappable {
	var farm: Int
	var server: String
	var id: String
	var secret: String
	
	required init?(map: Map) {
		farm = (try? map.value("farm")) ?? 0
		server = (try? map.value("server")) ?? ""
		id = (try? map.value("id")) ?? ""
		secret = (try? map.value("secret")) ?? ""
	}
	
	func mapping(map: Map) {
		farm <- map["farm"]
		server <- map["server"]
		id <- map["id"]
		secret <- map["secret"]
	}
}
