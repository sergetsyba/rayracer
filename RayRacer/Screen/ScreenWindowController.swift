//
//  ScreenWindowController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import Combine
import MetalKit
import RayRacerKit


class ScreenWindowController: NSWindowController {
	private var commandQueue: MTLCommandQueue
	private var pipelineState: MTLRenderPipelineState
	private var texture: MTLTexture
	
	private var metalView: MTKView
	
	init() {
		guard let device = MTLCreateSystemDefaultDevice(),
			  let library = device.makeDefaultLibrary() else {
			fatalError("Failed to initialize Metal.")
		}
		
		let view = MTKView()
		view.device = device
		view.isPaused = true
		view.enableSetNeedsDisplay = true
		
		let pipelineDescriptor = MTLRenderPipelineDescriptor()
		pipelineDescriptor.vertexFunction = library.makeFunction(name: "make_vertex")
		pipelineDescriptor.fragmentFunction = library.makeFunction(name: "shade_fragment")
		pipelineDescriptor.colorAttachments[0]
			.pixelFormat = view.colorPixelFormat
		
		let textureDescriptor = MTLTextureDescriptor()
		textureDescriptor.pixelFormat = .r8Uint
		textureDescriptor.width = 120
		textureDescriptor.height = 120
		
		self.commandQueue = device.makeCommandQueue()!
		self.pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)
		self.texture = device.makeTexture(descriptor: textureDescriptor)!
		
		self.metalView = view
		super.init(window: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
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
	var bitmap: [UInt8] {
		var bitmap = Array<UInt8>(repeating: 0, count: 120*120)
		for index in bitmap.indices {
			bitmap[index] = .random(in: 0..<128)
		}
		
		return bitmap
	}
	
	func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
		//
	}
	
	private func generateTexture() {
		let region = MTLRegionMake2D(0, 0, 120, 120)
		var bitmap = self.bitmap
		
		self.texture.replace(
			region: region,
			mipmapLevel: 0,
			withBytes: &bitmap,
			bytesPerRow: region.size.width)
	}
	
	func draw(in view: MTKView) {
		guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
			  let descriptor = view.currentRenderPassDescriptor,
			  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
			return
		}
		
		self.generateTexture()
		encoder.setRenderPipelineState(self.pipelineState)
		encoder.setFragmentTexture(self.texture, index: 0)
		encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
		encoder.endEncoding()
		
		commandBuffer.present(view.currentDrawable!)
		commandBuffer.commit()
	}
}
