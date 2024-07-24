//
//  FormView.swift
//  RayRacer
//
//  Created by Serge Tsyba on 7.7.2023.
//

import Cocoa

class FormView: NSView {
	private var verticalAnchor: NSLayoutYAxisAnchor!
	private var verticalSpacing: CGFloat = 0.0
	private let horizontalSpacing: CGFloat = 8.0
	
	init(_ entries: [[(String, NSView)]]) {
		super.init(frame: .zero)
		
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
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
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
			label.font = .systemRegular
			label.textColor = .secondaryLabelColor
			
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
			self.leadingAnchor.constraint(lessThanOrEqualTo: label.leadingAnchor),
			label.trailingAnchor.constraint(equalTo: view.leadingAnchor, constant: -self.horizontalSpacing),
			label.firstBaselineAnchor.constraint(equalTo: view.firstBaselineAnchor),
			
			self.centerXAnchor.constraint(equalTo: view.leadingAnchor),
			self.verticalAnchor.constraint(equalTo: view.topAnchor, constant: -self.verticalSpacing),
			self.trailingAnchor.constraint(greaterThanOrEqualTo: view.trailingAnchor)
		])
	}
}
