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

	private var screenWindowObserver: NSObjectProtocol?
	private var screenWindowController: ScreenWindowController? {
		didSet {
			let center: NotificationCenter = .default
			if let window = self.screenWindowController?.window {
				self.screenWindowObserver = center.addObserver(
					forName: NSWindow.willCloseNotification,
					object: window,
					queue: .main,
					using: { [weak self] _ in self?.stop() })
			} else if let observer = self.screenWindowObserver {
				center.removeObserver(observer)
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
			let distinct = newValue.removingDuplicates()
			UserDefaults.standard
				.cartridges = Array(distinct.prefix(10))
		}
	}

	func play(_ cartridge: Cartridge) {
		// pause emulation if it is currently running
		self.screenWindowController?
			.view?.isPaused = true

		var cartridge = cartridge
		if cartridge.program == nil {
			try! cartridge.load()
		}

		// set up console
		self.console.cartridge = cartridge
		self.console.reset()

		// resume emulation
		if self.screenWindowController == nil {
			self.screenWindowController = ScreenWindowController(console: self.console)
		}

		self.screenWindowController?.showWindow(self)

		// save cartridge in recently opened list
		self.cartridges.insert(cartridge, at: 0)
	}

	func stop() {
		self.screenWindowController = nil

		self.console.cartridge?.program = nil
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
