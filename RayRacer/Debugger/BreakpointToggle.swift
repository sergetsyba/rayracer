//
//  BreakpointToggle.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2023.
//

import Cocoa
import CoreGraphics
import CoreText

@IBDesignable class BreakpointToggle: NSControl {
	/// State of this toggle.
	public var state: NSControl.StateValue {
		didSet {
			self.needsDisplay = true
		}
	}
	
	/// Color of this toggle when it's on.
	public var tintColor: NSColor {
		didSet {
			self.needsDisplay = true
		}
	}
	/// Color of the text, displayed on this toggle when its's off.
	public var textColor: NSColor {
		didSet {
			self.needsDisplay = true
		}
	}
	/// Font of the text, displayed on this toggle..
	public override var font: NSFont? {
		didSet {
			self.invalidateIntrinsicContentSize()
			self.needsDisplay = true
		}
	}
	
	/// Insets between the edges of this toggle and text, displayed on it.
	public var insets: NSEdgeInsets {
		didSet {
			self.invalidateIntrinsicContentSize()
			self.needsDisplay = true
		}
	}
	/// Corner radius of this toggle's rectange.
	public var cornerRadius: CGFloat {
		didSet {
			self.invalidateIntrinsicContentSize()
			self.needsDisplay = true
		}
	}
	
	required init?(coder: NSCoder) {
		self.state = .off
		self.tintColor = .controlAccentColor
		self.textColor = .controlTextColor
		
		self.insets = .init(top: 4.0, left: 12.0, bottom: 4.0, right: 4.0)
		self.cornerRadius = 3.0
		
		super.init(coder: coder)
		self.font = .systemRegular
	}
	
	override func prepareForInterfaceBuilder() {
		self.state = .on
		self.stringValue = "$0a4c"
		self.font = .monospacedRegular
	}
}


// MARK: -
// MARK: Autolayout handling
extension BreakpointToggle {
	override var intrinsicContentSize: NSSize {
		var size = self.stringValue.size(withFont: self.font!)
		size += self.insets
		size.width += size.height / 3
		
		return size
	}
}


// MARK: -
// MARK: Drawing
extension BreakpointToggle {
	override func draw(_ dirtyRect: NSRect) {
		super.draw(dirtyRect)
		guard let context: CGContext = .current else {
			return
		}
		
		if self.state == .on {
			self.drawToggle(in: self.bounds, with: context)
		}
		if self.stringValue.count > 0 {
			self.drawText(in: self.bounds, with: context)
		}
	}
	
	private func drawToggle(in rect: CGRect, with context: CGContext) {
		let origin = CGPoint(x: rect.minX, y: rect.midY)
		let pointerWidth = rect.height / 3.0
		
		let corners = [
			CGPoint(x: rect.minX, y: rect.minY),
			CGPoint(x: rect.maxX - pointerWidth, y: rect.minY),
			CGPoint(x: rect.maxX, y: rect.midY),
			CGPoint(x: rect.maxX - pointerWidth, y: rect.maxY),
			CGPoint(x: rect.minX, y: rect.maxY),
			CGPoint(x: rect.minX, y: rect.minY)
		]
		
		context.saveGState()
		context.move(to: origin)
		for index in corners.indices.dropLast() {
			context.addArc(
				tangent1End: corners[index],
				tangent2End: corners[index + 1],
				radius: self.cornerRadius)
		}
		context.addLine(to: origin)
		
		context.setFillColor(self.tintColor.cgColor)
		context.fillPath()
		context.restoreGState()
	}
	
	private func drawText(in rect: CGRect, with context: CGContext) {
		let color: NSColor = self.state == .on
		? .white
		: self.textColor
		
		let string = NSAttributedString(string: self.stringValue, attributes: [
			.font: self.font!,
			.foregroundColor: color
		])
		
		let offset = CGPoint(x: self.insets.left, y: self.insets.bottom)
		let point = rect.origin + offset
		
		context.saveGState()
		string.draw(at: point)
		context.restoreGState()
	}
}


// MARK: -
// MARK: Event management
extension BreakpointToggle {
	override func mouseDown(with event: NSEvent) {
		self.state = self.state == .on ? .off : .on
		self.needsDisplay = true
		self.sendAction(self.action, to: self.target)
	}
}

private extension CGContext {
	func addCorner(to point: CGPoint, radius: CGFloat) {
		var p = self.currentPointOfPath
		p.x = point.x
		self.addLine(to: p)
		
		p.y = point.y
		self.addLine(to: p)
	}
}

private extension CGContext {
	static var current: CGContext? {
		let context: NSGraphicsContext? = .current
		return context?.cgContext
	}
	
	func moveTo(x: CGFloat, y: CGFloat) {
		let point = CGPoint(x: x, y: y)
		self.move(to: point)
	}
	
	func addLineTo(x: CGFloat, y: CGFloat) {
		let point = CGPoint(x: x, y: y)
		self.addLine(to: point)
	}
	
	func addLineTo(dx x: CGFloat) -> Self {
		var point = self.currentPointOfPath
		point.x += x
		self.addLine(to: point)
		
		return self
	}
	
	func addLineTo(dy y: CGFloat) -> Self {
		var point = self.currentPointOfPath
		point.y += y
		self.addLine(to: point)
		
		return self
	}
}


// MARK: -
// MARK: Convenience functionality
private extension CGSize {
	static func + (_ lhs: Self, _ rhs: NSEdgeInsets) -> Self {
		return .init(
			width: lhs.width + rhs.left + rhs.right,
			height: lhs.height + rhs.top + rhs.bottom)
	}
	
	static func += (_ lhs: inout Self, _ rhs: NSEdgeInsets) {
		lhs.height += rhs.top + rhs.bottom
		lhs.width += rhs.left + rhs.right
	}
}

private extension CGPoint {
	static func + (_ lhs: Self, _ rhs: Self) -> Self {
		return .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
	}
	
	static func += (_ lhs: inout Self, _ rhs: Self) {
		lhs.x += rhs.x
		lhs.y += rhs.y
	}
}
