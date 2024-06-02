//
//  DebuggerCellView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 16.6.2023.
//

import Cocoa

class DebuggerCellView: NSTableCellView {
	@IBOutlet private(set) var label: NSTextField!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.label.font = .monospacedRegular
	}
}

extension NSUserInterfaceItemIdentifier {
	static let debuggerCellView = NSUserInterfaceItemIdentifier("DebuggerCellView")
}
