//
//  String+Extensions.swift
//  Atari2600
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
