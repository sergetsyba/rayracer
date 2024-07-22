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
	@IBOutlet private var assemblyViewBox: NSBox!
	@IBOutlet private var systemStateViewBox: NSBox!
	
	private var assemblyViewController = AssemblyViewController()
	private var systemStateViewController = SystemStateViewController()
	
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
	@IBAction func removeAllBreakpointsMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.clearBreakpoints()
	}
	
	@IBAction func breakpointMenuItemSelected(_ sender: NSMenuItem) {
		self.assemblyViewController.showBreakpoint(sender.tag)
	}
	
	@IBAction func resumeProgramMenuItemSelected(_ sender: AnyObject) {
		let breakpoints = self.assemblyViewController.breakpoints
		let queue = DispatchQueue.global(qos: .background)
		queue.async() {
			self.console.resumeProgram(until: breakpoints)
		}
	}
}


// MARK: -
// MARK: UI updates
private extension DebuggerWindowController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .reset:
						self.updateToolbarItems()
					default:
						break
					}
				})
		
		self.cancellables.insert(
			// NOTE: delay lets toolbar item to get deselected
			self.assemblyViewController.$breakpoints
				.delay(for: 0.01, scheduler: RunLoop.current)
				.sink() { [unowned self] in
					self.updateBreakpointsToolbarItemMenu(breakpoints: $0)
				}
		)
	}
	
	func updateToolbarItems() {
		let cartridgeInserted = self.console.cartridge != nil
		self.toolbar[.stepProgramItem]?.isEnabled = cartridgeInserted
		self.toolbar[.stepScanLineItem]?.isEnabled = cartridgeInserted
		self.toolbar[.stepFrameItem]?.isEnabled = cartridgeInserted
		self.toolbar[.resumeItem]?.isEnabled = cartridgeInserted
		self.toolbar[.gameResetItem]?.isEnabled = cartridgeInserted
	}
	
	func updateBreakpointsToolbarItemMenu(breakpoints: [Address]) {
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
	
	func createBreakpointMenuItem(breakpoint: Address) -> NSMenuItem {
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
		case .breakpointsItem:
			// NOTE: NSMenuToolbarItem is not supported in Interface Builder
			let toolbarItem = NSMenuToolbarItem(itemIdentifier: itemIdentifier)
			toolbarItem.image = NSImage(symbolName: "Breakpoint", variableValue: 1.0)
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
			.stepProgramItem,
			.stepScanLineItem,
			.stepFrameItem,
			.gameResetItem,
			.space,
			.flexibleSpace
		]
	}
	
	func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		return [
			.breakpointsItem,
			.space,
			.resumeItem,
			.stepProgramItem,
			.stepScanLineItem,
			.stepFrameItem,
			.flexibleSpace,
			.gameResetItem
		]
	}
}

private extension NSToolbarItem.Identifier {
	static let breakpointsItem = NSToolbarItem.Identifier("BreakpointsToolbarItem")
	static let resumeItem = NSToolbarItem.Identifier("ResumeToolbarItem")
	static let stepProgramItem = NSToolbarItem.Identifier("StepProgramToolbarItem")
	static let stepScanLineItem = NSToolbarItem.Identifier("StepScanLineToolbarItem")
	static let stepFrameItem = NSToolbarItem.Identifier("StepFrameToolbarItem")
	static let gameResetItem = NSToolbarItem.Identifier("GameResetToolbarItem")
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
