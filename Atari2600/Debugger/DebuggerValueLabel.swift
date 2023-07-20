//
//  DebuggerValueLabel.swift
//  Atari2600
//
//  Created by Serge Tsyba on 9.7.2023.
//

import Cocoa

class DebuggerValueLabel: NSTextField {
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.font = .monospacedRegular
	}
}


// MARK: -
// MARK: UI updates
extension DebuggerValueLabel {
	func reset(_ value: String) {
		self.stringValue = value
		self.textColor = .disabledControlTextColor
	}
	
	func update(_ value: String) {
		if self.stringValue != value {
			self.stringValue = value
			self.textColor = .controlTextColor
		}
	}
}
