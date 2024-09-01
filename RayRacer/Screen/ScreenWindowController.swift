//
//  ScreenWindowController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import MetalKit
import RayRacerKit
import Combine

class ScreenWindowController: NSWindowController {
	private var commandQueue: MTLCommandQueue
	private var pipelineState: MTLRenderPipelineState
	
	private var texture: MTLTexture
	private var textureData = Data(size: .ntsc)
	private let textureRegion = MTLRegion(origin: .zero, size: .ntsc)
	private var clock = 0
	
	private var metalView: MTKView
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	init() {
		guard let device = MTLCreateSystemDefaultDevice() else {
			fatalError("Failed to initialize Metal.")
		}
		
		let view = MTKView()
		view.device = device
		view.isPaused = true
		view.enableSetNeedsDisplay = true
		
		guard let commandQueue = device.makeCommandQueue(),
			  let pipelineState = try? device.makeRenderPipelineState(
				descriptor: Self.makeRenderPipelineDescriptor(view: view)),
			  let texture = device.makeTexture(
				descriptor: Self.makeTextureDescriptor(size: .ntsc)) else {
			fatalError("Failed to initialize Metal.")
		}
		
		self.commandQueue = commandQueue
		self.pipelineState = pipelineState
		self.texture = texture
		
		self.metalView = view
		super.init(window: nil)
	}
	
	private class func makeRenderPipelineDescriptor(view: MTKView) -> MTLRenderPipelineDescriptor {
		guard let library = view.device?.makeDefaultLibrary() else {
			fatalError("Failed to initialize Metal.")
		}
		
		let descirptor = MTLRenderPipelineDescriptor()
		descirptor.vertexFunction = library.makeFunction(name: "make_vertex")
		descirptor.fragmentFunction = library.makeFunction(name: "shade_fragment")
		descirptor.colorAttachments[0]
			.pixelFormat = view.colorPixelFormat
		
		return descirptor
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
extension ScreenWindowController {
	override var windowNibName: NSNib.Name? {
		return "ScreenWindow"
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		
		self.metalView.delegate = self
		self.window?
			.contentView = self.metalView
	}
}


// MARK: -
// MARK: Metal support
extension ScreenWindowController: MTKViewDelegate {
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
extension ScreenWindowController: Screen {
	var height: Int {
		return MTLSize.ntsc.height
	}
	
	var width: Int {
		return MTLSize.ntsc.width
	}
	
	func sync() {
		self.textureData.withUnsafeBytes() { [unowned self] in
			self.texture.replace(
				region: self.textureRegion,
				mipmapLevel: 0,
				withBytes: $0.baseAddress!,
				bytesPerRow: self.textureRegion.size.width)
		}
		
		self.clock = 0
		self.metalView.needsDisplay = true
	}
	
	func write(color: Int) {
		self.textureData[self.clock] = UInt8(color)
		self.clock += 1
	}
}


// MARK: -
// MARK: Convenience functionality
private extension MTLOrigin {
	static let zero = MTLOrigin(x: 0, y: 0, z: 0)
}

private extension MTLSize {
	static let ntsc = MTLSize(width: 228, height: 262, depth: 1)
}

private extension Data {
	init(size: MTLSize) {
		self.init(count: size.width * size.height * size.depth)
	}
}
