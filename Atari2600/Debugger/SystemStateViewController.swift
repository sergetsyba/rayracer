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
	
	override func viewWillAppear() {
		super.viewWillAppear()
		self.outlineView.expandTopItems()
	}
}


// MARK: -
// MARK: Outline view management
extension SystemStateViewController: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return Section.allCases.count
		} else if let section = item as? Section {
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
			return Section.allCases[index]
		} else if let section = item as? Section {
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
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is Section
	}
}

extension SystemStateViewController: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		if let section = item as? Section {
			return self.makeView(outlineView, forSectionItem: section)
		} else if let item = item as? CPUDebugItem {
			return self.makeView(outlineView, forCPUDebugItem: item)
		} else if let item = item as? MemoryDebugItem {
			return self.makeView(outlineView, forMemoryDebugItem: item)
		} else if let item = item as? TimerDebugItem {
			return self.makeView(outlineView, forTimerDebugItem: item)
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forSectionItem item: Section) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugSectionTableCellView, owner: nil) as? DebugSectionTableCellView
		view?.textField?.stringValue = item.rawValue
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forCPUDebugItem item: CPUDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		switch item {
		case .accumulator:
			view?.wordValue = (item.rawValue, self.console.cpu.accumulator)
		case .indexX:
			view?.wordValue = (item.rawValue, self.console.cpu.x)
		case .indexY:
			view?.wordValue = (item.rawValue, self.console.cpu.y)
		case .status:
			let string = NSMutableAttributedString(mos6507Status: self.console.cpu.status)
			view?.attributedStringValue = (item.rawValue, string)
		case .stackPointer:
			view?.wordValue = (item.rawValue, self.console.cpu.stackPointer)
		case .programCounter:
			view?.addressValue = (item.rawValue, self.console.cpu.programCounter)
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forMemoryDebugItem item: MemoryDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as? DebugValueTableCellView
		view?.textField?.stringValue = String(memory: self.console.riot.memory)
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forTimerDebugItem item: TimerDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		switch item {
		case .value:
			view?.stringValue = (item.rawValue, "\(self.console.riot.remainingTimerCycles)")
		case .interval:
			view?.stringValue = (item.rawValue, "\(self.console.riot.intervalIncrement)")
		}
		
		return view
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let debugSectionTableCellView = NSUserInterfaceItemIdentifier("DebugSectionTableCellView")
	static let debugValueTableCellView = NSUserInterfaceItemIdentifier("DebugValueTableCellView")
	static let debugItemTableCellView = NSUserInterfaceItemIdentifier("DebugItemTableCellView")
}


// MARK: -
// MARK: Outline view model
private extension SystemStateViewController {
	enum Section: String, CaseIterable {
		case cpu = "CPU"
		case memory = "Memory"
		case timer = "Timer"
		
		static var allCases: [Section] {
			return [
				.cpu,
				.memory,
				.timer
			]
		}
	}
	
	private enum CPUDebugItem: String, CaseIterable {
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
	}
	
	private enum MemoryDebugItem: String, CaseIterable {
		case memory = "Memory"
		
		static var allCases: [MemoryDebugItem] {
			return [
				.memory
			]
		}
	}
	
	private enum TimerDebugItem: String, CaseIterable {
		case value = "Remaining cycles"
		case interval = "Interval"
		
		static var allCases: [TimerDebugItem] {
			return [
				.value,
				.interval
			]
		}
	}
}


// MARK: -
// MARK: Data formatting
private extension String {
	init(memory: Data) {
		self = memory.indices
			.split(by: 16)
			.map() {
				return memory[$0]
					.map() { String(format: "%02x", $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}

private extension NSMutableAttributedString {
	convenience init(mos6507Status status: MOS6507.Status) {
		self.init(string: "N V   B D I Z C")
		for (index, value) in status.enumerated() {
			if !value {
				let range = NSRange(location: index * 2, length: 1)
				self.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
			}
		}
	}
}


// MARK: -
// MARK: Convenience functionality
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
