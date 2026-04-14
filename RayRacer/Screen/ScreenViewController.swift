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
	fileprivate let renderer: NoBrakesRenderer
	fileprivate var console: Atari2600
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init(renderer: NoBrakesRenderer, console: Atari2600) {
		self.renderer = renderer
		self.console = console
		super.init(nibName: nil, bundle: nil)
		
		// set self as video output
		var console = self.console.console!
		console.setVideoOutput(self)
		
		// set video buffer
		let buffer = self.renderer.nextBuffer
		console.setVideoBuffer(buffer)
	}
}


// MARK: -
// MARK: Video output
extension UnsafeMutablePointer<racer_atari2600> {
	mutating func setVideoOutput(_ output: ScreenViewController) {
		self.pointee
			.tia.pointee
			.video_output = Unmanaged.passUnretained(output)
			.toOpaque()
		self.pointee
			.tia.pointee
			.video_sync = synchronize(output:sync:)
	}
	
	mutating func setVideoBuffer(_ buffer: MTLBuffer) {
		let contents = buffer.contents()
			.assumingMemoryBound(to: UInt8.self)
		
		self.pointee
			.tia.pointee
			.video_buffer = contents
		self.pointee
			.tia.pointee
			.video_buffer_end = contents.advanced(by: buffer.length)
	}
}

func synchronize(output: UnsafeRawPointer?, sync: VideoSync) {
	guard sync.intersection([.vertical, .buffer])
		.isEmpty == false else {
		// do nothing on horizontal sync
		return
	}
	
	let screen = Unmanaged<ScreenViewController>
		.fromOpaque(output!)
		.takeUnretainedValue()
	
	// reset video buffer
	let buffer = screen.renderer.nextBuffer
	var console = screen.console.console!
	console.setVideoBuffer(buffer)
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
		self.view.window?
			.makeFirstResponder(self)
		
		DispatchQueue.global(qos: .userInitiated)
			.async() { [unowned self] in
				self.console.resume()
			}
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
