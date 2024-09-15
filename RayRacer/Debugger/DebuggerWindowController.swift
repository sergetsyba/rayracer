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
