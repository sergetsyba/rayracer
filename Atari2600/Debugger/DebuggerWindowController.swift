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
	
	@IBOutlet private var assemblyContainerView: NSView!
	@IBOutlet private var cpuContainerView: NSView!
	@IBOutlet private var memoryContainerView: NSView!
	
	private var assemblyViewController = AssemblyViewController()
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
		
		self.assemblyContainerView.setContentView(self.assemblyViewController.view)
		self.cpuContainerView.setContentView(self.cpuViewController.view, layout: .centerHorizontally)
		self.memoryContainerView.setContentView(self.memoryViewController.view)
		
		self.setUpSinks()
	}
}


// MARK: -
// MARK: Target actions
private extension DebuggerWindowController {
	@objc func removeAllBreakpointsMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.breakpoints = []
	}
	
	@objc func breakpointMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.scrollTo(address: sender.tag)
	}
}


// MARK: -
// MARK: UI updates
private extension DebuggerWindowController {
	func setUpSinks() {
		self.console.$cartridge
			.sink() { [unowned self] data in
				self.toolbar[.resetItem]?
					.isEnabled = data != nil
			}.store(in: &self.cancellables)
		
		// NOTE: delay lets toolbar item to get deselected
		self.assemblyViewController.$breakpoints
			.delay(for: 0.01, scheduler: RunLoop.current)
			.sink() { [unowned self] in
				self.updateBreakpointsToolbarItemMenu(breakpoints: $0)
			}.store(in: &self.cancellables)
	}
	
	func updateBreakpointsToolbarItemMenu(breakpoints: [MOS6507.Address]) {
		let removeAllMenuItem = NSMenuItem(
			title: "Remove All",
			action: #selector(self.removeAllBreakpointsMenuItemSelected(_:)),
			keyEquivalent: "")
		
		let menu = NSMenu()
		menu.items = [
			removeAllMenuItem,
			.separator()
		]
		
		breakpoints.map() { self.createBreakpointMenuItem(breakpoint: $0) }
			.sorted(by: { $0.tag < $1.tag })
			.forEach(menu.addItem(_:))
		
		let toolbarItem = self.toolbar[.breakpointsItem] as? NSMenuToolbarItem
		toolbarItem?.menu = menu
		toolbarItem?.isEnabled = breakpoints.count > 0
	}
	
	func createBreakpointMenuItem(breakpoint: MOS6507.Address) -> NSMenuItem {
		let menuItem = NSMenuItem()
		menuItem.tag = breakpoint
		menuItem.attributedTitle = NSAttributedString(
			string: String(address: breakpoint),
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
		case .breakpointsItem:
			// NOTE: NSMenuToolbarItem is not supported in Interface Builder
			let toolbarItem = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
			toolbarItem.label = "Breakpoints"
			toolbarItem.isEnabled = false
			
			return toolbarItem
			
		default:
			// NOTE: all other toolbar items are loaded from Xib
			return nil
		}
	}
	
	func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.resumeItem,
			.stepItem,
			.resetItem,
			.space,
			.flexibleSpace
		]
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.space,
			.resumeItem,
			.stepItem,
			.flexibleSpace,
			.resetItem
		]
	}
}

private extension NSToolbarItem.Identifier {
	static let breakpointsItem = NSToolbarItem.Identifier("BreakpointsItem")
	static let resumeItem = NSToolbarItem.Identifier("ResumeItem")
	static let stepItem = NSToolbarItem.Identifier("StepItem")
	static let resetItem = NSToolbarItem.Identifier("ResetItem")
}


// MARK: -
// MARK: Convenience functionality
private extension NSToolbar {
	subscript (identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
		return self.items.first(where: { $0.itemIdentifier == identifier })
	}
}
