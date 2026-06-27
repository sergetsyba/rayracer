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
	@IBOutlet private var view: MTKView!
	@IBOutlet private var label: NSTextField!

	private let console: Atari2600
	private var racer: OpaquePointer!

	private let renderer = Renderer()
	private let timer = DispatchSource.makeTimerSource(queue: .main)

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	init(console: Atari2600) {
		self.console = console
		super.init(window: nil)

		self.timer.schedule(deadline: .now(), repeating: 1.0)
		self.timer.setEventHandler() { [weak self] in self?.updateFrameRate() }

		let buffer = renderer.buffers[0]
		self.racer = racer_thread_create(self.console.ref, buffer.data, buffer.length)
	}

	deinit {
		racer_thread_destroy(self.racer)
	}

	override var windowNibName: NSNib.Name? {
		return "ScreenWindow"
	}

	private func updateFrameRate() {
		self.label.stringValue = String(format: "%.0f fields/s", self.fieldRate)
	}
}

// MARK: -
// MARK: Window management
extension ScreenWindowController: NSWindowDelegate {
	override func windowDidLoad() {
		super.windowDidLoad()
		self.window?.delegate = self
		self.label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

		self.view.device = self.renderer.device
		self.view.delegate = self.renderer
		self.view.preferredFramesPerSecond = 60

		// pause rendering initially, it will resume once window becomes key
		self.view.isPaused = true
		self.renderer.delegate = self
	}

	func windowWillClose(_ notification: Notification) {
		// clear window delegate so that windowDidResignKey is not called
		self.window?.delegate = nil

		// cancel rendering
		self.view.isPaused = true
		self.view.delegate = nil
		self.renderer.delegate = nil

		// cancel field rate timer; it must be resumed when cancelling
		self.timer.cancel()
	}

	func windowDidBecomeKey(_ notification: Notification) {
		guard let window = notification.object as? NSWindow,
			  window == self.window else {
			return
		}
		self.view.isPaused = false
		self.timer.resume()
	}

	func windowDidResignKey(_ notification: Notification) {
		guard let window = notification.object as? NSWindow,
			  window == self.window else {
			return
		}
		self.view.isPaused = true
		self.timer.suspend()
	}
}

// MARK: -
// MARK: Field rendering
extension ScreenWindowController: RendererDelegate {
	func rendererWillBeginRendering(_ renderer: Renderer) -> MTLBuffer? {
		// ensure emulation has finished producing field data;
		// skip frame otherwise
		guard racer_thread_is_paused(self.racer) else {
			return nil
		}
		return renderer.buffers.first
	}

	func rendererDidEndRendering(_ renderer: Renderer) {
		// resume emulation to produce next field data
		self.resume()
	}
}

extension ScreenWindowController {
	enum PausePriority: UInt8 {
		case low = 0
		case high = 1
	}

	var fieldRate: Double {
		1e9 / Double(racer_thread_get_field_time(self.racer))
	}

	func pause(priority: PausePriority = .low) {
		racer_thread_pause(self.racer, priority.rawValue)
	}

	func resume(priority: PausePriority = .low) {
		racer_thread_resume(self.racer, priority.rawValue)
	}
}

// MARK: -
// MARK: Convenience functionality
extension MTLBuffer {
	var data: UnsafeMutablePointer<UInt8> {
		self.contents()
			.bindMemory(to: UInt8.self, capacity: self.length)
	}
}
