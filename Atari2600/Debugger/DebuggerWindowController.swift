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
	
	private var programViewController = ProgramViewController()
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
		
		self.programContainerView.setContentView(self.programViewController.view)
		self.cpuContainerView.setContentView(self.cpuViewController.view, layout: .centerHorizontally)
		self.memoryContainerView.setContentView(self.memoryViewController.view)
		
		self.setUpSinks()
	}
	
	func setUpSinks() {
		// TODO: remove delay before showing program in cartridge event publisher
		self.console.$cartridge
			.delay(for: 0.01, scheduler: RunLoop.current)
			.sink() { [unowned self] in
				if let data = $0 {
					self.programViewController.program = self.console.cpu.decode(data)
					self.console.cpu.reset()
				} else {
					self.programViewController.program = nil
				}
			}.store(in: &self.cancellables)
		
		self.console.cpu.$programCounter
			.sink() { [unowned self] in
				self.programViewController.programAddress = $0
			}.store(in: &self.cancellables)
		
		self.programViewController.$breakpoints
			.sink() { [unowned self] in
				self.toolbar.items[0].isEnabled = $0.count > 0
			}.store(in: &self.cancellables)
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
