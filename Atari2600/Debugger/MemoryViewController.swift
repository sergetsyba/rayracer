//
//  MemoryViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 9.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class MemoryViewController: NSViewController {
	@IBOutlet private var tiaRegistersLabel: NSTextField!
	@IBOutlet private var ramLabel: NSTextField!
	@IBOutlet private var riotRegistersLabel: NSTextField!
	
	private let console: Atari2600 = .current
	
	convenience init() {
		self.init(nibName: "MemoryView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.tiaRegistersLabel.memoryValue = Data(repeating: 0x00, count: 0x7f)
		self.ramLabel.memoryValue = Data(repeating: 0x00, count: 0xff - 0x7f)
		self.riotRegistersLabel.memoryValue = Data(repeating: 0x00, count: 0xff)
	}
}


// MARK: -
// MARK: Data formatting
extension NSTextField {
	var memoryValue: Data {
		get {
			fatalError("Getting memory value of NSTextField is currently not implemented.")
		}
		set {
			self.stringValue = newValue.formatted
		}
	}
}

private extension Data {
	var formatted: String {
		stride(from: self.startIndex, to: self.endIndex, by: 16)
			.map() { index1 in
				let columnCount = Swift.min(self.endIndex - index1, 16)
				return (0..<columnCount)
					.map() { index2 in self[index1 + index2] }
					.map() { String(format: "%02x", $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}
