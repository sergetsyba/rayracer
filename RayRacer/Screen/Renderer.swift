//
//  Renderer.swift
//  RayRacer
//
//  Created by Serge Tsyba on 2.5.2026.
//

import MetalKit
import librayracer



class Renderer: NSObject {
	private let commandQueue: MTLCommandQueue
	private let pipelineState: MTLRenderPipelineState

	private let buffers: [MTLBuffer]
	private let texture: MTLTexture
	private let frame: MTLFrame

	private var pointers: [UnsafeMutablePointer<UInt8>?]
	let racer: UnsafeMutablePointer<racer_thread>!

	init(console: UnsafeMutablePointer<racer_atari2600>!, queue: MTLCommandQueue, frame: MTLFrame = .ntscImage) {
		// set up Metal
		self.commandQueue = queue
		self.pipelineState = Self.makeRenderPipelineState(on: queue.device)

		let bufferCount = 3
		self.buffers = Self.makeBuffers(on: queue.device, count: bufferCount)
		self.texture = Self.makeTexture(on: queue.device, size: frame.size)
		self.frame = frame

		// set up emulation
		self.pointers = self.buffers.map() {
			$0.contents()
				.assumingMemoryBound(to: UInt8.self)
		}
		self.racer = racer_thread_create(console, &self.pointers, Int32(bufferCount), self.buffers[0].length)
	}

	var device: MTLDevice {
		return self.commandQueue.device
	}

	private class func makeRenderPipelineState(on device: MTLDevice) -> MTLRenderPipelineState {
		guard let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize render library.")
		}

		let descriptor = Self.makePipelineDescriptor(using: library)
		guard let state = try? device.makeRenderPipelineState(descriptor: descriptor) else {
			fatalError("Failed to initialize render pipeline state.")
		}

		return state
	}

	private class func makePipelineDescriptor(using library: MTLLibrary) -> MTLRenderPipelineDescriptor {
		let descriptor = MTLRenderPipelineDescriptor()
		descriptor.vertexFunction = library.makeFunction(name: "make_vertex")
		descriptor.fragmentFunction = library.makeFunction(name: "shade_fragment")
		descriptor.colorAttachments[0]
			.pixelFormat = .bgra8Unorm

		return descriptor
	}

	private class func makeBuffers(on device: MTLDevice, count: Int) -> [MTLBuffer] {
		// accomodates NTSC, PAL and SECAM field data with extra space for
		// additional 20 scan lines
		let bufferLength = (625/2 + 20) * 256

		return (0..<count)
			.map() { _ in
				guard let buffer = device.makeBuffer(length: bufferLength, options: .storageModeShared) else {
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

	private class func makeTextureDescriptor(size: MTLSize) -> MTLTextureDescriptor {
		let descriptor = MTLTextureDescriptor()
		descriptor.pixelFormat = .r8Uint
		descriptor.width = size.width
		descriptor.height = size.height

		// mark available only on the GPU for ::read or ::sample operations
		descriptor.storageMode = .private
		descriptor.usage = [.shaderRead]

		return descriptor
	}
}


// MARK: -
extension Renderer: MTKViewDelegate {
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// does nothing
	}

	func draw(in view: MTKView) {
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
			return
		}

		// lock last completed buffer for rendering
		let bufferIndex = racer_thread_lock_draw_buffer(self.racer)
		let buffer = self.buffers[Int(bufferIndex)]

		// extract visible image from signal data, ignoring vertical and
		// horizontal blanking regions
		blitEncoder.copy(
			from: buffer,
			sourceOffset: self.frame.origin.y * 228 + self.frame.origin.x,
			sourceBytesPerRow: 228 * MemoryLayout<UInt8>.size,
			sourceBytesPerImage: 0,
			sourceSize: self.frame.size,
			to: self.texture,
			destinationSlice: 0,
			destinationLevel: 0,
			destinationOrigin: .zero)

		blitEncoder.endEncoding()

		guard let renderPassDescriptor = view.currentRenderPassDescriptor,
			  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
			return
		}

		// encode render pass
		renderEncoder.setRenderPipelineState(self.pipelineState)
		renderEncoder.setFragmentTexture(self.texture, index: 0)
		renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		renderEncoder.endEncoding()

		commandBuffer.present(view.currentDrawable!)
		commandBuffer.addCompletedHandler() { [unowned self] _ in
			// release render buffer index once render finished and
			// resume emulation
			racer_thread_unlock_draw_buffer(self.racer)
			racer_thread_resume(self.racer)
		}

		commandBuffer.commit()
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Sequence where Element == MTLBuffer {
	var contents: [UnsafeMutablePointer<UInt8>?] {
		self.map() {
			$0.contents()
				.assumingMemoryBound(to: UInt8.self)
		}
	}
}
