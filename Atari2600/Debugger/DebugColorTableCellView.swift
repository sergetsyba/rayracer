//
//  GraphicsColorCellView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 19.6.2024.
//

import Cocoa
import Atari2600Kit


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
		self.colorView?.layer?.cornerRadius = 2.5
		self.textField?.font = .systemRegular
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSColor {
	convenience init(ntscColor color: Int) {
		let index = (color / 2) * 3
		
		self.init(
			red: CGFloat(ntscPalette[index]) / 255.0,
			green: CGFloat(ntscPalette[index + 1]) / 255.0,
			blue: CGFloat(ntscPalette[index + 2]) / 255.0,
			alpha: 1.0)
	}
}
