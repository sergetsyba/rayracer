//
//  Renderer.swift
//  RayRacer
//
//  Created by Serge Tsyba on 2.5.2026.
//

import MetalKit
import simd

class Renderer: NSObject {
	private let commandQueue: MTLCommandQueue = .current
	private let pipelineState: MTLRenderPipelineState
	let buffers: [MTLBuffer]
	
	private var geometry: FieldGeometry = .ntsc
	var delegate: RendererDelegate!
	
	init(bufferCount: Int = 1) {
		let device = self.commandQueue.device
		guard let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize render library.")
		}
		
		let pipelineDescriptor = Self.makePipelineDescriptor(using: library)
		guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
			fatalError("Failed to initialize render pipeline state.")
		}
		
		guard let buffers = device.makeBuffers(count: bufferCount, length: self.geometry.bufferLength, options: .storageModeShared) else {
			fatalError("Failed to initialize rendering buffers.")
		}
		
		self.pipelineState = pipelineState
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
	func rendererWillBeginRendering(_ renderer: Renderer) -> MTLBuffer?
	func rendererDidEndRendering(_ renderer: Renderer)
}

extension Renderer: MTKViewDelegate {
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// does nothing
	}
	
	func draw(in view: MTKView) {
		guard let buffer = self.delegate.rendererWillBeginRendering(self),
			  let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let renderPassDescriptor = view.currentRenderPassDescriptor,
			  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor),
			  let drawable = view.currentDrawable else {
			return
		}
		
		// encode render pass
		renderEncoder.setRenderPipelineState(self.pipelineState)
		renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
		renderEncoder.setFragmentBytes(&self.geometry, length: MemoryLayout<field_geometry>.stride, index: 1)
		
		renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
		renderEncoder.endEncoding()
		
		commandBuffer.present(drawable)
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

typealias FieldGeometry = field_geometry
extension FieldGeometry {
	static let ntsc: Self = .init(
		// accomodates NTSC, PAL and SECAM field data with extra space for
		// additional 20 scan lines
		field_size: SIMD2<UInt32>(228, (625/2 + 20)),
		// TIA signals a NTSC TV at 228 color clocks per scan line, but blanks
		// each image scanline for the first 68 color clocks;
		// NTSC visible frame consists of 480 scanlines of 2 interlaced fields,
		// with ~8% of those scanlines ((480/2)*0.08 = 19) being in overscan,
		// and are optionally not shown by TVs
		image_size: SIMD2<UInt32>(x: 228-68, y: 480/2-19),
		// TIA blanks each image scanline for the first 68 color clocks;
		// first (525-480)/2 = 22 scan lines in each field are vertical blank
		// interval in NTSC and are not shown by TVs
		image_origin: SIMD2<UInt32>(x: 68, y: 22))
	
	var bufferLength: Int {
		Int(self.field_size.x * self.field_size.y)
	}
}
