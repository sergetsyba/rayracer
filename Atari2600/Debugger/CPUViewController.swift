//
//  CPUViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 9.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class CPUViewController: NSViewController {
	@IBOutlet private var accumulatorLabel: DebuggerValueLabel!
	@IBOutlet private var indexXLabel: DebuggerValueLabel!
	@IBOutlet private var indexYLabel: DebuggerValueLabel!
	@IBOutlet private var statusLabel: DebuggerValueLabel!
	
	@IBOutlet private var stackPointerLabel: DebuggerValueLabel!
	@IBOutlet private var programCounterLabel: DebuggerValueLabel!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: "CPUView", bundle: .main)
		self.title = "CPU"
	}
}


// MARK: -
// MARK: View lifecycle
extension CPUViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		self.resetView(self.console.cpu)
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension CPUViewController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .reset:
						self.resetView(self.console.cpu)
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .break, .step:
						self.updateView(self.console.cpu)
					default:
						break
					}
				}
		)
	}
	
	func resetView(_ cpu: MOS6507) {
		self.accumulatorLabel.reset(word: cpu.accumulator)
		self.indexXLabel.reset(word: cpu.x)
		self.indexYLabel.reset(word: cpu.y)
		self.statusLabel.attributedStringValue = NSMutableAttributedString(status: cpu.status)
		
		self.stackPointerLabel.reset(word: cpu.stackPointer)
		self.programCounterLabel.reset(address: cpu.programCounter)
	}
	
	func updateView(_ cpu: MOS6507) {
		self.accumulatorLabel.update(word: cpu.accumulator)
		self.indexXLabel.update(word: cpu.x)
		self.indexYLabel.update(word: cpu.y)
		self.statusLabel.update(status: cpu.status)
		
		self.stackPointerLabel.update(word: cpu.stackPointer)
		self.programCounterLabel.update(address: cpu.programCounter)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension DebuggerValueLabel {
	func reset(word: Int) {
		let newValue = String(word: word)
		self.reset(newValue)
	}
	
	func reset(address: Int) {
		let newValue = String(address: address)
		self.reset(newValue)
	}
	
	func update(word: Int) {
		let newValue = String(word: word)
		self.update(newValue)
	}
	
	func update(address: Int) {
		let newValue = String(address: address)
		self.update(newValue)
	}
	
	func update(status: MOS6507.Status) {
		let string = NSMutableAttributedString(attributedString: self.attributedStringValue)
		string.update(status: status)
		self.attributedStringValue = string
	}
}

internal extension String {
	init(word: Int) {
		self = String(format: "%02x", word)
	}
	
	init(address: Int) {
		self = String(format: "$%04x", address)
	}
}

private extension NSMutableAttributedString {
	convenience init(status: MOS6507.Status) {
		self.init(string: "N V   B D I Z C")
		self.update(status: status)
	}
	
	func update(status: MOS6507.Status) {
		for (index, on) in status.enumerated() {
			self.update(statusValue: on, at: index)
		}
	}
	
	func update(statusValue on: Bool, at index: Int) {
		let range = NSRange(location: index * 2, length: 1)
		if on {
			let color: NSColor = .controlTextColor
			self.addAttribute(.foregroundColor, value: color, range: range)
		} else {
			self.removeAttribute(.foregroundColor, range: range)
		}
	}
}

extension MOS6507.Status: Sequence {
	public func makeIterator() -> some IteratorProtocol<Bool> {
		return [
			self.negative,
			self.overflow,
			false,
			self.break,
			self.decimalMode,
			self.interruptDisabled,
			self.zero,
			self.carry
		].makeIterator()
	}
}
