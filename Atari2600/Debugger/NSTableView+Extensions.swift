//
//  NSTableView+Extensions.swift
//  Atari2600
//
//  Created by Serge Tsyba on 29.5.2024.
//

import Cocoa

extension NSTableView {
	func registerNib(named nibName: String, bundle: Bundle = .main, forIdentifier identifier: NSUserInterfaceItemIdentifier) {
		let nib = NSNib(nibNamed: nibName, bundle: bundle)
		self.register(nib, forIdentifier: identifier)
	}
	
	func registerNibs(_ nibs: [NSNib.Name: NSUserInterfaceItemIdentifier], bundle: Bundle = .main) {
		for (name, id) in nibs {
			let nib = NSNib(nibNamed: name, bundle: bundle)
			self.register(nib, forIdentifier: id)
		}
	}
}
