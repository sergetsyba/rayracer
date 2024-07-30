//
//  AssemblyViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Combine
import RayRacerKit

typealias Program = [(Int, MOS6507Assembly.Instruction)]
typealias Breakpoint = Int

class AssemblyViewController: NSViewController {
	@IBOutlet private var noProgramView: NSView!
	@IBOutlet private var programView: NSView!
	@IBOutlet private var tableView: NSTableView!
	
	private let console: Atari2600 = .current
	private var program: Program?
	private let defaults: UserDefaults = .standard
	private var cancellables: Set<AnyCancellable> = []
	
	@Published
	private(set) var breakpoints: [Int] = [] {
		didSet {
			if let identifier = self.console.gameIdentifier {
				self.defaults.setBreakpoints(self.breakpoints, forGameIdentifier: identifier)
			}
		}
	}
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Program Assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.updateTableColumnWidths()
		self.updateView()
		self.setUpSinks()
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		self.updateTableColumnWidths()
	}
}


// MARK: -
private extension AssemblyViewController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.delay(for: 0.1, scheduler: RunLoop.main)
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .reset:
						self.updateView()
					default: break
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() {
					switch $0 {
					case .break:
						self.updateProgramAddressTableRow()
					default:
						break
					}
				})
	}
}


// MARK: -
// MARK: UI updates
private extension AssemblyViewController {
	static let tableColumnDataTemplates = ["$0000   ", "adc ($a4),y  ", "$c2 mem "]
	
	func updateTableColumnWidths() {
		Self.tableColumnDataTemplates
			.map() { $0.size(withFont: .monospacedRegular) }
			.enumerated()
			.forEach() { self.tableView.tableColumns[$0.0].width = $0.1.width }
	}
	
	func updateView() {
		if let data = self.console.cartridge {
			self.program = MOS6507Assembly.disassemble(data)
			self.breakpoints = self.defaults.breakpoints(
				forGameIdentifier: self.console.gameIdentifier!)
			
			// switch to program view
			self.view.setContentView(self.programView, layout: .fill)
			self.view.window?
				.makeFirstResponder(self.tableView)
		} else {
			self.program = nil
			self.breakpoints = []
			
			// switch to no program view
			self.view.setContentView(self.noProgramView, layout: .center)
			self.tableView.resignFirstResponder()
		}
		
		self.tableView.reloadData()
		self.updateProgramAddressTableRow()
	}
	
	func updateProgramAddressTableRow() {
		if let row = self.program?
			.firstIndex(where: { $0.0 == self.console.cpu.programCounter }) {
			
			self.tableView.selectRowIndexes([row], byExtendingSelection: false)
			self.tableView.ensureRowVisible(row)
			
			// reload data for the current program address row to update
			// operand address target
			self.tableView.reloadData(in: [row])
		} else {
			self.tableView.deselectAll(self)
		}
	}
}


// MARK: -
// MARK: Breakpoint management
extension AssemblyViewController {
	@IBAction func breakpointToggled(_ sender: BreakpointToggle) {
		if sender.state == .on {
			self.breakpoints.append(sender.tag)
		} else {
			self.breakpoints.removeAll(where: { $0 == sender.tag })
		}
	}
	
	func clearBreakpoints() {
		let rows = self.breakpoints.compactMap() { breakpoint in
			self.program?
			.firstIndex(where: { $0.0 == breakpoint} )}
		
		self.breakpoints = []
		self.tableView.reloadData(in: rows)
	}
	
	func showBreakpoint(_ breakpoint: Int) {
		if let row = self.program?.firstIndex(where: { $0.0 == breakpoint }) {
			self.tableView.scrollToRow(row)
		}
	}
}


// MARK: -
// MARK: Table view management
extension AssemblyViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.program?.count ?? 0
	}
}

extension AssemblyViewController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		// disable row selection from user interactions
		return row == tableView.selectedRow
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let (address, instruction) = self.program?[row] else {
			return nil
		}
		
		switch tableColumn {
		case tableView.tableColumns[0]:
			let view = tableView.makeView(withIdentifier: .assemblyAddressCellView, owner: nil) as! AssemblyAddressCellView
			view.toggle.stringValue = String(format: "$%04x", address)
			view.toggle.state = self.breakpoints.contains(address) ? .on : .off
			
			view.toggle.tag = address
			view.toggle.target = self
			view.toggle.action = #selector(self.breakpointToggled(_:))
			
			return view
			
		case tableView.tableColumns[1]:
			let view = tableView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as! DebugValueTableCellView
			view.textField?.stringValue = instruction.description
			return view
			
		case tableView.tableColumns[2]:
			let view = tableView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as! DebugValueTableCellView
			view.textField?.stringValue = self.formatTarget(of: instruction, at: row) ?? ""
			return view
			
		default:
			return nil
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let assemblyAddressCellView = NSUserInterfaceItemIdentifier("AssemblyAddressCellView")
	static let debugValueTableCellView = NSUserInterfaceItemIdentifier("DebugValueTableCellView")
}


