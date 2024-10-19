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
		
		// breakpoints toolbar items is a NSToolbarMenuItem, which is not
		// supported in NIBs; inserting the item manually modifies all toolbar
		// instances and will crash when attempting to insert again
		if self.toolbar.items
			.contains(where: { $0.itemIdentifier == .breakpointsToolbarItem }) == false {
			self.toolbar.insertItem(withItemIdentifier: .breakpointsToolbarItem, at: 0)
		}
		
		self.assemblyViewBox.contentView = self.assemblyViewController.view
		self.assemblyViewBox.contentView?
			.maskLayerToBounds(cornerRadius: NSBox.defaultCornerRaius)
		
		self.systemStateViewBox.contentView = self.systemStateViewController.view
		self.systemStateViewBox.contentView?
			.maskLayerToBounds(cornerRadius: NSBox.defaultCornerRaius)
		
		self.setUpSinks()
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
		self.resume()
	}
	
	@IBAction func didSelectStepCPUInstructionMenuItem(_ sender: AnyObject) {
		self.resume(step: .instructions, count: 1)
	}
	
	@IBAction func didSelectStepTVScanLineMenuItem(_ sender: AnyObject) {
		self.resume(step: .scanLines, count: 1)
	}
	
	@IBAction func didSelectStepTVFieldMenuItem(_ sender: AnyObject) {
		self.resume(step: .fields, count: 1)
	}
	
	@IBAction func didSelectStepMultipleMenuItem(_ sender: NSMenuItem) {
		var viewController: MultiStepperViewController! = self.window?
			.titlebarAccessoryViewControllers.first as? MultiStepperViewController
		
		if viewController == nil {
			viewController = MultiStepperViewController()
			viewController.handler = self.resume(step:count:)
			self.window?
				.addTitlebarAccessoryViewController(viewController)
		}
		
		viewController.becomeFirstResponder()
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
		
		let toolbarItem = self.toolbar.menuItem(withIdentifier: .breakpointsToolbarItem)
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

extension DebuggerWindowController: NSToolbarItemValidation {
	func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
		switch item.itemIdentifier {
		case .gameResumeToolbarItem,
				.stepCPUInstructionToolbarItem,
				.stepTVScanLineToolbarItem,
				.stepTVFieldToolbarItem:
			return self.console.cartridge != nil
			&& self.console.isSuspended(withCode: 2)
		default:
			return false
		}
	}
}

private extension NSToolbarItem.Identifier {
	static let breakpointsToolbarItem = NSToolbarItem.Identifier("BreakpointsToolbarItem")
	static let gameResumeToolbarItem = NSToolbarItem.Identifier("GameResumeToolbarItem")
	static let stepCPUInstructionToolbarItem = NSToolbarItem.Identifier("StepCPUInstructionToolbarItem")
	static let stepTVScanLineToolbarItem = NSToolbarItem.Identifier("StepTVScanLineToolbarItem")
	static let stepTVFieldToolbarItem = NSToolbarItem.Identifier("StepTVFieldToolbarItem")
	static let consoleResetToolbarItem = NSToolbarItem.Identifier("ConsoleResetToolbarItem")
}


// MARK: -
// MARK: Custom functionality
private extension DebuggerWindowController {
	private var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
	}
	
	private func resume() {
		let console = self.console
		let breakpoints = UserDefaults.standard
			.breakpoints(forGameIdentifier: console.gameIdentifier!)
		
		DispatchQueue.global(qos: .userInitiated)
			.async() { [unowned self] in
				console.resume(breakpoints: breakpoints, completionHandler: self.didReachBreakpoint)
			}
	}
	
	private func resume(step: MultiStepperViewController.Step, count: Int) {
		let console = self.console
		
		switch step {
		case .instructions:
			DispatchQueue.global(qos: .userInitiated)
				.async() { [unowned self] in
					console.resume(instructions: count, completionHandler: self.didReachBreakpoint)
				}
		case .scanLines:
			DispatchQueue.global(qos: .userInitiated)
				.async() { [unowned self] in
					console.resume(scanLines: count, completionHandler: self.didReachBreakpoint)
				}
		case .fields:
			DispatchQueue.global(qos: .userInitiated)
				.async() { [unowned self] in
					console.resume(fields: count, completionHandler: self.didReachBreakpoint)
				}
		}
	}
	
	private func didReachBreakpoint() {
		NotificationCenter.default
			.post(name: .break, object: self)
	}
}

extension Notification.Name {
	static let `break` = Notification.Name("Break")
}


// MARK: -
// MARK: Convenience functionality
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

private extension NSToolbar {
	func menuItem(withIdentifier identifier: NSToolbarItem.Identifier) -> NSMenuToolbarItem? {
		for item in self.items {
			if let menuItem = item as? NSMenuToolbarItem,
			   menuItem.itemIdentifier == identifier {
				return menuItem
			}
		}
		return nil
	}
}
