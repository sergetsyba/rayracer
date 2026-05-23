//
//  ScreenViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import MetalKit
import librayracer

// accomodates NTSC, PAL and SECAM field data with extra space for
// additional 20 scan lines
let bufferLength = (625/2 + 20) * 256

class ScreenViewController: NSViewController {
	private let renderer: Renderer
	private var bufferContents: [UnsafeMutablePointer<UInt8>?]
	private var fieldRateTimer: Timer?

	let console: Atari2600
	let racer: UnsafeMutablePointer<racer_thread>!

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	init(console: Atari2600) {
		let renderer = Renderer(bufferLength: bufferLength, bufferCount: 3)
		self.bufferContents = renderer.bufferContents

		self.console = console
		self.renderer = renderer

		self.racer = racer_thread_create(self.console.console, &self.bufferContents, 3, bufferLength)
		self.renderer.delegate = self.racer
		super.init(nibName: nil, bundle: nil)
	}
}


// MARK: -
// MARK: View lifecycle
extension ScreenViewController {
	override func loadView() {
		let view = MTKView()
		view.device = self.renderer.device
		view.delegate = self.renderer
		view.preferredFramesPerSecond = 60

		// force view aspect ratio to 4:3
		view.addConstraint(view.widthAnchor.constraint(
			equalTo: view.heightAnchor,
			multiplier: 4.0/3.0))

		self.view = view
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		self.fieldRateTimer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned self] _ in
			self.showFieldRate()
		}
	}

	override func viewWillDisappear() {
		super.viewDidDisappear()

		self.console.suspend()
		self.fieldRateTimer?.invalidate()
	}

	private func showFieldRate() {
		let fieldRate = Int(1e9 / self.racer.pointee.field_time)
		self.view.window?
			.title = "\(self.console.cartridge!.name) (\(fieldRate) fps)"
	}
}

// MARK: -
// MARK: Controller input
extension ScreenViewController {
	override func keyDown(with event: NSEvent) {
		guard let button = Joystick.Buttons(keyCode: event.keyCode) else {
			super.keyDown(with: event)
			return
		}
		self.console.controllers
			.0?.press(button)
	}

	override func keyUp(with event: NSEvent) {
		guard let button = Joystick.Buttons(keyCode: event.keyCode) else {
			super.keyDown(with: event)
			return
		}
		self.console.controllers
			.0?.release(button)
	}
}

private extension Joystick.Buttons {
	init?(keyCode: UInt16) {
		switch keyCode {
		case 49: self = .fire
		case 123: self = .left
		case 124: self = .right
		case 125: self = .down
		case 126: self = .up
		default:
			return nil
		}
	}
}

extension UnsafeMutablePointer<racer_thread>: RendererDelegate {
	func rendererWillBeginRendering(_ renderer: Renderer) -> Int {
		// lock last completed buffer for rendering
		let index = racer_thread_lock_draw_buffer(self)
		return Int(index)
	}
	
	func rendererDidEndRendering(_ renderer: Renderer) {
		// release render buffer index once render finished and
		// resume emulation
		racer_thread_unlock_draw_buffer(self)
		racer_thread_resume(self)
	}
}
