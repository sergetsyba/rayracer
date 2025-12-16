//
//  SystemStateViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 29.5.2024.
//

import Cocoa

class SystemStateViewController: NSViewController {
	@IBOutlet private var outlineView: NSOutlineView!
	
	var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
	}
	
	convenience init() {
		self.init(nibName: "SystemStateView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.setUpNotifications()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		self.outlineView.expandItem(nil, expandChildren: true)
	}
}


// MARK: -
private extension SystemStateViewController {
	func setUpNotifications() {
		let center: NotificationCenter = .default
		center.addObserver(forName: .reset, object: nil, queue: .main) { _ in
			self.outlineView.reloadData()
		}
		center.addObserver(forName: .break, object: nil, queue: .main) { _ in
			self.outlineView.reloadData()
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
			case .graphics:
				return GraphicsDebugSection.allCases.count
			}
		} else if let section = item as? GraphicsDebugSection {
			switch section {
			case .screen:
				return ScreenDebugItem.allCases.count
			case .background:
				return BackgroundDebugItem.allCases.count
			case .playField:
				return PlayfieldDebugItem.allCases.count
			case .player0:
				return Player0DebugItem.allCases.count
			case .player1:
				return Player1DebugItem.allCases.count
			case .missile0:
				return Missile0DebugItem.allCases.count
			case .missile1:
				return Missile1DebugItem.allCases.count
			case .ball:
				return BallDebugItem.allCases.count
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
			case .screen:
				return ScreenDebugItem.allCases[index]
			case .background:
				return BackgroundDebugItem.allCases[index]
			case .playField:
				return PlayfieldDebugItem.allCases[index]
			case .player0:
				return Player0DebugItem.allCases[index]
			case .player1:
				return Player1DebugItem.allCases[index]
			case .missile0:
				return Missile0DebugItem.allCases[index]
			case .missile1:
				return Missile1DebugItem.allCases[index]
			case .ball:
				return BallDebugItem.allCases[index]
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
		//		if let section = item as? DebugSection {
		//			return self.makeView(outlineView, forSectionItem: section)
		//		} else if let item = item as? CPUDebugItem {
		//			return self.makeView(outlineView, forCPUDebugItem: item)
		//		} else if let item = item as? MemoryDebugItem {
		//			return self.makeView(outlineView, forMemoryDebugItem: item)
		//		} else if let item = item as? TimerDebugItem {
		//			return self.makeView(outlineView, forTimerDebugItem: item)
		//		} else if let section = item as? GraphicsDebugSection {
		//			return self.makeView(outlineView, forSectionItem: section)
		//		} else if let item = item as? ScreenDebugItem {
		//			return self.makeView(outlineView, forScreenDebugItem: item)
		//		} else if let item = item as? Player0DebugItem {
		//			return self.makeView(outlineView, forPlayer0DebugItem: item)
		//		} else if let item = item as? Player1DebugItem {
		//			return self.makeView(outlineView, forPlayer1DebugItem: item)
		//		} else if let item = item as? Missile0DebugItem {
		//			return self.makeView(outlineView, forMissile0DebugItem: item)
		//		} else if let item = item as? Missile1DebugItem {
		//			return self.makeView(outlineView, forMissile1DebugItem: item)
		//		} else if let item = item as? BallDebugItem {
		//			return self.makeView(outlineView, forBallDebugItem: item)
		//		} else if let item = item as? PlayfieldDebugItem {
		//			return self.makeView(outlineView, forPlayfieldDebugItem: item)
		//		} else if let item = item as? BackgroundDebugItem {
		//			return self.makeView(outlineView, forBackgroundDebugItem: item)
		//		} else {
		//			return nil
		//		}
		return nil
	}
	
	private func makeView(_ outlineView: NSOutlineView, forSectionItem item: any RawRepresentable<String>) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugSectionTableCellView, owner: nil) as? DebugSectionTableCellView
		view?.textField?.stringValue = item.rawValue
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forCPUDebugItem item: CPUDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		let cpu = self.console.ref.pointee.mpu.pointee
		
