//
//  DebuggerValueLabel.swift
//  Atari2600
//
//  Created by Serge Tsyba on 9.7.2023.
//

import Cocoa

class DebuggerValueLabel: NSTextField {
	convenience init() {
		self.init(labelWithString: "")
		self.font = .monospacedRegular
	}
	
	override var isEnabled: Bool {
		didSet {
			self.textColor = self.isEnabled
			? .controlTextColor
			: .disabledControlTextColor
		}
	}
}
