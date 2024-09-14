//
//  RayRacerDelegate.swift
//  RayRacer
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import Metal
import CryptoKit
import RayRacerKit

@main
class RayRacerDelegate: NSObject, NSApplicationDelegate {
	private var windowControllers = Set<NSWindowController>()
	private var defaults: UserDefaults = .standard
	private var notifications: NotificationCenter = .default
	
	private var commandQueue: MTLCommandQueue!
	private var pipelineState: MTLRenderPipelineState!
	
	private(set) var console = Atari2600()
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		guard let device = MTLCreateSystemDefaultDevice(),
			  let commandQueue = device.makeCommandQueue(),
			  let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize Metal.")
		}
		
		let descriptor = self.makeRenderPipelineDescriptor(library: library)
		guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
			fatalError("Failed to initialize Metal.")
		}
		
		self.commandQueue = commandQueue
		self.pipelineState = pipelineState
	}
	
	private func makeRenderPipelineDescriptor(library: MTLLibrary) -> MTLRenderPipelineDescriptor {
		let descirptor = MTLRenderPipelineDescriptor()
		descirptor.vertexFunction = library.makeFunction(name: "make_vertex")
		descirptor.fragmentFunction = library.makeFunction(name: "shade_fragment")
		descirptor.colorAttachments[0]
			.pixelFormat = .bgra8Unorm
		
		return descirptor
	}
}


// MARK: -
// MARK: Target actions
extension RayRacerDelegate {
	@IBAction func didSelectInsertCartridgeMenuItem(_ sender: AnyObject) {
		self.withModalFileOpenPanel({
			self.openFile(at: $0)
		})
	}
	
	@IBAction func didSelectInsertRecentCartridgeMenuItem(_ sender: NSMenuItem) {
		let url = sender.representedObject as! URL
		self.openFile(at: url)
	}
	
	@IBAction func didSelectClearInsertRecentCartridgeMenuItem(_ sender: NSMenuItem) {
		self.defaults.clearOpenedFileURLs()
	}
	
	@IBAction func didSelectLeftDifficultyMenuItem(_ sender: NSMenuItem) {
		self.didSelectConsoleSwitchesMenuItem(sender, for: .difficulty0)
	}
	
	@IBAction func didSelectRightDifficultyMenuItem(_ sender: NSMenuItem) {
		self.didSelectConsoleSwitchesMenuItem(sender, for: .difficulty1)
	}
	
	@IBAction func didSelectTVTypeMenuItem(_ sender: NSMenuItem) {
		self.didSelectConsoleSwitchesMenuItem(sender, for: .color)
	}
	
	@IBAction func didSelectGameSelectMenuItem(_ sender: NSMenuItem) {
	}
	
	@IBAction func didSelectGameResetMenuItem(_ sender: AnyObject) {
	}
	
	private func didSelectConsoleSwitchesMenuItem(_ menuItem: NSMenuItem, for switch: Atari2600.Switches) {
		// menu items for `on` switch values appear at the top of the menu
		let on = menuItem.menu?
			.index(of: menuItem) == 0
		
		self.console.setSwitch(`switch`, on: on)
		self.defaults.consoleSwitches = self.console.switches
	}
	
	@IBAction func didSelectResetMenuItem(_ sender: AnyObject) {
		self.console.reset()
		self.postNotification(.reset)
	}
	
	@IBAction func didSelectGameResumeMenuItem(_ sender: AnyObject) {
		// TODO: resume game
	}
	
	@IBAction func didSelectStepInstructionMenuItem(_ sender: AnyObject) {
		self.console.stepInstruction()
		self.postNotification(.break)
	}
	
	@IBAction func didSelectStepScanLineMenuItem(_ sender: AnyObject) {
		self.console.stepScanLine()
		self.postNotification(.break)
	}
	
	@IBAction func didSelectStepFieldMenuItem(_ sender: AnyObject) {
		self.console.stepField()
		self.postNotification(.break)
	}
	
	@IBAction func didSelectDebuggerMenuItem(_ sender: AnyObject) {
		let windowController = DebuggerWindowController()
		self.showWindow(of: windowController)
	}
}

private extension RayRacerDelegate {
	func postNotification(_ name: Notification.Name) {
		NotificationCenter.default
			.post(name: name, object: self)
	}
}

extension Notification.Name {
	static let reset = Notification.Name("Break")
	static let `break` = Notification.Name("Break")
}


// MARK: -
// MARK: Window management
extension RayRacerDelegate: NSWindowDelegate {
	func showWindow(of windowController: NSWindowController) {
		windowController.window?.delegate = self
		windowController.showWindow(self)
		self.windowControllers.insert(windowController)
	}
	
	func windowWillClose(_ notification: Notification) {
		if let window = notification.object as? NSWindow {
			self.windowControllers.remove(where: { $0.window == window })
		}
	}
}


// MARK: -
// MARK: Main menu management
extension RayRacerDelegate: NSMenuDelegate {
	func menuNeedsUpdate(_ menu: NSMenu) {
		switch menu.identifier {
		case .insertRecentCartridgeMenu:
			self.prepareInsertRecentCartridgeMenuItems(in: menu)
		case .leftDifficultyMenu:
			self.prepareConsoleSwitchesMenuItems(in: menu, for: .difficulty0)
		case .rightDifficultyMenu:
			self.prepareConsoleSwitchesMenuItems(in: menu, for: .difficulty1)
		case .tvTypeMenu:
			self.prepareConsoleSwitchesMenuItems(in: menu, for: .color)
			
		default:
			break
		}
	}
	
