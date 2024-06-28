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
		self.outlineView.expandAllItems()
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
			case .graphics:
				return GraphicsDebugSection.allCases.count
			}
		} else if let section = item as? GraphicsDebugSection {
			switch section {
			case .frame:
				return FrameDebugItem.allCases.count
			case .background:
				return BackgroundDebugItem.allCases.count
			case .playField:
				return PlayFieldDebugItem.allCases.count
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
			case .graphics:
				return GraphicsDebugSection.allCases[index]
			}
		} else if let section = item as? GraphicsDebugSection {
			switch section {
			case .frame:
				return FrameDebugItem.allCases[index]
			case .background:
				return BackgroundDebugItem.allCases[index]
			case .playField:
				return PlayFieldDebugItem.allCases[index]
			}
		} else {
			return 0
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		return item is DebugSection || item is GraphicsDebugSection
	}
}

extension SystemStateViewController: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		if let section = item as? DebugSection {
			return self.makeView(outlineView, forSectionItem: section)
		} else if let item = item as? CPUDebugItem {
			return self.makeView(outlineView, forCPUDebugItem: item)
		} else if let item = item as? MemoryDebugItem {
			return self.makeView(outlineView, forMemoryDebugItem: item)
		} else if let item = item as? TimerDebugItem {
			return self.makeView(outlineView, forTimerDebugItem: item)
		} else if let section = item as? GraphicsDebugSection {
			return self.makeView(outlineView, forSectionItem: section)
		} else if let item = item as? FrameDebugItem {
			return self.makeView(outlineView, forFrameDebugItem: item)
		} else if let item = item as? BackgroundDebugItem {
			return self.makeView(outlineView, forBackgroundDebugItem: item)
		} else if let item = item as? PlayFieldDebugItem {
			return self.makeView(outlineView, forPlayFieldDebugItem: item)
		} else {
			return nil
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forSectionItem item: any RawRepresentable<String>) -> NSView? {
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
	
	private func makeView(_ outlineView: NSOutlineView, forFrameDebugItem item: FrameDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		switch item {
		case .beamPosition:
			let (scanLine, point) = self.console.tia.beamPosition
			view?.stringValue = (item.rawValue, "\(scanLine):\(point)")
		case .waitForSync:
			view?.boolValue = (item.rawValue, self.console.tia.awaitingHorizontalSync)
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forBackgroundDebugItem item: BackgroundDebugItem) -> NSView? {
		switch item {
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.backgroundColor)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forPlayFieldDebugItem item: PlayFieldDebugItem) -> NSView? {
		switch item {
		case .pattern:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, self.formatPlayFieldGraphics())
			return view
			
		case .reflected:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.playfield.reflected)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.playfield.color)
			return view
		}
	}
	
	private func formatPlayFieldGraphics() -> String {
		let graphics = self.console.tia.playfield.graphics
		let values = graphics
			.map({ String(format: "%02x", $0) })
			.joined()
		
		let pattern = graphics.map({
			return $0[0..<8]
				.map({ $0 ? "■" : "□" })
				.joined()
		}).joined()
		
		return "\(values)  \(pattern.suffix(20))"
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let debugSectionTableCellView = NSUserInterfaceItemIdentifier("DebugSectionTableCellView")
	static let debugValueTableCellView = NSUserInterfaceItemIdentifier("DebugValueTableCellView")
	static let debugItemTableCellView = NSUserInterfaceItemIdentifier("DebugItemTableCellView")
	static let debugColorTableCellView = NSUserInterfaceItemIdentifier("DebugColorTableCellView")
}


// MARK: -
// MARK: Outline view model
private extension SystemStateViewController {
	enum DebugSection: String, CaseIterable {
		case cpu = "CPU"
		case memory = "Memory"
		case timer = "Timer"
		case graphics = "Graphics"
	}
	
	enum FrameDebugItem: String, CaseIterable {
		case beamPosition = "Beam position"
		case waitForSync = "Wait for sync"
	}
	
	private enum CPUDebugItem: String, CaseIterable {
		case accumulator = "Accumulator"
		case indexX = "X"
		case indexY = "Y"
		case status = "Status"
		case stackPointer = "Stack pointer"
		case programCounter = "Program counter"
	}
	
	private enum MemoryDebugItem: String, CaseIterable {
		case memory = "Memory"
	}
	
	private enum TimerDebugItem: String, CaseIterable {
		case value = "Remaining cycles"
		case interval = "Interval"
	}
	
	private enum GraphicsDebugSection: String, CaseIterable {
		case frame = "Frame"
		case background = "Background"
		case playField = "Play field"
		//		case player0 = "Player 0"
		//		case player1 = "Player 1"
		//		case missile0 = "Missile 0"
		//		case missile1 = "Missile 1"
		//		case ball = "Ball"
	}
	
	enum BackgroundDebugItem: String, CaseIterable {
		case color = "Color"
	}
	
	enum PlayFieldDebugItem: String, CaseIterable {
		case pattern = "Pattern"
		case reflected = "Reflected"
		case color = "Color"
	}
	
	enum PlayerDebugItem: String, CaseIterable {
		case enabled = "Enabled"
		case pattern = "Pattern"
		case copies = "Copies"
		case reflected = "Reflected"
		case color = "Color"
		case position = "Position"
		case verticalDelay = "Vertical delay"
		case reset = "Reset"
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
