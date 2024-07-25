//
//  AssemblyAddressCellView.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2023.
//

import Cocoa

class AssemblyAddressCellView: NSTableCellView {
	@IBOutlet var toggle: BreakpointToggle!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		self.toggle.tintColor = .systemRed
		self.toggle.font = .monospacedRegular
		self.toggle.insets = NSEdgeInsets(top: 2.0, left: 8.0, bottom: 2.0, right: 4.0)
	}
	
	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			self.toggle.textColor = self.backgroundStyle == .emphasized
			? .alternateSelectedControlTextColor
			: .controlTextColor
		}
	}
}
