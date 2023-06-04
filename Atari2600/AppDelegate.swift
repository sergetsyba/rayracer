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
			self.console.memory.rom = data
			self.console.cpu.reset()
//			while true {
//				self.console.cpu.step()
//			}
		} catch {
			// TODO: handle error
			print(error)
		}
	}
	
	@IBAction func resetGame(_ sender: AnyObject) {
		self.console.cpu.reset()
	}
	
	@IBAction func stepMenuItemSelected(_ sender: AnyObject) {
		self.console.cpu.step()
	}
	
	@IBAction func debuggerMenuItemSelected(_ sender: AnyObject) {
		self.debuggerWindowController = DebuggerWindowController(console: self.console)
		self.debuggerWindowController?.window?.delegate = self
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
