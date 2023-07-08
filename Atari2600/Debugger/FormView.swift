//
//  FormView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 7.7.2023.
//

import Cocoa

class FormView: NSView {
	private var labelFont: NSFont = .systemFont(ofSize: .smallFontSize)
	
	private var verticalAnchor: NSLayoutYAxisAnchor!
	private var verticalSpacing: CGFloat = 0.0
	private let horizontalSpacing: CGFloat = 8.0
	
	convenience init(_ entries: [[(String, NSView)]]) {
		self.init(frame: .zero)
		
		self.verticalAnchor = self.topAnchor
		self.verticalSpacing = 0.0
		self.addEntries(entries)
		
		self.addConstraints([
			self.bottomAnchor.constraint(equalTo: self.verticalAnchor)
		])
		self.needsLayout = true
	}
	
	convenience init(_ entries: [(String, NSView)]) {
		self.init([entries])
	}
}


// MARK: -
// MARK: Entry layout
private extension FormView {
	private func addEntries(_ entries: [[(String, NSView)]]) {
		for entries in entries {
			self.addEntries(entries)
			self.verticalSpacing = 8.0
		}
	}
	
	private func addEntries(_ entries: [(String, NSView)]) {
		for (string, view) in entries {
			let label = NSTextField(labelWithString: string)
			label.font = self.labelFont
			
			self.addEntry(label, view)
			self.verticalAnchor = view.bottomAnchor
			self.verticalSpacing = 4.0
		}
	}
	
	private func addEntry(_ label: NSTextField, _ view: NSView) {
		label.translatesAutoresizingMaskIntoConstraints = false
		view.translatesAutoresizingMaskIntoConstraints = false
		
		self.addSubview(label)
		self.addSubview(view)
		self.addConstraints([
			label.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor),
			label.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -self.horizontalSpacing),
			label.firstBaselineAnchor.constraint(equalTo: view.firstBaselineAnchor),
			
			view.leadingAnchor.constraint(equalTo: self.centerXAnchor),
			view.topAnchor.constraint(equalTo: self.verticalAnchor, constant: self.verticalSpacing),
			view.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor)
		])
	}
}


// MARK: -
// MARK: Convenience functionality
private extension CGFloat {
	static let smallFontSize: Self = NSFont.smallSystemFontSize
}
