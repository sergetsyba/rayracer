//
//  RayRacerDelegate.swift
//  RayRacer
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import Metal
import CryptoKit

@main
class RayRacerDelegate: NSObject, NSApplicationDelegate {
	private var windowControllers = Set<NSWindowController>()
	
	private var commandQueue: MTLCommandQueue!
	private var pipelineState: MTLRenderPipelineState!
	
	private(set) var console = Atari2600()
	private var frameRateTimer: Timer?
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		self.initRendering()
		self.initConsole()
	}
	
	private func initRendering() {
		// pick GPU, which currenlt drives the display, instead of creating
		// default Metal device, which would trigger GPU switching
		let displayId = CGDirectDisplayID()
		guard let device = CGDirectDisplayCopyCurrentMetalDevice(displayId),
			  let commandQueue = device.makeCommandQueue(),
			  let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize Metal.")
		}
		
		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = library.makeFunction(name: "make_vertex")
		descriptor.fragmentFunction = library.makeFunction(name: "shade_fragment")
		descriptor.colorAttachments[0]
			.pixelFormat = .bgra8Unorm
		
		guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
			fatalError("Failed to initialize Metal.")
		}
		
		self.commandQueue = commandQueue
		self.pipelineState = pipelineState
	}
	
	private func initConsole() {
		self.console.switches = UserDefaults.standard
			.consoleSwitches
	}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
}


// MARK: -
// MARK: Target actions
extension RayRacerDelegate {
	@IBAction func didSelectDebuggerMenuItem(_ sender: AnyObject) {
		self.showDebugger()
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
}


// MARK: -
// MARK: Main menu management
extension RayRacerDelegate: NSMenuDelegate {
	func menuNeedsUpdate(_ menu: NSMenu) {
		let switches = UserDefaults.standard
			.consoleSwitches
		
		switch menu.identifier {
		case .insertRecentCartridgeMenu:
			self.prepareInsertRecentCartridgeMenuItems(in: menu)
		case .leftDifficultyMenu:
			menu.selectedItemIndex = switches[.difficulty0] ? 1 : 0
		case .rightDifficultyMenu:
			menu.selectedItemIndex = switches[.difficulty1] ? 1 : 0
		case .tvTypeMenu:
			menu.selectedItemIndex = switches[.color] ? 1 : 0
		default:
			break
		}
	}
	
	private func prepareInsertRecentCartridgeMenuItems(in menu: NSMenu) {
		var menuItems = UserDefaults.standard
			.openedFileURLs
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
}

extension RayRacerDelegate: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.identifier {
		case .insertRecentCartridgeMenuItem:
			return UserDefaults.standard
				.openedFileURLs.count > 0
		default:
			return true
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let insertRecentCartridgeMenu = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenu")
	static let insertRecentCartridgeMenuItem = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenuItem")
	
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
				.stepInstructionToolbarItem,
				.stepScanLineToolbarItem,
				.stepFieldToolbarItem,
				.resetToolbarItem:
			return self.console.cartridge != nil
		default:
			return false
		}
	}
}


private extension NSToolbarItem.Identifier {
	static let resumeToolbarItem = NSToolbarItem.Identifier("ResumeToolbarItem")
	static let stepInstructionToolbarItem = NSToolbarItem.Identifier("StepInstructionToolbarItem")
	static let stepScanLineToolbarItem = NSToolbarItem.Identifier("StepScanLineToolbarItem")
	static let stepFieldToolbarItem = NSToolbarItem.Identifier("StepFieldToolbarItem")
	static let resetToolbarItem = NSToolbarItem.Identifier("ResetToolbarItem")
}


// MARK: -
// MARK: Custom functionality
extension RayRacerDelegate {
	func withModalFileOpenPanel(_ perform: (URL) -> Void) {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.canCreateDirectories = false
		panel.directoryURL = UserDefaults.standard
			.openedFileURLs.first
		
		let response = panel.runModal()
		if let url = panel.url,
		   response == .OK {
			perform(url)
		}
	}
	
	private func program(at url: URL) -> (Data, String) {
		guard url.startAccessingSecurityScopedResource(),
			  let data = try? Data(contentsOf: url),
			  let bookmark = try? url.bookmarkData(options: .securityScopeAllowOnlyReadAccess) else {
			// TODO: show error when opening cartridge data fails
			fatalError()
		}
		
		url.stopAccessingSecurityScopedResource()
		UserDefaults.standard
			.addOpenedFileURL(url, bookmark: bookmark)
		
		return (data, url.lastPathComponent)
	}
	
	func showScreen(forProgramAt url: URL) {
		var windowController: NSWindowController! = self.windowControllers
			.first(where: { $0.contentViewController is ScreenViewController })
		
		if windowController == nil {
			windowController = NSWindowController(windowNibName: "ScreenWindow")
			windowController.contentViewController = ScreenViewController(console: self.console, commandQueue: self.commandQueue, pipelineState: self.pipelineState)
		}
		
		let (data, name) = self.program(at: url)
		let viewController = windowController.contentViewController as! ScreenViewController
		windowController.window?
			.title = name
		
		self.console.output = viewController
		self.console.cartridgeData = data
		self.console.reset()
		
		self.showWindow(of: windowController)
		
		self.frameRateTimer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned viewController, windowController] _ in
			let frameRate = Int(viewController.frameRate)
			windowController?.window?
				.title = [name, "(\(frameRate) FPS)"]
				.joined(separator: " ")
		}
	}
	
	private func showDebugger() {
		var windowController: NSWindowController! = self.windowControllers
			.first(where: { $0 is DebuggerWindowController })
		
		if windowController == nil {
			windowController = DebuggerWindowController()
		}
		
		self.console.suspend(priority: .high)
		self.showWindow(of: windowController)
	}
}


// MARK: -
// MARK: Window management
extension RayRacerDelegate: NSWindowDelegate {
	func showWindow(of windowController: NSWindowController) {
		self.windowControllers.insert(windowController)
		windowController.window?.delegate = self
		windowController.window?.makeKeyAndOrderFront(self)
	}
	
	func windowWillClose(_ notification: Notification) {
		if let window = notification.object as? NSWindow {
			self.windowControllers.remove(where: { $0.window == window })
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSMenu {
	var selectedItemIndex: Int? {
		get {
			return self.items
				.firstIndex(where: { $0.state == .on })
		}
		set {
			for (index, item) in self.items.enumerated() {
				item.state = index == newValue ? .on : .off
			}
		}
	}
}

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

private extension String {
	static let tabCharacter = String(String(utf16CodeUnits: [unichar(NSTabCharacter)], count: 1))
}
