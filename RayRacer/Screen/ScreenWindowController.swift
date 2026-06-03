//
//  ScreenWindowController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 27.5.2026.
//

import Cocoa
import MetalKit
import librayracer

class ScreenWindowController: NSWindowController {
	@IBOutlet var view: MTKView!
	@IBOutlet var label: NSTextField!
	
	private let renderer = Renderer(bufferCount: 3)
	private let console: Atari2600
	private var racer: Racer!
	
	private var timer: Timer!
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init(console: Atari2600) {
		self.console = console
		super.init(window: nil)
	}
	
	override var windowNibName: NSNib.Name? {
		return "ScreenWindow"
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		self.label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
		
		self.view.device = self.renderer.device
		self.view.delegate = self.renderer
		self.view.preferredFramesPerSecond = 60
		
		self.racer = Racer(console: self.console, buffers: self.renderer.buffers)
		self.renderer.delegate = self.racer
		
		self.timer = .scheduledTimer(
			withTimeInterval: 1,
			repeats: true,
			block: self.updateFieldRate(_:))
		
		// pause rendering initially
		// it will resume once window becomes key
		self.view.isPaused = true
	}
	
	func windowWillUnload() {
		self.view.isPaused = true
		self.view.delegate = nil
		
		self.timer.invalidate()
		
		// reassign pointer to racer_thread to avoid capturing self from
		// main actor; destroy racer_thread in a detached task to give
		// racer_thread time to break out of run loop and join its thread
		let racer = self.racer
		Task.detached(priority: .userInitiated) {
			racer_thread_destroy(racer)
		}
	}
	
	private func updateFieldRate(_: Timer) {
		let fieldRate = 1e9 / self.racer.pointee.field_time
		self.label.stringValue = String(format: "%.0f fields/s", fieldRate)
	}
}


// MARK: -
// MARK: Window management
extension ScreenWindowController: NSWindowDelegate {
	func windowDidBecomeKey(_ notification: Notification) {
		guard let window = notification.object as? NSWindow,
			  window == self.window else {
			return
		}
		self.view.isPaused = false
	}
	
	func windowDidResignKey(_ notification: Notification) {
		guard let window = notification.object as? NSWindow,
			  window == self.window else {
			return
		}
		self.view.isPaused = true
	}
}


// MARK: -
// MARK: Field generation
typealias Racer = UnsafeMutablePointer<racer_thread>
extension Racer: RendererDelegate {
	init(console: Atari2600, buffers: [MTLBuffer]) {
		var contents: [UnsafeMutablePointer<UInt8>?] = buffers.map() {
			$0.contents().assumingMemoryBound(to: UInt8.self)
		}
		self = contents.withUnsafeMutableBufferPointer() {
			racer_thread_create(console.console, $0.baseAddress, Int32(buffers.count), buffers[0].length)
		}
	}
	
	func rendererWillBeginRendering(_ renderer: Renderer) -> MTLBuffer? {
		// pause emulation
		racer_thread_pause(self)
		
		let index = Int(self.pointee.draw_buffer_index)
		return renderer.buffers[index]
	}
	
	func rendererDidEndRendering(_ renderer: Renderer) {
		// resume emulation
		racer_thread_resume(self)
	}
}
