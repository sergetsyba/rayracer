//
//  AssemblyDataCellView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 16.6.2023.
//

import Cocoa

class AssemblyDataCellView: NSTableCellView {
	@IBOutlet var label: NSTextField!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.label.font = .monospacedRegular
	}
}
