//
//  DebugSectionTableCellView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 23.6.2024.
//

import Cocoa

class DebugSectionTableCellView: NSTableCellView {
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?.font = .systemBold
	}
}
