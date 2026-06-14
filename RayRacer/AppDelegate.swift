//
//  RayRacerDelegate.swift
//  RayRacer
//
//  Created by Serge Tsyba on 22.5.2023.
//

import AppKit
import librayracer

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	@IBOutlet private var mainMenuController: MainMenuController!
	private var screenWindowController: ScreenWindowController?
	private let console = Atari2600()
	
	func applicationDidFinishLaunching(_ notification: Notification) {
		self.mainMenuController.collection = self
		self.mainMenuController.console = self.console
	}
	
	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}
}

// MARK: -
// MARK: Running programs
extension AppDelegate: CartridgeCollection {
	var cartridges: [Cartridge] {
		get {
			UserDefaults.standard
				.openedFileBookmarks
				.compactMap({ try? Cartridge(bookmark: $0) })
		}
		set {
			// store up to 10 recently played distinct cartridges
			UserDefaults.standard
				.openedFileBookmarks = newValue
				.removingDuplicates(where: { $0.name == $1.name })
				.prefix(10)
				.map(\.bookmark)
		}
	}
	
	func play(_ cartridge: Cartridge) {
		// pause emulation if it is currently running
		self.screenWindowController?
			.view?.isPaused = true
		
		// set up console
		self.console.cartridge = cartridge
		self.console.reset()
		
		// resume emulation
		if self.screenWindowController == nil {
			self.screenWindowController = ScreenWindowController(console: self.console)
			self.screenWindowController?
				.window?.delegate = self
		}
		
		self.screenWindowController?.showWindow(self)
		self.screenWindowController?
			.view?.isPaused = false
		
		// save cartridge in recently opened list
		self.cartridges.insert(cartridge, at: 0)
	}
	
	func stop() {
		self.console.cartridge = nil
		self.screenWindowController = nil
	}
}

protocol CartridgeCollection {
	var cartridges: [Cartridge] { get set }
	func play(_ cartridge: Cartridge)
}

// MARK: -
// MARK: Window management
extension AppDelegate: NSWindowDelegate {
	func windowWillClose(_ notification: Notification) {
		if let window = notification.object as? NSWindow,
		   window.windowController == self.screenWindowController {
			self.stop()
		}
	}
}

// MARK: -
// MARK: Convenience functionality
extension NSOpenPanel {
	class func runModal(_ perform: (URL) -> Void) {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.canCreateDirectories = false
		panel.directoryURL = UserDefaults.standard
			.openedFileBookmarks
			.first
			.map({ try? Cartridge(bookmark: $0) })??
			.url
		
		let response = panel.runModal()
		if let url = panel.url,
		   response == .OK {
			perform(url)
		}
	}
}

extension Array {
	func removingDuplicates(where comparator: (Element, Element) -> Bool) -> Self {
		var uniques: Self = []
		for element in self {
			if uniques.contains(where: { comparator(element, $0) }) == false {
				uniques.append(element)
			}
		}
		
		return uniques
	}
}