// MARK: -
// MARK: Data formatting
private extension AssemblyViewController {
	func formatTarget(of instruction: MOS6507Assembly.Instruction, at row: Int) -> String? {
		switch instruction.addressing {
		case .implied:
			// instructions with implied addressing do not have operands
			return nil
			
		case .zeroPage, .absolute:
			// for instructions with absolute addressing, always return
			// formatted operand address target
			let address = self.console.unmirror(instruction.operand)
			return self.formatTarget(at: address)
			
		default:
			// for instructions with indexed addressing, return formatted
			// operand address target only when program is currently at
			// that instruction
			if self.program?[row].0 == self.console.cpu.programCounter,
			   let address = self.console.cpu.nextOperandAddress {
				let address = self.console.unmirror(address)
				return self.formatTarget(at: address)
			} else {
				return nil
			}
		}
	}
	
	private func formatTarget(at address: Int) -> String? {
		if (0x0000..<0x0040).contains(address) {
			return MOS6507Assembly.tiaLabels[address]
		} else if (0x080..<0x0100).contains(address) {
			return String(format: "ram $%02x", address)
		} else if (0x0280..<0x0300).contains(address) {
			return MOS6507Assembly.riotLabels[address - 0x0280]
		} else if (0xf000...0xffff).contains(address) {
			return String(format: "rom $%03x", address)
		} else {
			return nil
		}
	}
}


// MARK: -
// MARK: User defaults integration
private extension String {
	static let breakpoints = "Breakpoints"
}

extension UserDefaults {
	func breakpoints(forGameIdentifier identifier: String) -> [Breakpoint] {
		let preferences = self.preferences(forGameIdentifier: identifier)
		let breakpoints = preferences[.breakpoints] as? [String] ?? []
		
		return breakpoints
			.map() { $0.dropFirst() }
			.compactMap() { Int($0, radix: 16) }
	}
	
	func setBreakpoints(_ breakpoints: [Breakpoint], forGameIdentifier identifier: String) {
		var preferences = self.preferences(forGameIdentifier: identifier)
		preferences[.breakpoints] = breakpoints
			.map() { String(format: "$%04x", $0) }
		
		self.setPreferences(preferences, forGameIdentifier: identifier)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSScrollView {
	func scroll(to point: NSPoint, animationDuration duration: CGFloat) {
		NSAnimationContext.beginGrouping()
		NSAnimationContext.current.duration = duration
		
		self.contentView.animator()
			.setBoundsOrigin(point)
		
		NSAnimationContext.endGrouping()
	}
}

private extension NSTableView {
	func ensureRowVisible(_ row: Int) {
		if self.isRowVisible(row) == false {
			self.scrollToRow(row)
		}
	}
	
	private func isRowVisible(_ row: Int) -> Bool {
		let scrollView = self.enclosingScrollView!
		let rowRect = self.rect(ofRow: row)
		
		let viewRect = scrollView.documentVisibleRect
		let insets = scrollView.contentInsets
		
		return rowRect.minY >= viewRect.minY + insets.top
		&& rowRect.maxY <= viewRect.maxY - insets.bottom
	}
	
	func scrollToRow(_ row: Int) {
		// scroll such that the target row ends up offset by 5 rows from
		// the table view's top to provide some context to the row data
		let row = min(row - 5, row)
		
		if let scrollView = self.enclosingScrollView {
			let rowRect = self.rect(ofRow: row)
			let point = NSPoint(x: rowRect.minX, y: rowRect.minY + scrollView.contentInsets.top)
			scrollView.scroll(to: point, animationDuration: 0.25)
		}
	}
	
	func reloadData(in rows: [Int]) {
		self.reloadData(
			forRowIndexes: IndexSet(rows),
			columnIndexes: IndexSet(0..<self.tableColumns.count))
	}
}
