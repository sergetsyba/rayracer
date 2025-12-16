//
//  DebuggerWindow.swift
//  RayRacer
//
//  Created by Serge Tsyba on 27.5.2023.
//

import AppKit
import Combine
import librayracer

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
		self.resume(until: {
			let programAddress = $0.ref.pointee.mpu.pointee.program_counter
			return self.assemblyViewController
				.breakpoints
				.contains(Int(programAddress))
		})
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
		
		// when multi-stepper is not shown, create and show it
		if viewController == nil {
			viewController = MultiStepperViewController()
			viewController.handler = { [unowned self] in
				self.resume(step: $0, count: $1)
			}
			
			self.window?
				.addTitlebarAccessoryViewController(viewController)
		}
		
		// forward focus to the text field in multi-stepper view
		self.window?
			.makeFirstResponder(viewController.textField)
	}
	
	private func resume(step: MultiStepperViewController.Step, count: Int) {
		switch step {
		case .instructions:
			self.resume(until: { _ in true }, count: count)
		case .scanLines:
			self.resume(until: { (_, syncCount) in syncCount == count })
		case .fields:
			self.resume(until: { (syncCount, _) in syncCount == count })
		}
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
			return self.console.program != nil
			&& self.console.isSuspended(withPriority: .high)
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
// MARK: Resume/suspend functionality
extension DebuggerWindowController {
	private var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
	}
	
	/// Resumes emulation until the specified condition occurs the specified number of times.
	private func resume(until condition: @escaping (Atari2600) -> Bool, count: Int = 1) {
		let console = self.console
		
		DispatchQueue.global(qos: .userInitiated)
			.async() { [unowned console] in
				var remaining = count
				console.resume(priority: .high, until: (
					{ [unowned console] in
						if console.ref.pointee.mpu.pointee.is_sync
							&& condition(console) {
							remaining -= 1
						}
						return remaining == 0
					},
					{ [unowned self] in
						DispatchQueue.main.async() { [unowned self] in
							NotificationCenter.default
								.post(name: .break, object: self)
						}
					}
				))
			}
	}
	
	/// Resumes emulation until the specified condition, which receives vertical and horizontal sync
	/// counts, is satisified.
	private func resume(until condition: @escaping (_ syncCount: (Int, Int)) -> Bool) {
		let console = self.console
		
		DispatchQueue.global(qos: .userInitiated)
			.async() { [unowned console] in
				let counter = GraphicsSyncCounter()
				counter.output = console.output
				
				console.output = counter
				console.resume(priority: .high, until: (
					{ [unowned console] in
						return console.ref.pointee.mpu.pointee.is_sync
						&& condition(counter.counts)
					},
					{ [unowned console, self] in
						console.output = counter.output
						
						DispatchQueue.main.async() { [unowned self] in
							NotificationCenter.default
								.post(name: .break, object: self)
						}
					}
				))
			}
	}
}

extension Notification.Name {
	static let `break` = Notification.Name("ProgramDidSuspendAtBreakpointNotification")
}


// MARK: -
// MARK: Convenience functionality
private extension racer_mcs6507 {
	var is_sync: Bool {
		return self.is_ready && self.operation_clock == 0
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
