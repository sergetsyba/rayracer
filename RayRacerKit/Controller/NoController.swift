//
//  NoController.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 7.12.2024.
//

struct NoController: Controller {
	let output = 0xff
}

// MARK: -
extension Controller where Self == NoController {
	static var none: Self {
		return NoController()
	}
}
