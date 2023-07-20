//
//  MemoryViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 12.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class MemoryViewController: NSViewController {
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: "MemoryView", bundle: .main)
		self.title = "Memory"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.resetView(self.console.riot.memory)
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension MemoryViewController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .reset:
						self.resetView(self.console.riot.memory)
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .break, .step:
						self.updateView(self.console.riot.memory)
					default:
						break
					}
				})
	}
	
	func resetView(_ memory: Data) {
		if let view = self.view as? NSTextField {
			view.attributedStringValue = NSMutableAttributedString(memory: memory)
			view.textColor = .controlTextColor
		}
	}
	
	func updateView(_ memory: Data) {
		if let view = self.view as? NSTextField {
			let string = NSMutableAttributedString(attributedString: view.attributedStringValue)
			string.update(memory: memory)
			view.attributedStringValue = string
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSMutableAttributedString {
	convenience init(memory: Data) {
		let formatted = String(memory: memory)
		self.init(string: formatted)
		
		for index in memory.indices {
			let color: NSColor = .disabledControlTextColor
			let range = NSRange(location: index * 3, length: 2)
			self.addAttribute(.foregroundColor, value: color, range: range)
		}
	}
	
	func update(memory: Data) {
		for index in memory.indices {
			self.update(memoryValue: memory[index], at: index)
		}
	}
	
	func update(memoryValue value: UInt8, at index: Int) {
		let range = NSRange(location: index * 3, length: 2)
		let oldValue = self.mutableString.substring(with: range)
		let newValue = String(memoryValue: value)
		
		if newValue != oldValue {
			self.mutableString.replaceCharacters(in: range, with: newValue)
			self.removeAttribute(.foregroundColor, range: range)
		}
	}
}

private extension String {
	init(memoryValue value: UInt8) {
		self = String(format: "%02x", value)
	}
	
	init(memory: Data) {
		self = memory.indices
			.split(by: 16)
			.map() {
				return memory[$0]
					.map() { String(memoryValue: $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}

private extension Range where Index == Int {
	func split(by count: Int) -> any Sequence<Self> {
		return Swift.stride(from: self.startIndex, to: self.endIndex, by: count)
			.map() { $0..<$0+count }
	}
}
