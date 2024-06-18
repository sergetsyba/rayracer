//
//  ColumnStackView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 2.1.2024.
//

import Cocoa

class ColumnStackView: NSView {
	private var columnCount: Int = 1
	private var spacing: Double = 12.0
	
	private var bottomContraint: NSLayoutConstraint!
	
	convenience init(_ views: any Sequence<NSView> = []) {
		self.init(frame: .zero)
		self.addSubviews(views)
	}
	
	override var firstBaselineOffsetFromTop: CGFloat {
		return self.subviews.first?
			.firstBaselineOffsetFromTop ?? 0.0
	}
	
	func addSubview(_ view: NSView, columnSpan: Int) {
		//
	}
	
	override func addSubview(_ view: NSView) {
		var constraints: [NSLayoutConstraint]
		if let firstView = self.subviews.first,
		   let lastView = self.subviews.last {
			constraints = [
				view.leadingAnchor.constraint(equalTo: firstView.leadingAnchor),
				view.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: self.spacing),
				view.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor),
				view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
			]
			
			// remove bottom edge alignment of the previous view
			self.removeConstraint(self.bottomContraint)
		} else {
			constraints = [
				view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
				view.topAnchor.constraint(equalTo: self.topAnchor),
				self.trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor),
				view.bottomAnchor.constraint(equalTo: self.bottomAnchor)
			]
		}
		
		super.addSubview(view)
		
		view.translatesAutoresizingMaskIntoConstraints = false
		self.addConstraints(constraints)
		
		// keep reference to the bottom edge alignment of the added view
		self.bottomContraint = constraints.last
	}
}


// MARK: - Convenience functionality
extension NSView {
	func addSubviews(_ views: any Sequence<NSView>) {
		for view in views {
			self.addSubview(view)
		}
	}
}
