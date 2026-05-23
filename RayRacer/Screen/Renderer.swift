//
//  Renderer.swift
//  RayRacer
//
//  Created by Serge Tsyba on 2.5.2026.
//

import MetalKit

class Renderer: NSObject {
	private let commandQueue: MTLCommandQueue = .current
	private let pipelineState: MTLRenderPipelineState
	
	private let texture: MTLTexture
	private let frame: MTLRegion
	private let buffers: [MTLBuffer]
	
	var delegate: RendererDelegate!
	
	init(bufferLength: Int, bufferCount: Int = 1, frame: MTLRegion = .ntscImage) {
		let device = self.commandQueue.device
		guard let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize render library.")
		}
		
		let pipelineDescriptor = Self.makePipelineDescriptor(using: library)
		guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
			fatalError("Failed to initialize render pipeline state.")
		}
		
		let textureDescriptor = Self.makeTextureDescriptor(size: frame.size)
		guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
			fatalError("Failed to initialize screen render texture.")
		}
		
		guard let buffers = device.makeBuffers(count: bufferCount, length: bufferLength, options: .storageModeShared) else {
			fatalError("Failed to initialize rendering buffers.")
		}
		
		self.pipelineState = pipelineState
		
		self.texture = texture
		self.frame = frame
		self.buffers = buffers
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
		descriptor.usage = [.shaderRead]
		
		return descriptor
	}
	
	var device: MTLDevice {
		return self.commandQueue.device
	}
	
	var bufferContents: [UnsafeMutablePointer<UInt8>?] {
		return self.buffers.map() {
			$0.contents()
				.assumingMemoryBound(to: UInt8.self)
		}
	}
}

// MARK: -
// MARK: Rendering
protocol RendererDelegate {
	func rendererWillBeginRendering(_ renderer: Renderer) -> Int
	func rendererDidEndRendering(_ renderer: Renderer)
}

extension Renderer: MTKViewDelegate {
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// does nothing
	}
	
	func draw(in view: MTKView) {
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
			return
		}
		
		let bufferIndex = self.delegate.rendererWillBeginRendering(self)
		let buffer = self.buffers[bufferIndex]
		let offset = self.frame.origin.y * 228 + self.frame.origin.x
		
		// extract visible image from signal data, ignoring vertical and
		// horizontal blanking regions
		blitEncoder.copy(
			from: buffer,
			sourceOffset: offset,
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
			self.delegate.rendererDidEndRendering(self)
		}
		
		commandBuffer.commit()
	}
}


// MARK: -
// MARK: Convenience functionality
extension MTLDevice {
	func makeBuffers(count: Int, length: Int, options: MTLResourceOptions) -> [MTLBuffer]? {
		var buffers: [MTLBuffer] = []
		for _ in 0..<count {
			guard let buffer = self.makeBuffer(length: length, options: options) else {
				return nil
			}
			buffers.append(buffer)
		}
		
		return buffers
	}
}

extension MTLCommandQueue where Self == MTLCommandQueue {
	static var current: Self {
		MTLCommandQueueWrapper.value
	}
}

private struct MTLCommandQueueWrapper {
	static let value: MTLCommandQueue = {
		// pick GPU, which currently drives the display, instead of creating
		// default Metal device, which would trigger GPU switching
		let displayId = CGMainDisplayID()
		guard let device = CGDirectDisplayCopyCurrentMetalDevice(displayId),
			  let queue = device.makeCommandQueue() else {
			fatalError("Failed to initialize Metal.")
		}
		
		return queue
	}()
}

extension MTLRegion {
	static let ntscImage: Self = MTLRegion(
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
