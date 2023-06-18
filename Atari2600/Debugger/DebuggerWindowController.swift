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
	@IBOutlet private var toolbar: NSToolbar!
	
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
					
					viewController.$breakpoints.sink() { [unowned self] in
						self.window?.toolbar?.items[0].isEnabled = $0.count > 0
					}.store(in: &self.cancellables)
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
// MARK: Toolbar management
extension DebuggerWindowController: NSToolbarDelegate {
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		switch itemIdentifier {
		case .breakpointsItem:
			let item = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
			item.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
			item.label = "Breakpoints"
			item.isEnabled = false
			
			return item
			
		case .resetItem:
			let item = NSToolbarItem(itemIdentifier: itemIdentifier)
			item.image = NSImage(systemSymbolName: "arrowtriangle.backward.circle", accessibilityDescription: nil)
			item.label = "Reset"
			
			return item
			
		default:
			return nil
		}
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.resetItem
		]
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.flexibleSpace,
			.resetItem
		]
	}
}

extension DebuggerWindowController: NSToolbarItemValidation {
	func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
		print(item.itemIdentifier)
		switch item.itemIdentifier {
		case .breakpointsItem:
			return false
		default:
			return true
		}
	}
}

private extension NSToolbarItem.Identifier {
	static let breakpointsItem = NSToolbarItem.Identifier("BreakpointsItem")
	static let resetItem = NSToolbarItem.Identifier("ResetItem")
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
