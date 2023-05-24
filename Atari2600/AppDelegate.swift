//
//  AppDelegate.swift
//  Atari2600
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import SwiftUI
import Atari2600Kit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	private var debuggerWindowController: NSWindowController?
	private var console = Atari2600()
	
	@IBOutlet var window: NSWindow!
}


// MARK: -
// MARK: Main menu actions
extension AppDelegate {
	@IBAction func insertCartridgeMenuItemSelected(_ sender: NSMenuItem) {
		let url = URL(filePath: "/Users/Serge/Developer/Проекты/Atari2600/ROMS/Pac-Man.bin")
		do {
			let data = try Data(contentsOf: url)
			self.console.insertCartridge(data: data)
		} catch {
			// TODO: handle error
			print(error)
		}
	}
	
	@IBAction func gameResetMenuItemSelected(_ sender: NSMenuItem) {
		self.console.cpu.reset()
	}
	
	@IBAction func debuggerMenuItemSelected(_ sender: AnyObject) {
		let debuggerView = DebuggerView(console: self.console)
			.frame(width: 400, height: 600)
		
		let debuggerViewController = NSHostingController(rootView: debuggerView)
		let debuggerWindow = NSWindow(contentViewController: debuggerViewController)
		debuggerWindow.title = "Debugger"
		debuggerWindow.delegate = self
		
		self.debuggerWindowController = NSWindowController(window: debuggerWindow)
		self.debuggerWindowController?.showWindow(nil)
	}
}


// MARK: -
extension AppDelegate: NSWindowDelegate {
	func windowWillClose(_ notification: Notification) {
		if let window = notification.object as? NSWindow,
		   window == self.debuggerWindowController?.window {
			self.debuggerWindowController = nil
		}
	}
}