		switch item {
		case .accumulator:
			view?.wordValue = (item.rawValue, cpu.accumulator)
		case .indexX:
			view?.wordValue = (item.rawValue, cpu.x)
		case .indexY:
			view?.wordValue = (item.rawValue, cpu.y)
		case .status:
			let status = MCS6507.Status(rawValue: cpu.status)
			view?.attributedStringValue = (item.rawValue, self.format(mcs6507Status: status))
		case .stackPointer:
			view?.wordValue = (item.rawValue, cpu.stack_pointer)
		case .programCounter:
			view?.addressValue = (item.rawValue, cpu.program_counter)
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forMemoryDebugItem item: MemoryDebugItem) -> NSView? {
		var riot = self.console.ref.pointee.riot.pointee
		let data = withUnsafeBytes(of: &riot.memory) {
			let bytes = $0.bindMemory(to: UInt8.self)
			return Data(bytes)
		}
		
		let view = outlineView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as? DebugValueTableCellView
		view?.textField?.stringValue = self.format(memory: data)
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forTimerDebugItem item: TimerDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		let riot = self.console.ref.pointee.riot.pointee
		
		switch item {
		case .value:
			view?.stringValue = (item.rawValue, "\(riot.timer)")
		case .interval:
			view?.stringValue = (item.rawValue, "\(1 << riot.timer_scale)")
		}
		
		return view
	}
	
	//	private func makeView(_ outlineView: NSOutlineView, forScreenDebugItem item: ScreenDebugItem) -> NSView? {
	//		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//		let tia = self.console.tia!
	//
	//		switch item {
	//		case .beamPosition:
	//			view?.stringValue = (item.rawValue, "todo" /*"\(tia.scanLine), \(tia.colorClock - 68)"*/)
	//		case .verticalSync:
	//			view?.boolValue = (item.rawValue, tia.isVerticalSyncEnabled)
	//		case .verticalBlank:
	//			view?.boolValue = (item.rawValue, tia.isVerticalBlankEnabled)
	//		case .waitForHorizontalSync:
	//			view?.boolValue = (item.rawValue, tia.awaitsHorizontalSync)
	//		}
	//
	//		return view
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forPlayer0DebugItem item: Player0DebugItem) -> NSView? {
	//		let player = self.console.tia.players.0
	//
	//		switch item {
	//		case .graphics:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.attributedStringValue = (item.rawValue, self.formatGraphics(of: player))
	//			return view
	//
	//		case .reflect:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, player.options[.reflected])
	//			return view
	//
	//		case .copies:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCopies(of: player))
	//			return view
	//
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, 0)
	//			return view
	//
	//		case .position:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.positionValue = (item.rawValue, player.position, player.motion)
	//			return view
	//
	//		case .delay:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, player.options[.delayed])
	//			return view
	//
	//		case .collisions:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCollisions(of: .player0))
	//			return view
	//		}
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forPlayer1DebugItem item: Player1DebugItem) -> NSView? {
	//		let player = self.console.tia.players.1
	//
	//		switch item {
	//		case .graphics:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.attributedStringValue = (item.rawValue, self.formatGraphics(of: player))
	//			return view
	//
	//		case .reflect:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, player.options[.reflected])
	//			return view
	//
	//		case .copies:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCopies(of: player))
	//			return view
	//
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, 0)
	//			return view
	//
	//		case .position:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.positionValue = (item.rawValue, player.position, player.motion)
	//			return view
	//
	//		case .delay:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, player.options[.delayed])
	//			return view
	//
	//		case .collisions:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCollisions(of: .player1))
	//			return view
	//		}
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forMissile0DebugItem item: Missile0DebugItem) -> NSView? {
	//		let missile = self.console.tia.missiles.0
	//
	//		switch item {
	//		case .enabled:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, missile.options[.enabled])
	//			return view
	//
	//		case .graphics:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatGraphics(width: missile.size))
	//			return view
	//
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, 0)
	//			return view
	//
	//		case .position:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.positionValue = (item.rawValue, missile.position, missile.motion)
	//			return view
	//
	//		case .collisions:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCollisions(of: .missile0))
	//			return view
	//		}
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forMissile1DebugItem item: Missile1DebugItem) -> NSView? {
	//		let missile = self.console.tia.missiles.1
	//
	//		switch item {
	//		case .enabled:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, missile.options[.enabled])
	//			return view
	//
	//		case .graphics:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatGraphics(width: missile.size))
	//			return view
	//
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, 0)
	//			return view
	//
	//		case .position:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.positionValue = (item.rawValue, missile.position, missile.motion)
	//			return view
	//
	//		case .collisions:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCollisions(of: .missile1))
	//			return view
	//		}
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forBallDebugItem item: BallDebugItem) -> NSView? {
	//		let ball = self.console.tia.ball
	//
	//		switch item {
	//		case .enabled:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.attributedStringValue = (item.rawValue, self.formatEnabled(of: ball))
	//			return view
	//
	//		case .graphics:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatGraphics(width: ball.size))
	//			return view
	//
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, 0 /*self.console.tia.playfield.color*/)
	//			return view
	//
	//		case .position:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.positionValue = (item.rawValue, ball.position, ball.motion)
	//			return view
	//
	//		case .verticalDelay:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.boolValue = (item.rawValue, ball.options[.delayed])
	//			return view
	//
	//		case .collisions:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCollisions(of: .ball))
	//			return view
	//		}
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forPlayfieldDebugItem item: PlayfieldDebugItem) -> NSView? {
	//		let playfield = self.console.tia.playfield
	//
	//		switch item {
	//		case .graphics:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatGraphics(of: playfield))
	//			return view
	//
	//		case .secondHalf:
	//			let formatted = playfield.options.contains(.reflected) ? "Reflect" : "Duplicate"
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, formatted)
	//			return view
	//
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, 0 /*playfield.color*/)
	//			return view
	//
	//		case .collisions:
	//			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
	//			view?.stringValue = (item.rawValue, self.formatCollisions(of: .playfield))
	//			return view
	//		}
	//	}
	//
	//	private func makeView(_ outlineView: NSOutlineView, forBackgroundDebugItem item: BackgroundDebugItem) -> NSView? {
	//		let backgroundColor = 0//self.console.tia.backgroundColor
	//
	//		switch item {
	//		case .color:
	//			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
	//			view?.colorValue = (item.rawValue, backgroundColor)
	//			return view
	//		}
	//	}
}

