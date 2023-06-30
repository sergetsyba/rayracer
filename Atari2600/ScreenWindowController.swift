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
				case .drawFrame(let _):
					var bitmap = Data(repeating: .random(in: 0..<255), count: 20)
					
					bitmap.withUnsafeMutableBytes() {
						let colorSpace = CGColorSpaceCreateDeviceGray()
						let context = CGContext(
							data: $0.baseAddress,
							width: 5,
							height: 5,
							bitsPerComponent: 8,
							bytesPerRow: 5,
							space: colorSpace,
							bitmapInfo: CGImageAlphaInfo.none.rawValue)
						
						if let image = context?.makeImage() {
							self.imageView.image = NSImage(
								cgImage: image,
								size: NSSize(width: 5, height: 5))
							print(self.imageView.image)
						}
					}
					
				default:
					break
				}
			}.store(in: &self.cancellables)
	}
}
