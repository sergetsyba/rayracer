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
	@IBOutlet private var ramLabel: NSTextField!
	
	private var cancellables: Set<AnyCancellable> = []
	private let console: Atari2600 = .current
	
	convenience init() {
		self.init(nibName: "MemoryView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.resetView()
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension MemoryViewController {
	func setUpSinks() {
		self.console.cpu.events
			.receive(on: DispatchQueue.main)
			.sink() { [unowned self] in
				switch $0 {
				case .reset:
					self.resetView()
				case .sync:
					self.clearMemoryHighlights()
				}
			}.store(in: &self.cancellables)
		
		self.console.riot.events
			.receive(on: DispatchQueue.main)
			.sink() {
				switch $0 {
				case .readMemory(let address):
					self.highlightMemory(at: address)
				case .writeMemoty(let address):
					self.highlightMemory(at: address)
				}
			}.store(in: &self.cancellables)
	}
	
	func resetView() {
		self.ramLabel.font = .regular
		self.ramLabel.attributedStringValue = NSAttributedString(
			string: String(memory: self.console.riot.memory))
	}
	
	func highlightMemory(at address: Address) {
		let data = self.console.riot.memory[address]
		let range = NSRange(location: address * 3, length: 2)
		
		self.ramLabel[range] = String(word: data)
		self.ramLabel.addHighlight(in: range)
	}
	
	func clearMemoryHighlights() {
		self.ramLabel.removeHighlights()
	}
}


// MARK: -
// MARK: Data formatting
private extension String {
	init(word: Int) {
		self.init(format: "%02x", word)
	}
	
	init(word: UInt8) {
		self.init(format: "%02x", word)
	}
	
	init(memory: Data) {
		self = memory.indices
			.stride(by: 16)
			.map() {
				return memory[$0]
					.map() { String(word: $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSTextField {
	subscript (range: NSRange) -> any StringProtocol {
		get {
			let string = self.attributedStringValue.string
			let start = string.index(string.startIndex, offsetBy: range.location)
			let end = string.index(start, offsetBy: range.length)
			
			return self.attributedStringValue.string[start..<end]
		}
		set {
			let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
			string.replaceCharacters(in: range, with: String(newValue))
			
			self.attributedStringValue = string
		}
	}
	
	func addHighlight(in range: NSRange) {
		let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
		string.setAttributes([
			.font: NSFont.emphasized,
			.foregroundColor: NSColor.labelColor
		], range: range)
		
		self.attributedStringValue = string
	}
	
	func removeHighlights() {
		let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
		let range = NSRange(location: 0, length: string.length)
		string.removeAttribute(.font, range: range)
		
		self.attributedStringValue = string
	}
}

private extension Range where Index == Int {
	func stride(by count: Int) -> any Sequence<Self> {
		return Swift.stride(from: self.startIndex, to: self.endIndex, by: count)
			.map() { $0..<$0+count }
	}
}
