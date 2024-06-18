//
//  NSFont+Constants.swift
//  Atari2600
//
//  Created by Serge Tsyba on 16.6.2023.
//

import Cocoa

extension NSFont {
	static let systemRegular: NSFont = .systemFont(ofSize: .smallSystemFontSize)
	static let systemBold: NSFont = .boldSystemFont(ofSize: .smallSystemFontSize)
	
	static let monospacedRegular: NSFont = .monospacedSystemFont(ofSize: .smallSystemFontSize, weight: .regular)
	static let monospacedBold: NSFont = .monospacedSystemFont(ofSize: .smallSystemFontSize, weight: .bold)
}

private extension CGFloat {
	static let smallSystemFontSize = NSFont.smallSystemFontSize
}
