//
//  ScreenViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import MetalKit
import RayRacerKit
import Combine

class ScreenViewController: NSViewController {
	private let commandQueue: MTLCommandQueue
	private let pipelineState: MTLRenderPipelineState
	
	private let screenTexture: MTLTexture
	private let imageTexture: MTLTexture
	
	private let screenSize: MTLSize = .ntsc
	private var screenData = Array<UInt8>(forTextureSize: .ntsc)
	private var screenIndex = 0
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init(commandQueue: MTLCommandQueue, pipelineState: MTLRenderPipelineState) {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError("Failed to initialize Metal.")
		}
		
		guard let screenTexture = device.makeTexture(descriptor: Self.makeTextureDescriptor(size: .ntsc)),
			  let imageTexture = device.makeTexture(descriptor: Self.makeTextureDescriptor(size: .ntscImage)) else {
				  fatalError("Failed to initialize screen render texture.")
			  }
		
		self.commandQueue = commandQueue
		self.pipelineState = pipelineState
		self.screenTexture = screenTexture
		self.imageTexture = imageTexture
		
		super.init(nibName: nil, bundle: nil)
	}
	
	private class func makeTextureDescriptor(size: MTLSize) -> MTLTextureDescriptor {
		let descriptor = MTLTextureDescriptor()
		descriptor.pixelFormat = .r8Uint
		descriptor.width = size.width
		descriptor.height = size.height
		
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
		view.isPaused = true
		view.enableSetNeedsDisplay = true
		
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
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
			return
		}
		
		// extract visible image from signal data, ignoring vertical and
		// horizontal blanking regions
		blitEncoder.copy(from: self.screenTexture, sourceSlice: 0, sourceLevel: 0, sourceOrigin: .ntscImage, sourceSize: .ntscImage, to: self.imageTexture, destinationSlice: 0, destinationLevel: 0, destinationOrigin: .zero)
		blitEncoder.endEncoding()
		
		guard let descriptor = view.currentRenderPassDescriptor,
			  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
			return
		}
		
		renderEncoder.setRenderPipelineState(self.pipelineState)
		renderEncoder.setFragmentTexture(self.imageTexture, index: 0)
		renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		renderEncoder.endEncoding()
		
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
		let region = MTLRegion(origin: .zero, size: self.screenSize)
		self.screenTexture.replace(
			region: region,
			mipmapLevel: 0,
			withBytes: self.screenData,
			bytesPerRow: region.size.width)
		
		self.screenIndex = 0
		self.view.needsDisplay = true
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
extension MTLOrigin {
	static let zero = MTLOrigin(x: 0, y: 0, z: 0)
	
	// TIA blanks each image scanline for the first 68 color clocks;
	// first (525-480)/2 = 22 scan lines in each field are vertical blank
	// interval in NTSC and are not shown by TVs
	static let ntscImage = MTLOrigin(x: 68, y: 22, z: 0)
}

extension MTLSize {
	// TIA signals a NTSC TV at 228 color clocks per scan line;
	// NTSC frame consists of 525 scan lines of 2 interlaced fields
	static let ntsc = MTLSize(width: 228, height: 525/2, depth: 1)
	
	// TIA signals a NTSC TV at 228 color clocks per scan line, but blanks
	// each image scanline for the first 68 color clocks;
	// NTSC visible frame consists of 480 scanlines of 2 interlaced fields,
	// with ~8% of those scanlines ((480/2)*0.08 = 19) being in overscan,
	// and are optionally not shown by TVs
	static let ntscImage = MTLSize(width: 228-68, height: 480/2-19, depth: 1)
}

extension Array where Element: Numeric {
	init(forTextureSize size: MTLSize) {
		let count = size.width * size.height * size.depth
		self.init(repeating: 0, count: count)
	}
}
