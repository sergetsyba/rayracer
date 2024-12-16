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


// MARK: -
// MARK: Convenience functionality
private extension NSColor {
	static let ntscPalette: [simd_float3] = {
		return withUnsafePointer(to: ntsc_palette) {
			let item = $0.pointer(to: \.0)
			return (0..<128)
				.compactMap({ item?[$0] })
				.map({ simd_float3($0) / 255.0 })
		}
	}()
	
	convenience init(ntscColor color: Int) {
		let components = Self.ntscPalette[color / 2]
		self.init(
			red: CGFloat(components.x),
			green: CGFloat(components.y),
			blue: CGFloat(components.z),
			alpha: 1.0)
	}
}
