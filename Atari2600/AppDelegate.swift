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
				let url = URL(gameNamed: "Fantastic Voyage")
				try self.console.insertCartridge(fromFileAt: url)
				self.console.reset()
				
				let controller = ScreenWindowController()
				controller.window?.title = url.lastPathComponent
				self.showWindow(of: controller)
				self.resumeMenuItemSelected(self)
			} catch {
				print(error)
			}
		}
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

private extension URL {
	init(gameNamed name: String) {
		self = URL(filePath: .projectPath)
			.appending(path: "Games")
			.appending(path: "\(name).bin")
	}
}

private extension String {
	static let projectPath: String = {
		let range = #file.range(of: "Atari2600")
		let path = #file.prefix(upTo: range!.upperBound)
		return String(path)
	}()
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
