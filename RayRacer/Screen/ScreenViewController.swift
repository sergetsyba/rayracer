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
	private var fieldRateTimer: Timer?
	
	let console: Atari2600
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init(renderer: Renderer, console: Atari2600) {
		self.renderer = renderer
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
		let name = self.console.cartridge!.name
		let rate = Int(racer_thread_get_field_rate(self.renderer.racer))
		self.view.window?
			.title = "\(name) (\(rate) fps)"
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
