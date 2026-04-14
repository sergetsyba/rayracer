//
//  NoBrakesRenderer.swift
//  RayRacer
//
//  Created by Валентина on 14.04.2026.
//

import MetalKit
import os

class NoBrakesRenderer: NSObject {
	private let commandQueue: MTLCommandQueue
	private let pipelineState: MTLRenderPipelineState

	private let buffers: [MTLBuffer]
	private var bufferWriteIndex: Int = 0
	private var bufferRenderIndex: Int?
	private let bufferLock = OSAllocatedUnfairLock()

	private let renderTexture: MTLTexture
	private let renderFrame: MTLFrame

	private(set) var fieldRate: Double = 0
	private var fieldStartTime: CFTimeInterval = 0

	init(queue: MTLCommandQueue, frame: MTLFrame = .ntscImage) {
		self.pipelineState = Self.makeRenderPipelineState(for: queue.device)
		self.commandQueue = queue

		// accomodates NTSC, PAL and SECAM field data with extra space for
		// additional 20 scan lines
		let bufferLength = (625/2 + 20) * 228
		self.buffers = Self.makeBuffers(on: queue.device, count: 3, length: bufferLength)

		self.renderTexture = Self.makeTexture(on: queue.device, size: frame.size)
		self.renderFrame = frame
	}

	var device: MTLDevice {
		self.commandQueue.device
	}

	private class func makeRenderPipelineState(for device: MTLDevice) -> MTLRenderPipelineState {
		guard let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize render library.")
		}

		let descriptor = Self.makePipelineDescriptor(using: library)
		guard let state = try? device.makeRenderPipelineState(descriptor: descriptor) else {
			fatalError("Failed to initialize render pipeline state.")
		}

		return state
	}

	private class func makeBuffers(on device: MTLDevice, count: Int, length: Int) -> [MTLBuffer] {
		return (0..<count).map() { _ in
			guard let buffer = device.makeBuffer(length: length, options: .storageModeShared) else {
				fatalError("Failed to initialize rendering buffer.")
			}
			return buffer
		}
	}

	private class func makeTexture(on device: MTLDevice, size: MTLSize) -> MTLTexture {
		let descriptor = Self.makeTextureDescriptor(size: size)
		guard let texture = device.makeTexture(descriptor: descriptor) else {
			fatalError("Failed to initialize screen render texture.")
		}

		return texture
	}

	private class func makePipelineDescriptor(using library: MTLLibrary) -> MTLRenderPipelineDescriptor {
		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = library.makeFunction(name: "make_vertex")
		descriptor.fragmentFunction = library.makeFunction(name: "shade_fragment")
		descriptor.colorAttachments[0]
			.pixelFormat = .bgra8Unorm

		return descriptor
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

extension NoBrakesRenderer: MTKViewDelegate {
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// does nothing
	}

	func draw(in view: MTKView) {
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
			return
		}

		// lock last completed buffer for rendering
		self.bufferLock.withLockUnchecked() {
			let index = self.bufferWriteIndex
			let count = self.buffers.count
			self.bufferRenderIndex = (index - 1 + count) % count
		}

		// extract visible image from signal data, ignoring vertical and
		// horizontal blanking regions
		let buffer = self.buffers[self.bufferWriteIndex]
		let offset = self.renderFrame.origin.y * 228 + self.renderFrame.origin.x
		let bytes = 228 * MemoryLayout<UInt8>.size

		blitEncoder.copy(from: buffer, sourceOffset: offset, sourceBytesPerRow: bytes, sourceBytesPerImage: 0, sourceSize: self.renderFrame.size, to: self.renderTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .zero)
		blitEncoder.endEncoding()

		guard let renderPassDescriptor = view.currentRenderPassDescriptor,
			  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
			return
		}

		// encode render pass
		renderEncoder.setRenderPipelineState(self.pipelineState)
		renderEncoder.setFragmentTexture(self.renderTexture, index: 0)
		renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		renderEncoder.endEncoding()

		commandBuffer.present(view.currentDrawable!)
		commandBuffer.addCompletedHandler() { [unowned self] _ in
			// release render buffer index once render finished
			self.bufferLock.withLockUnchecked() { [unowned self] in
				self.bufferRenderIndex = nil
			}
		}

		commandBuffer.commit()
	}
}

// MARK: -
// MARK: Video output
extension NoBrakesRenderer {
	var nextBuffer: MTLBuffer {
		return self.bufferLock.withLockUnchecked() {
			self.advanceVideoBuffer()
			self.updateFieldRate()

			return self.buffers[self.bufferWriteIndex]
		}
	}

	private func advanceVideoBuffer() {
		// advance write buffer index
		var index = (self.bufferWriteIndex + 1)
		index %= self.buffers.count

		// skip buffer when it is being rendered
		if index == self.bufferRenderIndex {
			index += 1
			index %= self.buffers.count
		}

		self.bufferWriteIndex = index
	}

	private func updateFieldRate() {
		let currentTime = CACurrentMediaTime()
		let fieldTime = currentTime - self.fieldStartTime

		// fps = α⋅(1/time) + (1-α)⋅fps
		// α = 0.1, smoothing factor
		self.fieldRate *= 0.9
		self.fieldRate += 0.1/fieldTime

		self.fieldStartTime = currentTime
	}
}


// MARK: -
// MARK: Convenience functionality
struct MTLFrame {
	var origin: MTLOrigin
	var size: MTLSize
}

extension MTLFrame {
	static let ntscImage: Self = MTLFrame(
		// TIA blanks each image scanline for the first 68 color clocks;
		// first (525-480)/2 = 22 scan lines in each field are vertical blank
		// interval in NTSC and are not shown by TVs
		origin: MTLOrigin(x: 68, y: 22, z: 0),
		// TIA signals a NTSC TV at 228 color clocks per scan line, but blanks
		// each image scanline for the first 68 color clocks;
		// NTSC visible frame consists of 480 scanlines of 2 interlaced fields,
		// with ~8% of those scanlines ((480/2)*0.08 = 19) being in overscan,
		// and are optionally not shown by TVs
		size: MTLSize(width: 228-68, height: 480/2-19, depth: 1))
}

extension MTLOrigin {
	static let zero = MTLOrigin(x: 0, y: 0, z: 0)
}
