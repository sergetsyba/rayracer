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
	private var cancellables: Set<AnyCancellable> = []
	private let console: Atari2600 = .current
	
	convenience init() {
		self.init(nibName: nil, bundle: .main)
	}
	
	override func loadView() {
		let label = NSTextField(labelWithString: "")
		label.font = .monospacedRegular
		
		self.view = label
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.resetView(to: self.console.riot.memory)
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
						self.resetView(to: self.console.riot.memory)
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .break, .step:
						self.updateView(to: self.console.riot.memory)
					default:
						break
					}
				})
	}
	
	func resetView(to memory: Data) {
		let formatted = String(memory: memory)
		let string = NSMutableAttributedString(string: formatted)
		for index in memory.indices {
			string.resetMemoryValue(at: index)
		}
		
		let label = self.view as! NSTextField
		label.attributedStringValue = string
	}
	
	func updateView(to memory: Data) {
		let label = self.view as! NSTextField
		let string = NSMutableAttributedString(attributedString: label.attributedStringValue)
		for (index, value) in memory.enumerated() {
			string.setMemoryValue(value, at: index)
		}
		
		label.attributedStringValue = string
	}
}


// MARK: -
private extension NSMutableAttributedString {
	func resetMemoryValue(at index: Int) {
		let range = NSRange(location: index * 3, length: 2)
		let color: NSColor = .disabledControlTextColor
		
		self.addAttribute(.foregroundColor, value: color, range: range)
	}
	
	func setMemoryValue(_ value: UInt8, at index: Int) {
		let range = NSRange(location: index * 3, length: 2)
		let oldValue = self.mutableString.substring(with: range)
		let newValue = String(memoryValue: value)
		
		if newValue != oldValue {
			self.mutableString.replaceCharacters(in: range, with: newValue)
			self.removeAttribute(.foregroundColor, range: range)
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension String {
	init(memoryValue value: UInt8) {
		self = String(format: "%02x", value)
	}
	
	init(memory: Data) {
		self = memory.indices
			.stride(by: 16)
			.map() {
				return memory[$0]
					.map() { String(memoryValue: $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}

private extension Range where Index == Int {
	func stride(by count: Int) -> any Sequence<Self> {
		return Swift.stride(from: self.startIndex, to: self.endIndex, by: count)
			.map() { $0..<$0+count }
	}
}
