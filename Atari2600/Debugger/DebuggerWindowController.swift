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
		self.assemblyViewController.$breakpoints
			.sink() { [unowned self] in
				self.updateBreakpointsToolbarItem(breakpoints: $0)
			}.store(in: &self.cancellables)
	}
	
	func updateBreakpointsToolbarItem(breakpoints: [MOS6507.Address]) {
		guard let toolbarItem = self.toolbar.items
			.first(where: { $0.itemIdentifier == .breakpointsItem }) as? NSMenuToolbarItem else {
			return
		}
		
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
		
		toolbarItem.menu = menu
		toolbarItem.isEnabled = breakpoints.count > 0
	}
	
	func createBreakpointMenuItem(breakpoint: MOS6507.Address) -> NSMenuItem {
		let item = NSMenuItem()
		item.tag = breakpoint
		item.attributedTitle = NSAttributedString(
			string: String(address: breakpoint),
			attributes: [
				.font: NSFont.monospacedRegular
			])
		
		item.action = #selector(self.breakpointMenuItemSelected(_:))
		return item
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

private extension NSToolbarItem.Identifier {
	static let breakpointsItem = NSToolbarItem.Identifier("BreakpointsItem")
	static let resetItem = NSToolbarItem.Identifier("ResetItem")
}
