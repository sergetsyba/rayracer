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
	private let texture: MTLTexture
	
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
		
		let descriptor = Self.makeTextureDescriptor(size: self.screenSize)
		guard let texture = device.makeTexture(descriptor: descriptor) else {
			fatalError("Failed to initialize screen render texture.")
		}
		
		self.commandQueue = commandQueue
		self.pipelineState = pipelineState
		self.texture = texture
		
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
		
		// fix aspect ratio to 4:3
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
			  let descriptor = view.currentRenderPassDescriptor,
			  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
			return
		}
		
		encoder.setRenderPipelineState(self.pipelineState)
		encoder.setFragmentTexture(self.texture, index: 0)
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		encoder.endEncoding()
		
		commandBuffer.present(view.currentDrawable!)
		commandBuffer.commit()
	}
}


// MARK: -
extension ScreenViewController: TIA.Output {
	private var currentScanLine: Int {
		return self.screenIndex / self.screenSize.width
	}
	
	func sync() {
		self.screenData.withUnsafeBytes() { [unowned self] in
			let region = MTLRegion(origin: .zero, size: self.screenSize)
			self.texture.replace(
				region: region,
				mipmapLevel: 0,
				withBytes: $0.baseAddress!,
				bytesPerRow: region.size.width)
		}
		
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
}

extension MTLSize {
	// ignoring 30 scan lines in overscan
	static let ntsc = MTLSize(width: 160, height: 262-30, depth: 1)
}

extension Array where Element: Numeric {
	init(forTextureSize size: MTLSize) {
		let count = size.width * size.height * size.depth
		self.init(repeating: 0, count: count)
	}
}
