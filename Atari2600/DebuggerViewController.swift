//
//  DebuggerViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 3.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit


class DebuggerViewController: NSViewController {
	@IBOutlet private var accumulatorLabel: NSTextField!
	@IBOutlet private var xLabel: NSTextField!
	@IBOutlet private var yLabel: NSTextField!
	@IBOutlet private var stackPointerLabel: NSTextField!
	@IBOutlet private var programCounterLabel: NSTextField!
	
	@IBOutlet private var negativeStatusLabel: NSTextField!
	@IBOutlet private var overflowStatusLabel: NSTextField!
	@IBOutlet private var breakStatusLabel: NSTextField!
	@IBOutlet private var decimalStatusLabel: NSTextField!
	@IBOutlet private var interruptDisabledStatusLabel: NSTextField!
	@IBOutlet private var zeroStatusLabel: NSTextField!
	@IBOutlet private var carryStatusLabel: NSTextField!
	
	@IBOutlet private var tiaRegistersLabel: NSTextField!
	@IBOutlet private var ramLabel: NSTextField!
	@IBOutlet private var riotRegistersLabel: NSTextField!
	
	private var cancellables = Set<AnyCancellable>()
	
	var console: Atari2600? {
		didSet {
			if self.isViewLoaded {
				self.clearSinks()
				self.setUpSinks()
			}
		}
	}
	
	convenience init() {
		self.init(nibName: "DebuggerView", bundle: .main)
	}
	
	override func viewDidLoad() {
		self.setUpSinks()
	}
}

private extension DebuggerViewController {
	func setUpSinks() {
		self.console?.cpu.$accumulator
			.map() { String(format: "%02x", $0) }
			.assign(to: \.stringValue, on: self.accumulatorLabel)
			.store(in: &self.cancellables)
		
		self.console?.cpu.$x
			.map() { String(format: "%02x", $0) }
			.assign(to: \.stringValue, on: self.xLabel)
			.store(in: &self.cancellables)
		
		self.console?.cpu.$y
			.map() { String(format: "%02x", $0) }
			.assign(to: \.stringValue, on: self.yLabel)
			.store(in: &self.cancellables)
		
		self.console?.cpu.$status
			.sink() { status in
				self.negativeStatusLabel.isEnabled = status.negative
				self.overflowStatusLabel.isEnabled = status.overflow
				self.breakStatusLabel.isEnabled = status.break
				self.decimalStatusLabel.isEnabled = status.decimal
				self.interruptDisabledStatusLabel.isEnabled = status.interruptDisabled
				self.zeroStatusLabel.isEnabled = status.zero
				self.carryStatusLabel.isEnabled = status.carry
			}.store(in: &self.cancellables)
		
		self.console?.cpu.$stackPointer
			.map() { String(format: "%02x", $0) }
			.assign(to: \.stringValue, on: self.stackPointerLabel)
			.store(in: &self.cancellables)
		
		self.console?.cpu.$programCounter
			.map() { String(format: "$%04x", $0) }
			.assign(to: \.stringValue, on: self.programCounterLabel)
			.store(in: &self.cancellables)
		
		self.console?.$memory.sink() { [unowned self] in
			self.tiaRegistersLabel.stringValue = $0.tiaRegisters.formatted
			self.ramLabel.stringValue = $0.ram.formatted
			self.riotRegistersLabel.stringValue = $0.riotRegisters.formatted
		}.store(in: &self.cancellables)
	}
	
	private func clearSinks() {
		for cancellable in self.cancellables {
			cancellable.cancel()
		}
	}
}


// MARK: -
// MARK: Data formatting
private extension Memory {
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


// MARK: -
// MARK: Convenience functionality
class DebuggerValueLabel: NSTextField {
	override var isEnabled: Bool {
		didSet {
			self.textColor = self.isEnabled ?
				.controlTextColor :
				.disabledControlTextColor
		}
	}
}

private extension Memory {
	var tiaRegisters: Self {
		self.subdata(in: 0x0000..<0x003e)
	}
	
	var ram: Self {
		self.subdata(in: 0x0080..<0x0100)
	}
	
	var riotRegisters: Self {
		self.subdata(in: 0x0280..<0x0298)
	}
}

private extension NSFont {
	static let valueFont: NSFont = .monospacedSystemFont(ofSize: 11.0, weight: .regular)
}
