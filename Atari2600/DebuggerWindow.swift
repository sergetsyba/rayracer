//
//  DebuggerWindow.swift
//  Atari2600
//
//  Created by Serge Tsyba on 27.5.2023.
//

import AppKit
import SwiftUI
import Atari2600Kit

class DebuggerWindowController: NSWindowController {
	var console: Atari2600
	
	init(console: Atari2600) {
		self.console = console
		super.init(window: nil)
		
		self.contentViewController = NSHostingController(
			rootView: DebuggerView(console: console)
				.frame(width: 400, height: 600))
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var windowNibName: NSNib.Name? {
		return "DebuggerWindow"
	}
}
