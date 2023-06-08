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
	private let console: Atari2600 = .current
	
	init() {
		super.init(window: nil)
		self.contentViewController = AssemblyViewController()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var windowNibName: NSNib.Name? {
		return "DebuggerWindow"
	}
}

