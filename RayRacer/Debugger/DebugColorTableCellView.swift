//
//  GraphicsColorCellView.swift
//  RayRacer
//
//  Created by Serge Tsyba on 19.6.2024.
//

import Cocoa
import RayRacerKit

class DebugColorTableCellView: NSTableCellView {
	@IBOutlet var colorView: NSView?
	
	var colorValue: (String, Int) {
		get { fatalError() }
		set {
			let formatted = String(format: "%02x", newValue.1)
			let color = NSColor(ntscColor: newValue.1)
			
			self.textField?.stringValue = "\(newValue.0) = \(formatted)"
			self.colorView?.layer?.backgroundColor = color.cgColor
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.colorView?.wantsLayer = true
		self.colorView?.layer?.cornerRadius = 1.5
		self.textField?.font = .systemRegular
	}
}
