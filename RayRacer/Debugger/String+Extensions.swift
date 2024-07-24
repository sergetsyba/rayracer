//
//  String+Extensions.swift
//  RayRacer
//
//  Created by Serge Tsyba on 1.6.2024.
//

import Cocoa

extension String {
	func size(withFont font: NSFont) -> NSSize {
		return NSString(string: self)
			.size(withAttributes: [
				.font: font
			])
	}
}
