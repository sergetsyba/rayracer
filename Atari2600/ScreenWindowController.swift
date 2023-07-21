//
//  ScreenWindowController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 30.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class ScreenWindowController: NSWindowController {
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
		self.cancellables.insert(
			self.console.tia.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .frame(let lines):
						(self.window?.contentView as? ScreenView)?
							.lines = lines
					}
				})
	}
}