	private func prepareInsertRecentCartridgeMenuItems(in menu: NSMenu) {
		var menuItems = self.defaults.openedFileURLs
			.map() {
				let menuItem = NSMenuItem()
				menuItem.title = $0.lastPathComponent
				menuItem.action = #selector(self.didSelectInsertRecentCartridgeMenuItem(_:))
				menuItem.representedObject = $0
				
				return menuItem
			}
		
		// when there's at least one recently opened file
		if let menuItem = menuItems.first {
			// add key shortcut for opening the most recently opened file
			menuItem.keyEquivalentModifierMask = [.command, .option]
			menuItem.keyEquivalent = "o"
			
			// add a separator and a menu item for clearing the recently
			// opened files menu
			menuItems.append(.separator())
			menuItems.append(NSMenuItem(
				title: "Clear Menu",
				action: #selector(self.didSelectClearInsertRecentCartridgeMenuItem(_:)),
				keyEquivalent: ""))
		}
		
		menu.items = menuItems
	}
	
	private func prepareConsoleSwitchesMenuItems(in menu: NSMenu, for value: Atari2600.Switches) {
		// menu items for `on` switch values are at the top of the menu
		let selectedIndex = self.defaults.consoleSwitches
			.contains(value) ? 0 : 1
		
		for (index, menuItem) in menu.items.enumerated() {
			menuItem.state = index == selectedIndex ? .on : .off
		}
	}
}

extension RayRacerDelegate: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.identifier {
		case .insertRecentCartridgeMenuItem:
			return self.defaults.openedFileURLs.count > 0
		default:
			return true
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let insertRecentCartridgeMenuItem = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenuItem")
	static let gameResetMenuItem = NSUserInterfaceItemIdentifier("GameResetMenuItem")
	static let insertRecentCartridgeMenu = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenu")
	
	static let leftDifficultyMenu = NSUserInterfaceItemIdentifier("LeftDifficultyMenu")
	static let rightDifficultyMenu = NSUserInterfaceItemIdentifier("RightDifficultyMenu")
	static let tvTypeMenu = NSUserInterfaceItemIdentifier("TVTypeMenu")
}


// MARK: -
// MARK: Toolbar item management
extension RayRacerDelegate: NSToolbarItemValidation {
	func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
		switch item.itemIdentifier {
		case .resumeToolbarItem,
				.stepProgramToolbarItem,
				.stepScanLineToolbarItem,
				.stepFrameToolbarItem,
				.gameResetToolbarItem:
			return self.console.cartridge != nil
		default:
			return false
		}
	}
}


private extension NSToolbarItem.Identifier {
	static let resumeToolbarItem = NSToolbarItem.Identifier("ResumeToolbarItem")
	static let stepProgramToolbarItem = NSToolbarItem.Identifier("StepProgramToolbarItem")
	static let stepScanLineToolbarItem = NSToolbarItem.Identifier("StepScanLineToolbarItem")
	static let stepFrameToolbarItem = NSToolbarItem.Identifier("StepFrameToolbarItem")
	static let gameResetToolbarItem = NSToolbarItem.Identifier("GameResetToolbarItem")
}


// MARK: -
// MARK: Custom functionality
private extension RayRacerDelegate {
	func withModalFileOpenPanel(_ perform: (URL) -> Void) {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.canCreateDirectories = false
		panel.directoryURL = self.defaults.openedFileURLs.first
		
		let response = panel.runModal()
		if let url = panel.url,
		   response == .OK {
			perform(url)
		}
	}
	
	func openFile(at url: URL) {
		guard let data = try? Data(contentsOfSecurityScopedResourceAt: url) else {
			// TODO: show error when opening cartridge data fails
			fatalError()
		}
		
		let viewController = ScreenViewController(
			commandQueue: self.commandQueue,
			pipelineState: self.pipelineState)
		
		let windowController = NSWindowController(windowNibName: "ScreenWindow")
		windowController.contentViewController = viewController
		windowController.window?
			.title = url.lastPathComponent
		
		self.console.tia.output = viewController
		self.console.switches = self.defaults.consoleSwitches
		self.console.insertCartridge(data)
		self.console.reset()
		self.postNotification(.reset)
		
		self.showWindow(of: windowController)
		self.defaults.addOpenedFileURL(url)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Data {
	enum SecurityScopeError: Error {
		case requestDenied
	}
	
	init(contentsOfSecurityScopedResourceAt url: URL) throws {
		guard url.startAccessingSecurityScopedResource() else {
			throw SecurityScopeError.requestDenied
		}
		defer {
			url.stopAccessingSecurityScopedResource()
		}
		try self.init(contentsOf: url)
	}
}

private extension Set {
	mutating func remove(where condition: (Self.Element) -> Bool) {
		if let index = self.firstIndex(where: condition) {
			self.remove(at: index)
		}
	}
}

extension Atari2600 {
	var gameIdentifier: String? {
		guard let data = self.cartridge else {
			return nil
		}
		
		return Insecure.MD5
			.hash(data: data)
			.map() { String(format: "%02x", $0) }
			.joined()
	}
}
