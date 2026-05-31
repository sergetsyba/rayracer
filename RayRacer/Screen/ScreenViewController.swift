//
//  ScreenViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import MetalKit
import librayracer

class ScreenViewController: NSViewController {
	private let renderer: Renderer
	private let racer: Racer
	private let console: Atari2600

	private var fieldRateTimer: Timer?
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init(console: Atari2600) {
		let renderer = Renderer(bufferCount: 3)
		let racer = Racer(console: console, buffers: renderer.buffers)
		renderer.delegate = racer
		
		self.renderer = renderer
		self.racer = racer
		self.console = console
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
		self.fieldRateTimer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			self?.showFieldRate()
		}
	}
	
	override func viewWillDisappear() {
		super.viewDidDisappear()
		self.fieldRateTimer?.invalidate()
		
		let view = self.view as! MTKView
		view.isPaused = true
		view.delegate = nil
		
		// reassign pointer to racer_thread to avoid capturing self
		// from main actor; destroy racer_thread in a detached task
		// to give racer_thread time to break out of run loop and
		// join its thread
		let racer = self.racer
		Task.detached(priority: .userInitiated) {
			racer_thread_destroy(racer)
		}
	}
	
	private func showFieldRate() {
		let name = self.console.cartridge!.name
		let frameRate = 1e9 / self.racer.pointee.field_time
		
		self.view.window?
			.title = String(format: "%@ (%.0f fps)", name, frameRate)
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


