//
//  ScreenWindowController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import Combine
import CoreGraphics
import Atari2600Kit

class ScreenWindowController: NSWindowController {
	@IBOutlet private var imageView: NSImageView!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(window: nil)
	}
	
	override var windowNibName: NSNib.Name? {
		return "ScreenWindow"
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension ScreenWindowController {
	func setUpSinks() {
		self.console.tia.events
			.receive(on: DispatchQueue.main)
			.sink() {
				switch $0 {
				case .drawFrame(var frame):
					frame.withUnsafeMutableBytes() {
						let colorSpace = CGColorSpaceCreateDeviceGray()
						let context = CGContext(
							data: $0.baseAddress,
							width: 192,
							height: 160,
							bitsPerComponent: 8,
							bytesPerRow: 192,
							space: colorSpace,
							bitmapInfo: CGImageAlphaInfo.none.rawValue)
						
						if let image = context?.makeImage() {
							self.imageView.image = NSImage(
								cgImage: image,
								size: NSSize(width: 192, height: 160))
						}
					}
				}
			}.store(in: &self.cancellables)
	}
}
