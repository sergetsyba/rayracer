//
//  AppDelegate.swift
//  Atari2600
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
	private var debuggerWindowController: NSWindowController?
	
	@IBOutlet var window: NSWindow!
	
	@IBAction func showDebuggerWindow(_ sender: AnyObject) {
		let debuggerView = DebuggerView()
			.frame(width: 400, height: 600)
		
		let viewController = NSHostingController(rootView: debuggerView)
		let debuggerWindow = NSWindow(contentViewController: viewController)
		debuggerWindow.title = "Debugger"
		debuggerWindow.delegate = self
		
		self.debuggerWindowController = NSWindowController(window: debuggerWindow)
		self.debuggerWindowController?.showWindow(nil)
	}
}

extension AppDelegate: NSWindowDelegate {
	func windowWillClose(_ notification: Notification) {
		if let window = notification.object as? NSWindow,
		   window == self.debuggerWindowController?.window {
			self.debuggerWindowController = nil
		}
	}
}
