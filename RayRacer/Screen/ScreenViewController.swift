//
//  ScreenViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import MetalKit
import RayRacerKit

class ScreenViewController: NSViewController {
	private let console: Atari2600
	private var screenData: Array<UInt8>
	private var screenDataReady: Bool
	private var screenIndex = 0
	
	private let commandQueue: MTLCommandQueue
	private let pipelineState: MTLRenderPipelineState
	private let screenBuffer: MTLBuffer
	private let imageTexture: MTLTexture
	
	private let screenSize: MTLSize = .ntsc
	private let imageSize: MTLSize = .ntscImage
	private let imageOrigin: MTLOrigin = .ntscImage
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init(console: Atari2600, commandQueue: MTLCommandQueue, pipelineState: MTLRenderPipelineState) {
		self.console = console
		self.screenData = Array<UInt8>(repeating: 0, count: self.screenSize.count)
		self.screenDataReady = true
		
		let device = commandQueue.device
		guard let screenBuffer = device.makeBuffer(bytesNoCopy: &self.screenData, length: self.screenData.count),
			  let imageTexture = device.makeTexture(descriptor: Self.makeTextureDescriptor(size: self.imageSize)) else {
			fatalError("Failed to initialize screen render texture.")
		}
		
		self.commandQueue = commandQueue
		self.pipelineState = pipelineState
		self.screenBuffer = screenBuffer
		self.imageTexture = imageTexture
		
		super.init(nibName: nil, bundle: nil)
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
		view.preferredFramesPerSecond = 30
		
		// force view aspect ratio to 4:3
		view.addConstraint(view.widthAnchor.constraint(
			equalTo: view.heightAnchor,
			multiplier: 4.0/3.0))
		
		self.view = view
	}
}


// MARK: -
// MARK: Metal support
extension ScreenViewController: MTKViewDelegate {
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		// does nothing
	}
	
	func draw(in view: MTKView) {
		// skip frame when console has been suspended by another component
		// or has not yet produced field data
		guard self.screenDataReady else {
			return
		}
		
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
			return
		}
		
		// extract visible image from signal data, ignoring vertical and
		// horizontal blanking regions
		let imageOffset = self.imageOrigin.y * self.screenSize.width + self.imageOrigin.x
		let bytesPerRow = self.screenSize.width * MemoryLayout<UInt8>.size
		blitEncoder.copy(from: self.screenBuffer, sourceOffset: imageOffset, sourceBytesPerRow: bytesPerRow, sourceBytesPerImage: 0, sourceSize: self.imageSize, to: self.imageTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .zero)
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
		
		// begin preparing next field once command buffer work finishes
		commandBuffer.addCompletedHandler() { [unowned self] _ in
			DispatchQueue.global(qos: .userInitiated)
				.async() { [unowned self] in
					self.console.resume()
				}
		}
		
		commandBuffer.present(view.currentDrawable!)
		commandBuffer.commit()
	}
}


// MARK: -
extension ScreenViewController: TIA.GraphicsOutput {
	private var currentScanLine: Int {
		return self.screenIndex / self.screenSize.width
	}
	
	func sync() {
		self.console.suspend()
		self.screenIndex = 0
		
		// notify emulation has produced next field data
		DispatchQueue.main.async() {
			self.screenDataReady = true
		}
	}
	
	func write(color: Int) {
		guard self.currentScanLine < self.screenSize.height else {
			return
		}
		
		self.screenData[self.screenIndex] = UInt8(color)
		self.screenIndex += 1
	}
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
