//
//  ScreenViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import MetalKit
import os
import librayracer

class ScreenViewController: NSViewController {
	// accomodates NTSC, PAL and SECAM field data with extra space for
	// additional 20 scan lines
	private static let bufferLength: Int = (625/2 + 20) * 228
	private let buffers: [MTLBuffer]
	private var writeBufferIndex: Int = 0
	private var drawBufferIndex: Int?
	private var bufferIndexLock = OSAllocatedUnfairLock()

	private let imageTexture: MTLTexture
	private let imageSize: MTLSize = .ntscImage
	private let imageOrigin: MTLOrigin = .ntscImage

	private let commandQueue: MTLCommandQueue
	private let pipelineState: MTLRenderPipelineState
	private let console: Atari2600

	private(set) public var fieldRate: Double = 0
	private var fieldStartTime: CFTimeInterval = 0

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	init(console: Atari2600, commandQueue: MTLCommandQueue, pipelineState: MTLRenderPipelineState) {
		// initialize tripple buffering for storing field data
		let device = commandQueue.device
		self.buffers = (0..<3).map() { _ in
			guard let buffer = device.makeBuffer(length: Self.bufferLength, options: .storageModeShared) else {
				fatalError("Failed to initialize screen field buffer.")
			}
			return buffer
		}

		// initialize screen render texture
		guard let imageTexture = device.makeTexture(descriptor: Self.makeTextureDescriptor(size: self.imageSize)) else {
			fatalError("Failed to initialize screen render texture.")
		}
		self.imageTexture = imageTexture

		self.commandQueue = commandQueue
		self.pipelineState = pipelineState

		self.console = console
		super.init(nibName: nil, bundle: nil)

		// set first video buffer and self as video output
		let buffer = self.buffers[self.writeBufferIndex]
		self.console
			.console.pointee
			.setVideoBuffer(buffer)
		self.console
			.console.pointee
			.setVideoOutput(self)
	}

	private class func makeTextureDescriptor(size: MTLSize) -> MTLTextureDescriptor {
		let descriptor = MTLTextureDescriptor()
		descriptor.pixelFormat = .r8Uint
		descriptor.width = size.width
		descriptor.height = size.height

		// mark available only on the GPU for ::read or ::sample operations
		descriptor.storageMode = .private
		descriptor.usage = .shaderRead

		return descriptor
	}
}


// MARK: -
// MARK: Windows lifecycle
extension ScreenViewController {
	override func loadView() {
		let view = MTKView()
		view.device = self.commandQueue.device
		view.delegate = self
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
// MARK: Metal support
extension ScreenViewController: MTKViewDelegate {
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// does nothing
	}

	func draw(in view: MTKView) {
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
			return
		}

		// lock last completed buffer for rendering
		self.bufferIndexLock.lock()
		self.drawBufferIndex = self.completeWriteBufferIndex
		self.bufferIndexLock.unlock()

		let buffer = self.buffers[self.drawBufferIndex!]
		let offset = self.imageOrigin.y * 228 + self.imageOrigin.x
		let byteCount = 228

		// extract visible image from signal data, ignoring vertical and
		// horizontal blanking regions
		blitEncoder.copy(from: buffer, sourceOffset: offset, sourceBytesPerRow: byteCount, sourceBytesPerImage: 0, sourceSize: self.imageSize, to: self.imageTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .zero)
		blitEncoder.endEncoding()

		guard let renderPassDescriptor = view.currentRenderPassDescriptor,
			  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
			return
		}

		// encode render pass
		renderEncoder.setRenderPipelineState(self.pipelineState)
		renderEncoder.setFragmentTexture(self.imageTexture, index: 0)
		renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		renderEncoder.endEncoding()

		commandBuffer.present(view.currentDrawable!)
		commandBuffer.addCompletedHandler() { [unowned self] _ in
			// clear lock on completed buffer after rendering
			self.bufferIndexLock.withLockUnchecked() { [unowned self] in
				self.drawBufferIndex = nil
			}
		}

		commandBuffer.commit()
	}
}

// MARK: -
// MARK: Video output
extension ScreenViewController {
	/// Returns index of the most recent buffer with a complete field.
	var completeWriteBufferIndex: Int {
		return (self.writeBufferIndex - 1 + 3) % 3
	}

	/// Advances index of buffer for storing video output to the next available one.
	func advanceVideoBuffer() {
		// advance write buffer index
		var index = (self.writeBufferIndex + 1)
		index %= self.buffers.count

		// skip buffer when it is being rendered
		if index == self.drawBufferIndex {
			index += 1
			index %= self.buffers.count
		}

		self.writeBufferIndex = index

		// reset video buffer in TIA
		let buffer = self.buffers[self.writeBufferIndex]
		self.console
			.console.pointee
			.setVideoBuffer(buffer)
	}

	func updateFieldRate() {
		let currentTime = CACurrentMediaTime()
		let fieldTime = currentTime - self.fieldStartTime

		// fps = α⋅(1/time) + (1-α)⋅fps
		// α = 0.1, smoothing factor
		self.fieldRate *= 0.9
		self.fieldRate += 0.1/fieldTime

		self.fieldStartTime = currentTime
	}

	func synchronize(_ sync: VideoSync) {
		if sync.intersection([.vertical, .buffer]).isEmpty == false {
			self.bufferIndexLock
				.withLockUnchecked() { [unowned self] in
					self.advanceVideoBuffer()
				}

			self.updateFieldRate()
		}
	}
}

private extension racer_atari2600 {
	mutating func setVideoBuffer(_ buffer: MTLBuffer) {
		let contents = buffer.contents()
			.assumingMemoryBound(to: UInt8.self)

		self.tia.pointee
			.video_buffer = contents
		self.tia.pointee
			.video_buffer_end = contents.advanced(by: buffer.length)
	}

	mutating func setVideoOutput(_ output: ScreenViewController) {
		self.tia.pointee
			.video_output = Unmanaged.passUnretained(output)
			.toOpaque()
		self.tia.pointee
			.video_sync = synchronize(output:sync:)
	}
}

func synchronize(output: UnsafeRawPointer?, sync: VideoSync) {
	let screen = Unmanaged<ScreenViewController>
		.fromOpaque(output!)
		.takeUnretainedValue()

	screen.synchronize(sync)
}



// MARK: -
// MARK: Convenience functionality
private extension MTLOrigin {
	static let zero = MTLOrigin(x: 0, y: 0, z: 0)

	// TIA blanks each image scanline for the first 68 color clocks;
	// first (525-480)/2 = 22 scan lines in each field are vertical blank
	// interval in NTSC and are not shown by TVs
	static let ntscImage = MTLOrigin(x: 68, y: 22, z: 0)
}

private extension MTLSize {
	// TIA signals a NTSC TV at 228 color clocks per scan line;
	// NTSC frame consists of 525 scan lines of 2 interlaced fields
	static let ntsc = MTLSize(width: 228, height: 525/2, depth: 1)

	// TIA signals a NTSC TV at 228 color clocks per scan line, but blanks
	// each image scanline for the first 68 color clocks;
	// NTSC visible frame consists of 480 scanlines of 2 interlaced fields,
	// with ~8% of those scanlines ((480/2)*0.08 = 19) being in overscan,
	// and are optionally not shown by TVs
	static let ntscImage = MTLSize(width: 228-68, height: 480/2-19, depth: 1)

	var count: Int {
		return self.width * self.height * self.depth
	}
}
