//
//  DebuggerWindow.swift
//  Atari2600
//
//  Created by Serge Tsyba on 27.5.2023.
//

import AppKit
import Combine
import Atari2600Kit

class DebuggerWindowController: NSWindowController {
	@IBOutlet private var programContainerView: NSView!
	@IBOutlet private var cpuContainerView: NSView!
	@IBOutlet private var memoryContainerView: NSView!
	
	private var programViewController: NSViewController?
	private let cpuViewController = CPUViewController()
	private let memoryViewController = MemoryViewController()
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	init() {
		super.init(window: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var windowNibName: NSNib.Name? {
		return "DebuggerWindow"
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		
		self.console.$cartridge
			.sink() { [unowned self] in
				if let _ = $0 {
					let viewController = AssemblyViewController()
					self.programContainerView.setContentView(viewController.view, layout: .fill)
					self.programViewController = viewController
				} else {
					let viewController = NoProgramViewController()
					self.programContainerView.setContentView(viewController.view, layout: .center)
					self.programViewController = viewController
				}
			}.store(in: &self.cancellables)
		
		self.cpuContainerView.setContentView(
			self.cpuViewController.view, layout: .centerHorizontally)
		
		self.memoryContainerView.setContentView(
			self.memoryViewController.view)
	}
}


// MARK: -
class NoProgramViewController: NSViewController {
	convenience init() {
		self.init(nibName: "NoProgramView", bundle: .main)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSView {
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
