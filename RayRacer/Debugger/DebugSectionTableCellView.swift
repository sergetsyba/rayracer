//
//  DebugSectionTableCellView.swift
//  RayRacer
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
