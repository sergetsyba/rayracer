//
//  AppDelegate.swift
//  Atari2600
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import CryptoKit
import Atari2600Kit

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	private var windowControllers = Set<NSWindowController>()
	private var console: Atari2600 = .current
	
	private var timer: DispatchSourceTimer?
}


// MARK: -
// MARK: Main menu actions
extension AppDelegate {
	@IBAction func insertCartridgeMenuItemSelected(_ sender: Any) {
		if self.console.cartridge == nil {
			do {
				let url = URL(filePath: "/Users/Serge/Developer/Проекты/Atari2600/Games/RushHour.bin")
				try self.console.insertCartridge(fromFileAt: url)
				
				//				let controller = ScreenWindowController()
				//				controller.window?.title = url.lastPathComponent
				//				self.showWindow(of: controller)
			} catch {
				print(error)
			}
			
		} else {
			self.console.cartridge = nil
			for controller in self.windowControllers {
				if controller is ScreenWindowController {
					controller.window?.close()
				}
			}
		}
	}
	
	@IBAction func resetGameMenuItemSelected(_ sender: AnyObject) {
		self.console.cpu.reset()
	}
	
	@IBAction func resumeMenuItemSelected(_ sender: AnyObject) {
		DispatchQueue.global(qos: .default)
			.async { [unowned self] in
				repeat {
					self.console.stepProgram()
				} while true
			}
		
		//		let queue = DispatchQueue.global(qos: .background)
		//
		//		let timer = DispatchSource.makeTimerSource(queue: queue)
		//		timer.schedule(deadline: .now(), repeating: .microseconds(2))
		//		timer.setEventHandler() { [unowned self] in self.console.step() }
		//
		//		self.timer = timer
		//		self.timer?.resume()
	}
	
	@IBAction func stepProgramMenuItemSelected(_ sender: AnyObject) {
		self.console.stepProgram()
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
}


// MARK: -
// MARK: Convenience functionality
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
