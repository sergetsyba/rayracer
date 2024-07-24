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
	private var console: Atari2600 = .current
	
	private var defaults: UserDefaults = .standard
	private var timer: DispatchSourceTimer?
}


// MARK: -
// MARK: Main menu actions
extension AppDelegate {
	@IBAction func insertCartridgeMenuItemSelected(_ sender: Any) {
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
	
	@IBAction func insertRecentCartridgeMenuItemSelected(_ sender: NSMenuItem) {
		let url = sender.representedObject as! URL
		self.openFile(at: url)
	}
	
	@IBAction func clearInsertRecentCartridgeMenuItemSelected(_ sender: NSMenuItem) {
		self.defaults.clearOpenedFileURLs()
	}
	
	@IBAction func resetGameMenuItemSelected(_ sender: AnyObject) {
		self.console.reset()
	}
	
	@IBAction func resumeMenuItemSelected(_ sender: AnyObject) {
		let queue = DispatchQueue.global(qos: .background)
		
		let timer = DispatchSource.makeTimerSource(queue: queue)
		timer.schedule(deadline: .now(), repeating: .microseconds(2))
		timer.setEventHandler() { [unowned self] in self.console.stepProgram() }
		
		self.timer = timer
		self.timer?.resume()
	}
	
	@IBAction func stepProgramMenuItemSelected(_ sender: AnyObject) {
		self.console.stepProgram()
	}
	
	@IBAction func stepScanLineMenuItemSelected(_ sender: AnyObject) {
		self.console.stepScanLine()
	}
	
	@IBAction func stepFrameMenuItemSelected(_ sender: AnyObject) {
		self.console.stepFrame()
	}
	
	@IBAction func debuggerMenuItemSelected(_ sender: AnyObject) {
		let windowController = DebuggerWindowController()
		self.showWindow(of: windowController)
	}
}


// MARK: -
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
		
		self.console.insertCartridge(data)
		self.console.reset()
		self.defaults.addOpenedFileURL(url)
		
		let controller = ScreenWindowController()
		controller.window?.title = url.lastPathComponent
		self.showWindow(of: controller)
	}
}


// MARK: -
// MARK: Menu management
extension AppDelegate: NSMenuDelegate {
	func menuNeedsUpdate(_ menu: NSMenu) {
		if menu.identifier == .insertRecentCartridgeMenu {
			menu.items = self.prepareInsertRecentCartridgeMenuItems()
		}
	}
	
	private func prepareInsertRecentCartridgeMenuItems() -> [NSMenuItem] {
		var menuItems = self.defaults.openedFileURLs
			.map() {
				let menuItem = NSMenuItem()
				menuItem.title = $0.lastPathComponent
				menuItem.action = #selector(self.insertRecentCartridgeMenuItemSelected(_:))
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
				action: #selector(self.clearInsertRecentCartridgeMenuItemSelected(_:)),
				keyEquivalent: ""))
		}
		
		return menuItems
	}
}

extension AppDelegate: NSMenuItemValidation {
	func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
		switch menuItem.identifier {
		case .insertRecentCartridgeMenuItem:
			return self.defaults.openedFileURLs.count > 0
		case .gameResetMenuItem:
			return self.console.cartridge != nil
		default:
			return true
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let insertRecentCartridgeMenuItem = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenuItem")
	static let gameResetMenuItem = NSUserInterfaceItemIdentifier("GameResetMenuItem")
	static let insertRecentCartridgeMenu = NSUserInterfaceItemIdentifier("InsertRecentCartridgeMenu")
}


// MARK: -
// MARK: Preference management
private extension String {
	static let openedFileBookmarks = "OpenedFileBookmarks"
}

private extension UserDefaults {
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
	
	var gameIdentifier: String {
		return Insecure.MD5
			.hash(data: self.cartridge!)
			.map() { String(format: "%02x", $0) }
			.joined()
	}
}
