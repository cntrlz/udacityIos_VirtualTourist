//
//  Photos.swift
//  VirtualTourist
//
//  Created by benchmark on 7/31/18.
//  Copyright © 2018 Viktor Lantos. All rights reserved.
//

import ObjectMapper

class MappedPhotos: Mappable {
	var photos: [MappedPhoto]
	
	required init?(map: Map) {
		photos = (try? map.value("photos.photo")) ?? []
	}
	
	func mapping(map: Map) {
		photos	<- map["photos"]
	}
}
