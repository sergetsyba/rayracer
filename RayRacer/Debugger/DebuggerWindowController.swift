//
//  DebuggerWindow.swift
//  RayRacer
//
//  Created by Serge Tsyba on 27.5.2023.
//

import AppKit
import Combine
import RayRacerKit

class DebuggerWindowController: NSWindowController {
	@IBOutlet private var toolbar: NSToolbar!
	@IBOutlet private var assemblyViewBox: NSBox!
	@IBOutlet private var systemStateViewBox: NSBox!
	
	private var assemblyViewController = AssemblyViewController()
	private var systemStateViewController = SystemStateViewController()
	private var cancellables: Set<AnyCancellable> = []
	
	private let defaults: UserDefaults = .standard
	private let notifications: NotificationCenter = .default
	
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
		self.toolbar.insertItem(withItemIdentifier: .breakpointsToolbarItem, at: 0)
		
		self.assemblyViewBox.contentView = self.assemblyViewController.view
		self.assemblyViewBox.contentView?
			.maskLayerToBounds(cornerRadius: NSBox.defaultCornerRaius)
		
		self.systemStateViewBox.contentView = self.systemStateViewController.view
		self.systemStateViewBox.contentView?
			.maskLayerToBounds(cornerRadius: NSBox.defaultCornerRaius)
		
		self.setUpSinks()
		self.window?.becomeKey()
	}
}


// MARK: -
// MARK: Target actions
private extension DebuggerWindowController {
	@IBAction func breakpointMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.showBreakpoint(sender.tag)
	}
	
	@IBAction func removeAllBreakpointsMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.clearBreakpoints()
	}
	
	@IBAction func didSelectGameResumeMenuItem(_ sender: AnyObject) {
		var breakpoints: [Int] = []
		if let identifier = self.console.gameIdentifier {
			breakpoints = self.defaults.breakpoints(forGameIdentifier: identifier)
		}
		
		self.console.resume(until: breakpoints)
		self.notifications.post(name: .break, object: self)
	}
	
	@IBAction func didSelectStepCPUInstructionMenuItem(_ sender: AnyObject) {
		self.stepCPUInstructions(count: 1)
	}
	
	@IBAction func didSelectStepTVScanLineMenuItem(_ sender: AnyObject) {
		self.stepTVScanLines(count: 1)
	}
	
	@IBAction func didSelectStepTVFieldMenuItem(_ sender: AnyObject) {
		self.stepTVFields(count: 1)
	}
	
	@IBAction func didSelectStepMultipleMenuItem(_ sender: NSMenuItem) {
		guard let window = self.window else {
			return
		}
		
		if let viewController = window.titlebarAccessoryViewControllers.first as? MultiStepperViewController {
			// focus on multi-stepper view when it is already shown
			viewController.becomeFirstResponder()
		} else {
			let viewController = self.makeMultiStepperViewController()
			window.addTitlebarAccessoryViewController(viewController)
			viewController.becomeFirstResponder()
		}
	}
	
	private func makeMultiStepperViewController() -> MultiStepperViewController {
		let viewController = MultiStepperViewController()
		viewController.handler = { [unowned self] in
			switch $0 {
			case .step(let step, let count):
				switch step {
				case .instructions:
					self.stepCPUInstructions(count: count)
				case .scanLines:
					self.stepTVScanLines(count: count)
				case .fields:
					self.stepTVFields(count: count)
				}
				
			case .done:
				if let index = self.window?.titlebarAccessoryViewControllers
					.firstIndex(where: { $0 is MultiStepperViewController }) {
					self.window?.removeTitlebarAccessoryViewController(at: index)
				}
			}
		}
		
		return viewController
	}
}


// MARK: -
// MARK: UI updates
private extension DebuggerWindowController {
	func setUpSinks() {
		self.cancellables.insert(
			// NOTE: delay lets toolbar item to get deselected
			self.assemblyViewController.$breakpoints
				.delay(for: 0.01, scheduler: RunLoop.current)
				.sink() { [unowned self] in
					self.updateBreakpointsToolbarItemMenu($0)
				})
	}
	
	func updateBreakpointsToolbarItemMenu(_ breakpoints: [Int]) {
		let menu = NSMenu()
		menu.items = self.createBreakpointMenuItems(breakpoints)
		
		let toolbarItem = self.toolbar[.breakpointsToolbarItem] as? NSMenuToolbarItem
		toolbarItem?.menu = menu
		toolbarItem?.isEnabled = menu.items.count > 0
	}
	
	private func createBreakpointMenuItems(_ breakpoints: [Int]) -> [NSMenuItem] {
		guard breakpoints.count > 0 else {
			return []
		}
		
		var menuItems = breakpoints.sorted()
			.map({ self.createBreakpointMenuItem($0) })
		
		menuItems.append(.separator())
		menuItems.append(NSMenuItem(
			title: "Remove All",
			action: #selector(self.removeAllBreakpointsMenuItemSelected(_:)),
			keyEquivalent: ""))
		
		return menuItems
	}
	
	private func createBreakpointMenuItem(_ breakpoint: Int) -> NSMenuItem {
		let menuItem = NSMenuItem()
		menuItem.tag = breakpoint
		menuItem.attributedTitle = NSAttributedString(
			string: String(format: "$%04x", breakpoint),
			attributes: [
				.font: NSFont.monospacedRegular
			])
		
		menuItem.action = #selector(self.breakpointMenuItemSelected(_:))
		return menuItem
	}
}


// MARK: -
// MARK: Toolbar management
extension DebuggerWindowController: NSToolbarDelegate {
	func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		switch itemIdentifier {
		case .breakpointsToolbarItem:
			// NOTE: NSMenuToolbarItem is not supported in Interface Builder
			let toolbarItem = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem.image = NSImage(symbolName: "Breakpoint", variableValue: 1.0)
			toolbarItem.label = "Breakpoints"
			
			return toolbarItem
			
		default:
			// NOTE: all other toolbar items are loaded from Xib
			return nil
		}
	}
}

private extension NSToolbarItem.Identifier {
	static let breakpointsToolbarItem = NSToolbarItem.Identifier("BreakpointsToolbarItem")
}


// MARK: -
// MARK: Custom functionality
private extension DebuggerWindowController {
	private var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
	}
	
	private func stepCPUInstructions(count: Int) {
		for _ in 0..<count {
			self.console.stepInstruction()
		}
		self.notifications.post(name: .break, object: self)
	}
	
	private func stepTVScanLines(count: Int) {
		for _ in 0..<count {
			self.console.stepScanLine()
		}
		self.notifications.post(name: .break, object: self)
	}
	
	private func stepTVFields(count: Int) {
		for _ in 0..<count {
			self.console.stepField()
		}
		self.notifications.post(name: .break, object: self)
	}
}

extension Notification.Name {
	static let `break` = Notification.Name("Break")
}


// MARK: -
// MARK: Convenience functionality
private extension NSToolbar {
	subscript (identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
		return self.items.first(where: { $0.itemIdentifier == identifier })
	}
}

private extension NSView {
	func maskLayerToBounds(cornerRadius: CGFloat) {
		self.wantsLayer = true
		self.layer?.masksToBounds = true
		self.layer?.cornerRadius = cornerRadius
	}
}

private extension NSBox {
	static let defaultCornerRaius: CGFloat = 4.5
}
