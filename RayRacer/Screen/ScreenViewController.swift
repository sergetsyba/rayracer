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
	private let console: Atari2600
	private var fieldRateTimer: Timer?

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	init(console: Atari2600) {
		// accomodates NTSC, PAL and SECAM field data with extra space for
		// additional 20 scan lines
		let renderer = Renderer(bufferLength: (625/2 + 20) * 256, bufferCount: 3)
		renderer.delegate = Racer(console: console, buffers: renderer.buffers)

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
		self.fieldRateTimer?.invalidate()
	}

	private func showFieldRate() {
		let racer = self.renderer.delegate as! Racer
		let name = self.console.cartridge!.name
		let frameRate = 1e9 / racer.pointee.field_time

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


// MARK: -
// MARK: Emulation

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
		// suspend emulation
		racer_thread_suspend(self)

		let index = Int(self.pointee.draw_buffer_index)
		return renderer.buffers[index]
	}

	func rendererDidEndRendering(_ renderer: Renderer) {
		// resume emulation
		racer_thread_resume(self)
	}
}
