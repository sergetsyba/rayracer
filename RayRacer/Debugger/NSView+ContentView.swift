//
//  NSView+ContentView.swift
//  RayRacer
//
//  Created by Serge Tsyba on 18.6.2023.
//

import Cocoa

extension NSView {
	enum ContentViewLayout {
		case center
		case centerHorizontally
		case fill
	}
	
	func setContentView(_ view: NSView?, layout: ContentViewLayout = .fill) {
		for subview in self.subviews {
			subview.removeFromSuperview()
		}
		guard let view = view else {
			return
		}
		
		self.addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
		
		switch layout {
		case .center:
			self.addConstraints([
				NSLayoutConstraint(item: self, toItem: view, attribute: .leading, relatedBy: .lessThanOrEqual),
				NSLayoutConstraint(item: self, toItem: view, attribute: .top, relatedBy: .lessThanOrEqual),
				NSLayoutConstraint(item: self, toItem: view, attribute: .trailing, relatedBy: .greaterThanOrEqual),
				NSLayoutConstraint(item: self, toItem: view, attribute: .bottom, relatedBy: .greaterThanOrEqual),
				NSLayoutConstraint(item: self, toItem: view, attribute: .centerX),
				NSLayoutConstraint(item: self, toItem: view, attribute: .centerY)
			])
			
		case .centerHorizontally:
			self.addConstraints([
				NSLayoutConstraint(item: self, toItem: view, attribute: .leading, relatedBy: .lessThanOrEqual),
				NSLayoutConstraint(item: self, toItem: view, attribute: .top),
				NSLayoutConstraint(item: self, toItem: view, attribute: .trailing, relatedBy: .greaterThanOrEqual),
				NSLayoutConstraint(item: self, toItem: view, attribute: .bottom),
				NSLayoutConstraint(item: self, toItem: view, attribute: .centerX)
			])
			
		case .fill:
			self.addConstraints([
				NSLayoutConstraint(item: self, toItem: view, attribute: .leading),
				NSLayoutConstraint(item: self, toItem: view, attribute: .top),
				NSLayoutConstraint(item: self, toItem: view, attribute: .trailing),
				NSLayoutConstraint(item: self, toItem: view, attribute: .bottom)
			])
		}
	}
}

private extension NSLayoutConstraint {
	convenience init(item item1: Any, toItem item2: Any, attribute: NSLayoutConstraint.Attribute, relatedBy relation: NSLayoutConstraint.Relation = .equal) {
		self.init(item: item1, attribute: attribute, relatedBy: relation, toItem: item2, attribute: attribute, multiplier: 1.0, constant: 0.0)
	}
}
