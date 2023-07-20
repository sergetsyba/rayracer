//
//  ScreenView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 16.7.2023.
//

import Cocoa

class ScreenView: NSView {
	var lines: [CGColor] = [] {
		didSet {
			self.needsDisplay = true
		}
	}
	
	override func draw(_ dirtyRect: NSRect) {
		var point1 = NSPoint(x: dirtyRect.minX, y: dirtyRect.minY)
		var point2 = NSPoint(x: dirtyRect.maxX, y: dirtyRect.minY)
		
		for color in self.lines {
			NSColor(cgColor: color)?
				.setStroke()
			
			let path = NSBezierPath()
			path.move(to: point1)
			path.line(to: point2)
			
			path.lineWidth = 1.0
			path.stroke()
			
			point1.y += 1.0
			point2.y += 1.0
		}
	}
}
