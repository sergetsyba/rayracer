//
//  AppDelegate.swift
//  RayRacer
//
//  Created by Serge Tsyba on 22.5.2023.
//

import AppKit
import librayracer

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	@IBOutlet private var mainMenuController: MainMenuController!

	private var screenWindowObserver: NSObjectProtocol?
	private var screenWindowController: ScreenWindowController? {
		didSet {
			let center: NotificationCenter = .default
			if let windowController = self.screenWindowController {
				self.screenWindowObserver = center.addObserver(
					forName: NSWindow.willCloseNotification,
					object: windowController.window,
					queue: .main,
					using: { [weak self] _ in self?.screenWindowController = nil })
			} else if let observer = self.screenWindowObserver {
				center.removeObserver(observer)
				self.screenWindowObserver = nil
			}
		}
	}

	private let console = Atari2600()
	private var racer: OpaquePointer!

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
				.cartridges
		}
		set {
			// store up to 10 recently played distinct cartridges
			let cartridges = newValue.removingDuplicates()
				.prefix(10)
			UserDefaults.standard
				.cartridges = Array(cartridges)
		}
	}

	func play(_ cartridge: Cartridge) {
		// pause emulation if it is currently running
		self.screenWindowController?
			.pause(priority: .high)

		// change cartridge
		self.console.cartridge = cartridge
		self.console.reset()
		self.cartridges.insert(cartridge, at: 0)

		if self.screenWindowController == nil {
			self.screenWindowController = ScreenWindowController(console: self.console)
		}

		// show screen and resume emulation
		self.screenWindowController?.showWindow(self)
		self.screenWindowController?
			.resume(priority: .high)
	}

	func stop() {
		// clean up screen, which stops emulation
		self.screenWindowController = nil
		// remove cartridge
		self.console.cartridge = nil
	}
}

protocol CartridgeCollection {
	var cartridges: [Cartridge] { get set }
	func play(_ cartridge: Cartridge)
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

		let response = panel.runModal()
		if let url = panel.url,
		   response == .OK {
			perform(url)
		}
	}
}

extension Array where Element: Equatable {
	func removingDuplicates() -> Self {
		var uniques: Self = []
		for element in self {
			if uniques.contains(where: { $0 == element }) == false {
				uniques.append(element)
			}
		}

		return uniques
	}
}
