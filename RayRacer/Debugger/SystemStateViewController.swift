//
//  SystemStateViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 29.5.2024.
//

import Cocoa
import Combine
import RayRacerKit

class SystemStateViewController: NSViewController {
	@IBOutlet private var outlineView: NSOutlineView!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: "SystemStateView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.setUpSyncs()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		self.outlineView.expandItem(nil, expandChildren: true)
		self.outlineView.reloadData()
	}
}


// MARK: -
private extension SystemStateViewController {
	func setUpSyncs() {
		self.cancellables.insert(self.console.events
			.receive(on: DispatchQueue.main)
			.sink() {
				switch $0 {
				case .reset:
					self.outlineView.reloadData()
				default:
					break
				}
			})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() {
					switch $0 {
					case .break:
						self.outlineView.reloadData()
					default:
						break
					}
				})
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
		} else if let item = item as? ScreenDebugItem {
			return self.makeView(outlineView, forScreenDebugItem: item)
		} else if let item = item as? Player0DebugItem {
			return self.makeView(outlineView, forPlayer0DebugItem: item)
		} else if let item = item as? Player1DebugItem {
			return self.makeView(outlineView, forPlayer1DebugItem: item)
		} else if let item = item as? Missile1DebugItem {
			return self.makeView(outlineView, forMissile1DebugItem: item)
		} else if let item = item as? Missile0DebugItem {
			return self.makeView(outlineView, forMissile0DebugItem: item)
		} else if let item = item as? BallDebugItem {
			return self.makeView(outlineView, forBallDebugItem: item)
		} else if let item = item as? PlayfieldDebugItem {
			return self.makeView(outlineView, forPlayfieldDebugItem: item)
		} else if let item = item as? BackgroundDebugItem {
			return self.makeView(outlineView, forBackgroundDebugItem: item)
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
		let cpu = self.console.cpu!
		
		switch item {
		case .accumulator:
			view?.wordValue = (item.rawValue, cpu.accumulator)
		case .indexX:
			view?.wordValue = (item.rawValue, cpu.x)
		case .indexY:
			view?.wordValue = (item.rawValue, cpu.y)
		case .status:
			view?.attributedStringValue = (item.rawValue, self.formattedCPUStatus)
		case .stackPointer:
			view?.wordValue = (item.rawValue, cpu.stackPointer)
		case .programCounter:
			view?.addressValue = (item.rawValue, cpu.programCounter)
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forMemoryDebugItem item: MemoryDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as? DebugValueTableCellView
		let riot = self.console.riot!
		
		view?.textField?.stringValue = String(memory: riot.memory)
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forTimerDebugItem item: TimerDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		let riot = self.console.riot!
		
		switch item {
		case .value:
			view?.stringValue = (item.rawValue, "\(riot.timerClock)")
		case .interval:
			view?.stringValue = (item.rawValue, "\(riot.timerInterval)")
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forScreenDebugItem item: ScreenDebugItem) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
		let tia = self.console.tia!
		
		switch item {
		case .beamPosition:
			let scanLine = self.console.frameClock / self.console.width
			let colorClock = self.console.frameClock % self.console.width
			view?.stringValue = (item.rawValue, "\(scanLine), \(colorClock - 68)")
		case .verticalSync:
			view?.stringValue = (item.rawValue, self.formattedVerticalSync)
		case .verticalBlank:
			view?.boolValue = (item.rawValue, tia.verticalBlank)
		case .waitForHorizontalSync:
			view?.boolValue = (item.rawValue, tia.waitingHorizontalSync)
		}
		
		return view
	}
	
	private func makeView(_ outlineView: NSOutlineView, forPlayer0DebugItem item: Player0DebugItem) -> NSView? {
		switch item {
		case .graphics:
			let formatted = self.formatPlayerGraphics(self.console.tia.player0Graphics, reflected: self.console.tia.player0Reflected, delayed: self.console.tia.player0Delay)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.attributedStringValue = (item.rawValue, formatted)
			return view
			
		case .reflect:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.player0Reflected)
			return view
			
		case .copies:
			let formatted = self.formatPlayerCopies(self.console.tia.player0Copies)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.player0Color)
			return view
			
		case .position:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.positionValue = (item.rawValue, self.console.tia.player0Position, self.console.tia.player0Motion)
			return view
			
		case .delay:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.player0Delay)
			return view
			
		case .collisions:
			let formatted = self.formatCollisions(of: .player0)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forMissile0DebugItem item: Missile0DebugItem) -> NSView? {
		switch item {
		case .enabled:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.missile0Enabled)
			return view
			
		case .graphics:
			let formatted = self.formatGraphics(width: self.console.tia.missile0Size)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.player0Color)
			return view
			
		case .position:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.positionValue = (item.rawValue, self.console.tia.missile0Position, self.console.tia.missile0Motion)
			return view
			
		case .collisions:
			let formatted = self.formatCollisions(of: .missile0)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forPlayer1DebugItem item: Player1DebugItem) -> NSView? {
		switch item {
		case .graphics:
			let formatted = self.formatPlayerGraphics(self.console.tia.player1Graphics, reflected: self.console.tia.player1Reflected, delayed: self.console.tia.player1Delay)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.attributedStringValue = (item.rawValue, formatted)
			return view
			
		case .reflect:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.player1Reflected)
			return view
			
		case .copies:
			let formatted = self.formatPlayerCopies(self.console.tia.player1Copies)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.player1Color)
			return view
			
		case .position:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.positionValue = (item.rawValue, self.console.tia.player1Position, self.console.tia.player1Motion)
			return view
			
		case .delay:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.player1Delay)
			return view
			
		case .collisions:
			let formatted = self.formatCollisions(of: .player1)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forMissile1DebugItem item: Missile1DebugItem) -> NSView? {
		switch item {
		case .enabled:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.missile1Enabled)
			return view
			
		case .graphics:
			let formatted = self.formatGraphics(width: self.console.tia.missile1Size)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.player1Color)
			return view
			
		case .position:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.positionValue = (item.rawValue, self.console.tia.missile1Position, self.console.tia.missile1Motion)
			return view
			
		case .collisions:
			let formatted = self.formatCollisions(of: .missile1)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forBallDebugItem item: BallDebugItem) -> NSView? {
		switch item {
		case .enabled:
			let formatted = self.formatBallEnabled(self.console.tia.ballEnabled, delayed: self.console.tia.ballDelay)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.attributedStringValue = (item.rawValue, formatted)
			return view
			
		case .graphics:
			let formatted = self.formatGraphics(width: self.console.tia.ballSize)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.playfieldColor)
			return view
			
		case .position:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.positionValue = (item.rawValue, self.console.tia.ballPosition, self.console.tia.ballMotion)
			return view
			
		case .verticalDelay:
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.boolValue = (item.rawValue, self.console.tia.ballDelay)
			return view
			
		case .collisions:
			let formatted = self.formatCollisions(of: .ball)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forPlayfieldDebugItem item: PlayfieldDebugItem) -> NSView? {
		switch item {
		case .graphics:
			let formatted = self.formatPlayfieldGraphics(self.console.tia.playfield)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .secondHalf:
			let formatted = self.console.tia.playfieldReflected ? "Reflect" : "Duplicate"
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
			
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, self.console.tia.playfieldColor)
			return view
			
		case .collisions:
			let formatted = self.formatCollisions(of: .playfield)
			let view = outlineView.makeView(withIdentifier: .debugItemTableCellView, owner: nil) as? DebugItemTableCellView
			view?.stringValue = (item.rawValue, formatted)
			return view
		}
	}
	
	private func makeView(_ outlineView: NSOutlineView, forBackgroundDebugItem item: BackgroundDebugItem) -> NSView? {
		let backgroundColor = self.console.tia.backgroundColor
		
		switch item {
		case .color:
			let view = outlineView.makeView(withIdentifier: .debugColorTableCellView, owner: nil) as? DebugColorTableCellView
			view?.colorValue = (item.rawValue, backgroundColor)
			return view
		}
	}
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
	private var formattedCPUStatus: NSAttributedString {
		let string = NSMutableAttributedString(string: "N V   B D I Z C")
		let status = self.console.cpu.status
		
		for (index, value) in status.enumerated() {
			if !value {
				let range = NSRange(location: index * 2, length: 1)
				string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
			}
		}
		
		return string
	}
	
	private var formattedVerticalSync: String {
		let (sync, clocks) = self.console.tia.verticalSync
		if sync {
			return "Yes, \(clocks)/\(3*228)"
		} else {
			return "No"
		}
	}
	
	private func formatPlayfieldGraphics(_ graphics: Int) -> String {
		let playfield = self.console.tia.playfield
		let pfs = [
			(playfield & 0x0000f) << 4,
			Int(reversingBits: (playfield & 0x00ff0) >> 4),
			(playfield & 0xff000) >> 12
		]
		
		let values = pfs
			.map({ String(format: "%02x", $0) })
			.joined(separator: " ")
		
		let pattern = (0..<20)
			.map({ playfield[$0] ? "■": "□" })
			.joined()
		
		return "\(values) \(pattern.suffix(20))"
	}
	
	private func formatPlayerGraphics(_ graphics: (Int, Int), reflected: Bool, delayed: Bool) -> NSAttributedString {
		let formatted = (
			self.formatPlayerGraphics(graphics.0, reflected: reflected),
			self.formatPlayerGraphics(graphics.1, reflected: reflected))
		
		let string = NSMutableAttributedString(string: formatted.0 + "  " + formatted.1)
		let range = delayed
		? NSRange(location: 0, length: formatted.0.count)
		: NSRange(location: formatted.0.count + 2, length: formatted.1.count)
		
		string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
		return string
	}
	
	private func formatPlayerGraphics(_ graphics: Int, reflected: Bool) -> String {
		let value = String(format: "%02x", graphics)
		var pattern = stride(from: 7, through: 0, by: -1)
			.map({ graphics[$0] ? "■": "□" })
			.joined()
		
		if reflected {
			pattern = String(pattern.reversed())
		}
		
		return "\(value) \(pattern)"
	}
	
	private func formatGraphics(width: Int) -> String {
		return (0..<width)
			.map({ _ in "■" })
			.joined()
	}
	
	private func formatPlayerCopies(_ copies: Int) -> String {
		switch copies {
		case 0: return "1, single size"
		case 1: return "2, close"
		case 2: return "2, medium"
		case 3: return "3, close"
		case 4: return "2, wide"
		case 5: return "1, double size"
		case 6: return "3, medium"
		case 7: return "1, quadruple size"
		default: fatalError()
		}
	}
	
	private func formatBallEnabled(_ enabled: (Bool, Bool), delayed: Bool) -> NSAttributedString {
		let formatted = (
			enabled.0 ? "Yes" : "No",
			enabled.1 ? "Yes" : "No")
		
		let string = NSMutableAttributedString(string: "\(formatted.0)  \(formatted.1)")
		let range = delayed
		? NSRange(location: 0, length: formatted.0.count)
		: NSRange(location: formatted.0.count + 2, length: formatted.1.count)
		
		string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
		return string
	}
	
	private func formatCollisions(of object: TIA.GraphicsObject) -> String {
		if let objects = self.console.tia.collistions[object] {
			return objects.map({ "\($0)" })
				.joined(separator: ", ")
		} else {
			return "None"
		}
	}
}

extension TIA.GraphicsObject: CustomStringConvertible {
	public var description: String {
		switch self {
		case .player0: return "Player 0"
		case .player1: return "Player 1"
		case .missile0: return "Missile 0"
		case .missile1: return "Missile 1"
		case .ball: return "Ball"
		case .playfield: return "Playfield"
		}
	}
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
	
	enum Missile0DebugItem: String, CaseIterable {
		case enabled = "Enabled"
		case graphics = "Graphics"
		case color = "Color"
		case position = "Position"
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
