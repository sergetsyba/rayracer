//
//  AppDelegate.swift
//  RayRacer
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import CryptoKit
import RayRacerKit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	private var windowControllers = Set<NSWindowController>()
	private var console: Atari2600? = .current
	
	private var defaults: UserDefaults = .standard
	private var timer: DispatchSourceTimer?
}


// MARK: -
// MARK: Target actions
extension AppDelegate {
	@IBAction func didSelectInsertCartridgeMenuItem(_ sender: AnyObject) {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.canCreateDirectories = false
		panel.directoryURL = self.defaults.openedFileURLs.first
		
		let response = panel.runModal()
		guard let url = panel.url,
			  response == .OK else {
			return
		}
		
		self.openFile(at: url)
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
	
	@IBAction func didSelectResetMenuItem(_ sender: AnyObject) {
		self.console?.reset()
	}
	
	private func didSelectConsoleSwitchesMenuItem(_ menuItem: NSMenuItem, for switch: Atari2600.Switches) {
		// menu items for `on` switch values appear at the top of the menu
		let on = menuItem.menu?
			.index(of: menuItem) == 0
		
		self.console?.setSwitch(`switch`, on: on)
		// TODO: -
//		self.defaults.consoleSwitches = self.console?.switches
	}
}

extension AppDelegate {
	@IBAction func didSelectGameResumeMenuItem(_ sender: AnyObject) {
		if let console = self.console {
			let identifier = console.gameIdentifier!
			let breakpoints = self.defaults.breakpoints(forGameIdentifier: identifier)
			console.resumeProgram(until: breakpoints)
		}
	}
	
	@IBAction func didSelectStepProgramMenuItem(_ sender: AnyObject) {
		self.console?.stepProgram()
	}
	
	@IBAction func didSelectStepScanLineMenuItem(_ sender: AnyObject) {
		self.console?.stepScanLine()
	}
	
	@IBAction func didSelectStepFrameMenuItem(_ sender: AnyObject) {
		self.console?.stepFrame()
	}
	
	@IBAction func didSelectDebuggerMenuItem(_ sender: AnyObject) {
		let windowController = DebuggerWindowController()
		self.showWindow(of: windowController)
	}
}


// MARK: -
// MARK: Window management
extension AppDelegate: NSWindowDelegate {
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
	
	func openFile(at url: URL) {
		guard let data = try? Data(contentsOfSecurityScopedResourceAt: url) else {
			// TODO: show error when opening cartridge data fails
			fatalError()
		}
		
		let controller = ScreenWindowController()
		controller.window?.title = url.lastPathComponent
		
		let console = Atari2600()
		console.tia.screen = controller
		console.switches = self.defaults.consoleSwitches
		console.insertCartridge(data)
		console.reset()
		
		self.console = console
		self.showWindow(of: controller)
		self.defaults.addOpenedFileURL(url)
	}
}


// MARK: -
// MARK: Main menu management
extension AppDelegate: NSMenuDelegate {
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

extension AppDelegate: NSMenuItemValidation {
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
extension AppDelegate: NSToolbarItemValidation {
	func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
		switch item.itemIdentifier {
		case .resumeToolbarItem,
				.stepProgramToolbarItem,
				.stepScanLineToolbarItem,
				.stepFrameToolbarItem,
				.gameResetToolbarItem:
			return self.console?
				.cartridge != nil
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
// MARK: Preference management
private extension String {
	static let consoleSwitches = "ConsoleSwitches"
	static let openedFileBookmarks = "OpenedFileBookmarks"
}

private extension UserDefaults {
	var consoleSwitches: Atari2600.Switches {
		get {
			// by default, TV type is set to `color` and both difficulties
			// to `advanced`
			let value = self.object(forKey: .consoleSwitches) as? Int ?? 0xc8
			return Atari2600.Switches(rawValue: value)
		}
		set {
			self.setValue(newValue.rawValue, forKey: .consoleSwitches)
		}
	}
	
	var openedFileURLs: [URL] {
		// show up to 10 recently opened files
		return self.openedFileBookmarks
			.prefix(10)
			.map({ $0.0 })
	}
	
	func addOpenedFileURL(_ url: URL) {
		guard let data = try? url.bookmarkData(options: .readOnlySecurityScope) else {
			return
		}
		
		// read bookmark data in user defaults, excluding bookmark data of
		// the new URL; read bookmark data of 9 recently opened files to
		// limit the result to 10, once the new data is added
		var defaultsData = self.openedFileBookmarks
			.filter({ $0.0 != url })
			.prefix(9)
			.map({ $0.1 })
		
		// prepend bookmark data of the new URL at the beginning and write
		// bookmark data to user defaults
		defaultsData.insert(data, at: 0)
		self.setValue(defaultsData, forKey: .openedFileBookmarks)
	}
	
	func clearOpenedFileURLs() {
		self.removeObject(forKey: .openedFileBookmarks)
	}
	
	private var openedFileBookmarks: [(URL, Data)] {
		guard let data = self.value(forKey: .openedFileBookmarks) as? [Data] else {
			return []
		}
		
		// resolve file URLs from bookmark data and only keep unique ones
		var bookmarks: [(URL, Data)] = []
		for data in data {
			var stale = false
			
			// resolve file URLs from bookmark data and only keep unique ones
			if let url = try? URL(resolvingBookmarkData: data, options: .securityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
			   bookmarks.contains(where: { $0.0 == url }) == false {
				bookmarks.append((url, data))
			}
			
			if stale {
				// TODO: update opened file URL stale bookmark
			}
		}
		
		return bookmarks
	}
}

private extension URL.BookmarkCreationOptions {
	static let readOnlySecurityScope: Self = [
		.withSecurityScope,
		.securityScopeAllowOnlyReadAccess
	]
}

private extension URL.BookmarkResolutionOptions {
	static let securityScope: Self = [
		.withSecurityScope,
		.withoutUI
	]
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
	static let current = Atari2600()
	
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
