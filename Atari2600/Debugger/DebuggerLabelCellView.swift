//
//  DebuggerLabelCellView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 2.6.2024.
//

import Cocoa

class DebuggerLabelCellView: NSTableCellView {
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?.font = .systemFont(ofSize: 11.0)
	}
}

extension NSUserInterfaceItemIdentifier {
	static let debuggerLabelCellView = NSUserInterfaceItemIdentifier("DebuggerLabelCellView")
}
