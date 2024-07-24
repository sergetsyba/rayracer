//
//  RowStackView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 2.1.2024.
//

import Cocoa

class RowStackView: NSView {
	private let spacing: Double = 36.0
	private var trailingConstraint: NSLayoutConstraint!
	
	convenience init(_ views: any Sequence<NSView> = []) {
		self.init(frame: .zero)
		self.addSubviews(views)
	}
	
	override func addSubview(_ view: NSView) {
		var constraints: [NSLayoutConstraint]
		if let lastView = self.subviews.last {
			constraints = [
				view.leadingAnchor.constraint(equalTo: lastView.trailingAnchor, constant: self.spacing),
				view.topAnchor.constraint(equalTo: self.topAnchor),
				view.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
				view.trailingAnchor.constraint(equalTo: self.trailingAnchor)
			]
			
			// remove trailing edge alignment of the previous view
			self.removeConstraint(self.trailingConstraint)
		} else {
			constraints = [
				view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
				view.topAnchor.constraint(equalTo: self.topAnchor),
				view.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor),
				view.trailingAnchor.constraint(equalTo: self.trailingAnchor)
			]
		}
		
		super.addSubview(view)
		
		view.translatesAutoresizingMaskIntoConstraints = false
		self.addConstraints(constraints)
		
		// keep reference to the trailing edge alignment of the added view
		self.trailingConstraint = constraints.last
	}
}