private extension NSUserInterfaceItemIdentifier {
	static let debugSectionTableCellView = NSUserInterfaceItemIdentifier("DebugSectionTableCellView")
	static let debugValueTableCellView = NSUserInterfaceItemIdentifier("DebugValueTableCellView")
	static let debugItemTableCellView = NSUserInterfaceItemIdentifier("DebugItemTableCellView")
	static let debugColorTableCellView = NSUserInterfaceItemIdentifier("DebugColorTableCellView")
}


// MARK: -
// MARK: Data formatting
private extension SystemStateViewController {
	private func format(mcs6507Status status: MCS6507.Status) -> NSAttributedString {
		let string = NSMutableAttributedString(string: "N V B D I Z C")
		let values = MCS6507.Status.allCases
		
		for (index, value) in values.enumerated() {
			if status.contains(value) == false {
				let range = NSRange(location: index * 2, length: 1)
				string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
			}
		}
		
		return string
	}
	
	private func format(memory data: Data) -> String {
		return data.indices
			.split(by: 16)
			.map() {
				return data[$0]
					.map() { String(format: "%02x", $0) }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
	
	//	private func formatGraphics(of player: TIA.Player) -> NSAttributedString {
	//		let formatted = (
	//			self.formatPlayerGraphics(Int(player.graphics.0), reflected: player.options[.reflected]),
	//			self.formatPlayerGraphics(Int(player.graphics.1), reflected: player.options[.reflected]))
	//
	//		let string = NSMutableAttributedString(string: formatted.0 + "  " + formatted.1)
	//		let range = player.options[.delayed]
	//		? NSRange(location: 0, length: formatted.0.count)
	//		: NSRange(location: formatted.0.count + 2, length: formatted.1.count)
	//
	//		string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
	//		return string
	//	}
	//
	//	private func formatPlayerGraphics(_ graphics: Int, reflected: Bool) -> String {
	//		let value = String(format: "%02x", graphics)
	//		var pattern = stride(from: 7, through: 0, by: -1)
	//			.map({ graphics[$0] ? "■": "□" })
	//			.joined()
	//
	//		if reflected {
	//			pattern = String(pattern.reversed())
	//		}
	//
	//		return "\(value) \(pattern)"
	//	}
	//
	//	private func formatCopies(of player: TIA.Player) -> String {
	//		switch player.copyMask {
	//		case 0: return "1, single size"
	//		case 1: return "2, close"
	//		case 2: return "2, medium"
	//		case 3: return "3, close"
	//		case 4: return "2, wide"
	//		case 5: return "1, double size"
	//		case 6: return "3, medium"
	//		case 7: return "1, quadruple size"
	//		default: fatalError()
	//		}
	//	}
	//
	//	private func formatGraphics(width: Int) -> String {
	//		return (0..<width)
	//			.map({ _ in "■" })
	//			.joined()
	//	}
	//
	//	private func formatEnabled(of ball: TIA.Ball) -> NSAttributedString {
	//		let formatted = (
	//			ball.options[.enabled0] ? "Yes" : "No",
	//			ball.options[.enabled1] ? "Yes" : "No")
	//
	//		let string = NSMutableAttributedString(string: "\(formatted.0)  \(formatted.1)")
	//		let range = ball.options[.delayed]
	//		? NSRange(location: 0, length: formatted.0.count)
	//		: NSRange(location: formatted.0.count + 2, length: formatted.1.count)
	//
	//		string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
	//		return string
	//	}
	//
	//	private func formatGraphics(of playfield: TIA.Playfield) -> String {
	//		let values = playfield.graphics2
	//			.map({ String(format: "%02x", $0) })
	//			.joined(separator: " ")
	//
	////		let pattern = (0..<20)
	////			.map({ playfield.graphics[$0] ? "■": "□" })
	////			.joined()
	//
	//		let pattern = ""
	//		return "\(values) \(pattern.suffix(20))"
	//	}
	//
	//	private func formatCollisions(of object: TIA.GraphicsObject) -> String {
	//		let objects = self.console.tia
	//			.collisions(of: object)
	//			.map({ $0.rawValue })
	//
	//		return objects.isEmpty
	//		? "None"
	//		: objects.joined(separator: ", ")
	//	}
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
	
	enum ScreenDebugItem: String, CaseIterable {
		case beamPosition = "Beam position"
		case verticalSync = "Vertical sync"
		case verticalBlank = "Vertical blank"
		case waitForHorizontalSync = "Wait for horizontal sync"
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
		case screen = "Screen"
		case player0 = "Player 0"
		case missile0 = "Missile 0"
		case player1 = "Player 1"
		case missile1 = "Missile 1"
		case ball = "Ball"
		case playField = "Play field"
		case background = "Background"
	}
	
	enum Player0DebugItem: String, CaseIterable {
		case graphics = "Graphics"
		case reflect = "Reflect"
		case copies = "Copies"
		case color = "Color"
		case position = "Position"
		case delay = "Delay"
		case collisions = "Collisions"
	}
	
	enum Player1DebugItem: String, CaseIterable {
		case graphics = "Graphics"
		case reflect = "Reflect"
		case copies = "Copies"
		case color = "Color"
		case position = "Position"
		case delay = "Delay"
		case collisions = "Collisions"
	}
	
	enum Missile0DebugItem: String, CaseIterable {
		case enabled = "Enabled"
		case graphics = "Graphics"
		case color = "Color"
		case position = "Position"
		case collisions = "Collisions"
	}
	
	enum Missile1DebugItem: String, CaseIterable {
		case enabled = "Enabled"
		case graphics = "Graphics"
		case color = "Color"
		case position = "Position"
		case collisions = "Collisions"
	}
	
	enum BallDebugItem: String, CaseIterable {
		case enabled = "Enabled"
		case graphics = "Graphics"
		case color = "Color"
		case position = "Position"
		case verticalDelay = "Vertical delay"
		case collisions = "Collisions"
	}
	
	enum PlayfieldDebugItem: String, CaseIterable {
		case graphics = "Graphics"
		case secondHalf = "Second half"
		case color = "Color"
		case collisions = "Collisions"
	}
	
	enum BackgroundDebugItem: String, CaseIterable {
		case color = "Color"
	}
}


// MARK: -
// MARK: Convenience functionality
struct MCS6507 {
	struct Status: OptionSet, CaseIterable {
		static let carry = Status(rawValue: 1 << 0)
		static let zero = Status(rawValue: 1 << 1)
		static let interruptDisabled = Status(rawValue: 1 << 2)
		static let decimalMode = Status(rawValue: 1 << 3)
		static let `break` = Status(rawValue: 1 << 4)
		static let overflow = Status(rawValue: 1 << 6)
		static let negative = Status(rawValue: 1 << 7)
		
		static var allCases: [Self] {
			return [
				.carry,
				.zero,
				.interruptDisabled,
				.decimalMode,
				.break,
				.overflow,
				.negative
			]
		}
		
		var rawValue: Int32
		init(rawValue: Int32) {
			self.rawValue = rawValue
		}
	}
}



//private extension TIA {
//	enum GraphicsObject: String {
//		case player0 = "Player 0"
//		case missile0 = "Missile 0"
//		case player1 = "Player 1"
//		case missile1 = "Missile 1"
//		case ball = "Ball"
//		case playfield = "Playfield"
//	}
//
//	func collisions(of object: GraphicsObject) -> [GraphicsObject] {
//		var objects: [GraphicsObject] = []
//		switch object {
//		case .player0:
//			if self.read(at: 0x07)[7] {
//				objects.append(.player1)
//			}
//			if self.read(at: 0x00)[6] {
//				objects.append(.missile0)
//			}
//			if self.read(at: 0x01)[6] {
//				objects.append(.missile1)
//			}
//			if self.read(at: 0x02)[6] {
//				objects.append(.ball)
//			}
//			if self.read(at: 0x02)[7] {
//				objects.append(.playfield)
//			}
//		case .player1:
//			if self.read(at: 0x07)[7] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x00)[7] {
//				objects.append(.missile0)
//			}
//			if self.read(at: 0x01)[7] {
//				objects.append(.missile1)
//			}
//			if self.read(at: 0x03)[6] {
//				objects.append(.ball)
//			}
//			if self.read(at: 0x03)[7] {
//				objects.append(.playfield)
//			}
//		case .missile0:
//			if self.read(at: 0x00)[6] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x00)[7] {
//				objects.append(.player1)
//			}
//			if self.read(at: 0x07)[6] {
//				objects.append(.missile1)
//			}
//			if self.read(at: 0x04)[6] {
//				objects.append(.ball)
//			}
//			if self.read(at: 0x04)[7] {
//				objects.append(.playfield)
//			}
//		case .missile1:
//			if self.read(at: 0x01)[6] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x01)[7] {
//				objects.append(.player1)
//			}
//			if self.read(at: 0x07)[6] {
//				objects.append(.missile1)
//			}
//			if self.read(at: 0x05)[6] {
//				objects.append(.ball)
//			}
//			if self.read(at: 0x05)[7] {
//				objects.append(.playfield)
//			}
//		case .ball:
//			if self.read(at: 0x02)[6] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x03)[6] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x04)[6] {
//				objects.append(.missile0)
//			}
//			if self.read(at: 0x05)[6] {
//				objects.append(.missile1)
//			}
//			if self.read(at: 0x06)[7] {
//				objects.append(.playfield)
//			}
//		case .playfield:
//			if self.read(at: 0x02)[7] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x03)[7] {
//				objects.append(.player0)
//			}
//			if self.read(at: 0x04)[7] {
//				objects.append(.missile0)
//			}
//			if self.read(at: 0x05)[7] {
//				objects.append(.missile1)
//			}
//			if self.read(at: 0x06)[7] {
//				objects.append(.ball)
//			}
//		}
//
//		return objects
//	}
//}

private extension Range where Index == Int {
	func split(by count: Int) -> any Sequence<Self> {
		return Swift.stride(from: self.startIndex, to: self.endIndex, by: count)
			.map() { $0..<$0+count }
	}
}

private extension Int {
	subscript(bit: Int) -> Bool {
		get {
			let mask: Int = 0x01 << bit
			return self & mask == mask
		}
		set {
			let mask: Int = 0x01 << bit
			if newValue {
				self |= mask
			} else {
				self &= ~mask
			}
		}
	}
}

//extension TIA.Playfield {
//	var graphics2: [UInt8] {
//		return [
//			UInt8((self.graphics >> 0) & 0xff),
//			UInt8((self.graphics >> 8) & 0xff),
//			UInt8((self.graphics >> 16) & 0xff)
//		]
//	}
//
//}
