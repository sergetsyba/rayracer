//
//  DebuggerValueCellView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 16.6.2023.
//

import Cocoa

class DebuggerValueCellView: NSTableCellView {
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?.font = .monospacedRegular
	}
}

extension NSUserInterfaceItemIdentifier {
	static let debuggerValueCellView = NSUserInterfaceItemIdentifier("DebuggerValueCellView")
}
