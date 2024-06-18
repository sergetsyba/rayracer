//
//  SystemStateViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 29.5.2024.
//

import Cocoa
import Atari2600Kit

class SystemStateViewController: NSViewController {
	@IBOutlet private var outlineView: NSOutlineView!
	
	private let console: Atari2600 = .current
	
	convenience init() {
		self.init(nibName: "SystemStateView", bundle: .main)
	}
}


// MARK: -
// MARK: View lifecycle
extension SystemStateViewController {
	override func viewWillAppear() {
		super.viewWillAppear()
		
		for section in DebugSection.allCases {
			self.outlineView.expandItem(section)
		}
	}
}


// MARK: -
// MARK: Outline view management
extension SystemStateViewController: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return DebugSection.allCases.count
		} else if let section = item as? DebugSection {
			switch section {
			case .cpu:
				return CPUDebugItem.allCases.count
			case .memory:
				return MemoryDebugItem.allCases.count
			case .timer:
				return TimerDebugItem.allCases.count
			}
		} else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return DebugSection.allCases[index]
		} else if let section = item as? DebugSection {
			switch section {
			case .cpu:
				return CPUDebugItem.allCases[index]
			case .memory:
				return MemoryDebugItem.allCases[index]
			case .timer:
				return TimerDebugItem.allCases[index]
			}
		} else {
			return 0
		}
	}
}

extension SystemStateViewController: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .systemStateTableCellView, owner: self) as! NSTableCellView
		view.textField?.font = .systemRegular
		
		if let section = item as? DebugSection {
			view.textField?.stringValue = section.description
			view.textField?.font = .systemBold
		} else if let item = item as? CPUDebugItem {
			view.textField?.attributedStringValue = self.formatDebugItem(item)
		} else if let item = item as? MemoryDebugItem {
			view.textField?.attributedStringValue = self.formatDebugItem(item)
		} else if let item = item as? TimerDebugItem {
			view.textField?.attributedStringValue = self.formatDebugItem(item)
		}
		
		return view
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is DebugSection
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let systemStateTableCellView = NSUserInterfaceItemIdentifier("SystemStateTableCellView")
}


private enum DebugSection: String, CaseIterable, CustomStringConvertible {
	case cpu = "CPU"
	case memory = "Memory"
	case timer = "Timer"
	
	static var allCases: [DebugSection] {
		return [
			.cpu,
			.memory,
			.timer
		]
	}
	
	var description: String {
		return self.rawValue
	}
}

private enum CPUDebugItem: String, CaseIterable, CustomStringConvertible {
	case accumulator = "Accumulator"
	case indexX = "X"
	case indexY = "Y"
	case status = "Status"
	case stackPointer = "Stack pointer"
	case programCounter = "Program counter"
	
	static var allCases: [CPUDebugItem] {
		return [
			.accumulator,
			.indexX,
			.indexY,
			.status,
			.stackPointer,
			.programCounter
		]
	}
	
	var description: String {
		return self.rawValue
	}
}

private enum MemoryDebugItem: String, CaseIterable, CustomStringConvertible {
	case memory = "Memory"
	
	static var allCases: [MemoryDebugItem] {
		return [
			.memory
		]
	}
	
	var description: String {
		return self.rawValue
	}
}

private enum TimerDebugItem: String, CaseIterable, CustomStringConvertible {
	case value = "Remaining cycles"
	case interval = "Interval"
	
	static var allCases: [TimerDebugItem] {
		return [
			.value,
			.interval
		]
	}
	
	var description: String {
		return self.rawValue
	}
}


// MARK: -
// MARK: Data formatting
private extension SystemStateViewController {
	private static let attributes: [NSAttributedString.Key: Any] = [
		.font: NSFont.monospacedRegular
	]
	
	func formatDebugItem(_ item: CPUDebugItem) -> NSAttributedString {
		switch item {
		case .accumulator:
			let value = String(format: "%02x", self.console.cpu.accumulator)
			return NSAttributedString(debugItem: item, value: value)
			
		case .indexX:
			let value = String(format: "%02x", self.console.cpu.x)
			return NSAttributedString(debugItem: item, value: value)
			
		case .indexY:
			let value = String(format: "%02x", self.console.cpu.y)
			return NSAttributedString(debugItem: item, value: value)
			
		case .status:
			let value = self.formatCPUStatus(self.console.cpu.status)
			return NSAttributedString(debugItem: item, value: value)
			
		case .stackPointer:
			let value = String(format: "%02x", self.console.cpu.stackPointer)
			return NSAttributedString(debugItem: item, value: value)
			
		case .programCounter:
			let value = String(format: "$%04x", self.console.cpu.programCounter)
			return NSAttributedString(debugItem: item, value: value)
		}
	}
	
	private func formatCPUStatus(_ status: MOS6507.Status) -> NSAttributedString {
		let string = NSMutableAttributedString(string: "N V   B D I Z C")
		for (index, value) in status.enumerated() {
			if !value {
				let range = NSRange(location: index * 2, length: 1)
				string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
			}
		}
		
		return string
	}
	
	func formatDebugItem(_ item: MemoryDebugItem) -> NSAttributedString {
		let string = self.console.riot.memory.indices
			.split(by: 16)
			.map() {
				return self.console.riot.memory[$0]
					.map() { String(format: "%02x", $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
		
		return NSAttributedString(string: string, attributes: Self.attributes)
	}
	
	func formatDebugItem(_ item: TimerDebugItem) -> NSAttributedString {
		switch item {
		case .value:
			let value = "\(self.console.riot.remainingTimerCycles)"
			return NSAttributedString(debugItem: item, value: value)
			
		case .interval:
			let value = "\(self.console.riot.intervalIncrement)"
			return NSAttributedString(debugItem: item, value: value)
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSAttributedString {
	private static let valueAttributes: [NSAttributedString.Key: Any] = [
		.font: NSFont.monospacedRegular
	]
	
	convenience init(debugItem item: any CustomStringConvertible, value: String) {
		let string1 = NSMutableAttributedString(string: "\(item) = ")
		let string2 = NSAttributedString(string: value, attributes: Self.valueAttributes)
		string1.append(string2)
		
		self.init(attributedString: string1)
	}
	
	convenience init(debugItem item: any CustomStringConvertible, value: NSAttributedString) {
		let string = NSMutableAttributedString(string: "\(item.description) = ")
		string.append(value)
		
		self.init(attributedString: string)
	}
}

private extension Range where Index == Int {
	func split(by count: Int) -> any Sequence<Self> {
		return Swift.stride(from: self.startIndex, to: self.endIndex, by: count)
			.map() { $0..<$0+count }
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
