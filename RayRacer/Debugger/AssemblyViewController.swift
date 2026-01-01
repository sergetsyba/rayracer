//
//  AssemblyViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import librayracer

class AssemblyViewController: NSViewController, AssemblyViewDataSource {
	@IBOutlet private var noProgramView: NSView!
	@IBOutlet private var programView: NSView!
	@IBOutlet private var tableView: NSTableView!
	
	@Published
	var breakpoints: [Breakpoint] = []
	var program: Program = []
	
	private var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
	}
	
	private var delegate: AssemblyViewDelegate? {
		didSet {
			self.tableView.dataSource = self.delegate
			self.tableView.delegate = self.delegate
		}
	}
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Program Assembly"
	}
	
	deinit {
		NotificationCenter.default
			.removeObserver(self)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.updateView()
		self.setUpNotifications()
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		self.updateTableColumnWidths()
	}
}

typealias Program = [(offset: Int, instruction: Instruction?)]
typealias Breakpoint = Int
let tableColumnDataTemplates = ["$0000   ", "adc ($a4),y  ", "$c2 mem "]


// MARK: -
// MARK: UI updates
private extension AssemblyViewController {
	func updateTableColumnWidths() {
		tableColumnDataTemplates
			.map() { $0.size(withFont: .monospacedRegular) }
			.enumerated()
			.forEach() { self.tableView.tableColumns[$0.0].width = $0.1.width }
	}
	
	func setUpNotifications() {
		let center: NotificationCenter = .default
		center.addObserver(forName: .break, object: nil, queue: .main) { _ in
			self.updateProgramCounterRow()
		}
		center.addObserver(forName: .reset, object: nil, queue: .main) { _ in
			self.updateView()
		}
	}
	
	func updateView() {
		if let cartridge = self.console.cartridge {
			// disassemble program and load its breakpoints
			self.program = self.disassemble(data: cartridge.data)
			self.breakpoints = UserDefaults.standard
				.breakpoints(forProgramIdentifier: cartridge.id)
			
			self.delegate = self.assemblyViewDelegate(for: cartridge)
			self.delegate?.dataSource = self
			
			// switch to program view
			self.view.setContentView(self.programView, layout: .fill)
			self.view.window?
				.makeFirstResponder(self.tableView)
		} else {
			self.delegate = nil
			
			// switch to no program view
			self.view.setContentView(self.noProgramView, layout: .center)
			self.tableView.resignFirstResponder()
		}
		
		self.tableView.reloadData()
		self.updateProgramCounterRow()
	}
	
	private func assemblyViewDelegate(for cartridge: Cartridge) -> AssemblyViewDelegate {
		switch cartridge.kind {
		case .atari2KB:
			return HalfBankAssemblyViewDelegate()
		case .atari4KB:
			return SingleBankAssemblyViewDelegate()
		case .atari8KB,
				.atari12KB,
				.atari16KB,
				.atari32KB:
			return MultiBankAssemblyViewDelegate()
		default:
			fatalError("Unsupported cartridge type: \(cartridge.kind).")
		}
	}
	
	func updateProgramCounterRow() {
		if let row = self.programCounterRow {
			// reload data for the current program address row to update
			// operand address target
			self.tableView.reloadData(in: [row])
			self.tableView.selectRowIndexes([row], byExtendingSelection: false)
			self.tableView.scrollToRow(row, offset: 5)
		} else {
			self.tableView.deselectAll(self)
		}
	}
	
	private var programCounterRow: Int? {
		guard let cartridge = self.console.cartridge,
			  let cpu = self.console.console?.pointee.mpu,
			  let delegate = self.delegate else {
			return nil
		}
		
		let programCounter = Int(cpu.pointee.program_counter)
		let offset = (cartridge.bankIndex * 0x1000) + programCounter % 0x1000
		return delegate.row(forProgramOffset: offset)
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
		
		// update defaults
		let programId = self.console.cartridge!.id
		UserDefaults.standard
			.setBreakpoints(self.breakpoints, forProgramIdentifier: programId)
	}
	
	func clearBreakpoints() {
		let rows = self.breakpoints
			.compactMap({ self.delegate?.row(forProgramOffset: $0) })
		
		self.breakpoints = []
		self.tableView.reloadData(in: rows)
		
		// update defaults
		let programId = self.console.cartridge!.id
		UserDefaults.standard
			.setBreakpoints(self.breakpoints, forProgramIdentifier: programId)
	}
	
	func showBreakpoint(_ breakpoint: Breakpoint) {
		if let row = self.delegate?.row(forProgramOffset: breakpoint) {
			self.tableView.scrollToRow(row, offset: 5)
		}
	}
}


// MARK: -
// MARK: Table view management
private protocol AssemblyViewDelegate: AnyObject, NSTableViewDataSource, NSTableViewDelegate {
	var dataSource: AssemblyViewDataSource? { get set }
	func row(forProgramOffset: Int) -> Int
}
private protocol AssemblyViewDataSource: AnyObject {
	var program: Program { get }
	var breakpoints: [Breakpoint] { get }
}

extension AssemblyViewDelegate {
	func tableView(_ tableView: NSTableView, viewFor entry: (offset: Int, instruction: Instruction?), column: Int) -> NSView? {
		switch column {
		case 0:
			let breakpointSet = self.dataSource?
				.breakpoints.contains(where: { $0 == entry.offset }) ?? false
			
			let view = tableView.makeView(withIdentifier: .assemblyAddressCellView, owner: nil) as! AssemblyAddressCellView
			view.objectValue = entry.offset % 0x1000
			view.toggle.tag = entry.offset
			view.toggle.state = breakpointSet ? .on : .off
			return view
			
		case 1:
			let view = tableView.makeView(withIdentifier: .assemblyInstructionCellView, owner: nil) as! NSTableCellView
			view.objectValue = entry.instruction
			return view
			
		case 2:
			let view = tableView.makeView(withIdentifier: .assemblyTargetCellView, owner: nil) as! NSTableCellView
			view.objectValue = entry.instruction
			return view
			
		default:
			return nil
		}
	}
}

// MARK: -
// MARK: Single bank cartridge
private class SingleBankAssemblyViewDelegate: NSObject, AssemblyViewDelegate {
	weak var dataSource: AssemblyViewDataSource?
	
	func row(forProgramOffset offset: Int) -> Int {
		return self.dataSource?
			.program.firstIndex(where: { $0.0 == offset })
		?? -1
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.dataSource?
			.program.count ?? 0
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let entry = self.dataSource?.program[row],
			  let tableColumn = tableColumn,
			  let column = tableView.tableColumns.firstIndex(of: tableColumn) else {
			return nil
		}
		return self.tableView(tableView, viewFor: entry, column: column)
	}
}

// MARK: -
// MARK: Half-bank cartridge
private class HalfBankAssemblyViewDelegate: NSObject, AssemblyViewDelegate {
	private var groupRow: Int = -1
	weak var dataSource: (any AssemblyViewDataSource)? {
		didSet {
			self.groupRow = self.dataSource?
				.program.count ?? -1
		}
	}
	
	func row(forProgramOffset offset: Int) -> Int {
		guard let program = self.dataSource?.program,
			  let index = program.firstIndex(where: { $0.0 == offset }) else {
			return -1
		}
		return index < self.groupRow ? index : index + 1
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		guard let program = self.dataSource?.program,
			  program.count > 0 else {
			return 0
		}
		return program.count * 2 + 1
	}
	
	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return row == self.groupRow
	}
	
	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		guard self.tableView(tableView, isGroupRow: row) else {
			// do not return row views for regular rows
			return nil
		}
		
		let view = tableView.makeView(withIdentifier: .assemblyGroupRowView, owner: nil) as! AssemblyGroupRowView
		view.stringValue = "Mirror"
		return view
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard self.tableView(tableView, isGroupRow: row) == false else {
			// do not return cell views for group rows
			return nil
		}
		
		// duplicate rows for mirrored section, excluding group row
		var index = row
		if row >= self.groupRow {
			index -= self.groupRow + 1
		}
		
		guard var entry = self.dataSource?.program[index],
			  let tableColumn = tableColumn,
			  let column = tableView.tableColumns.firstIndex(of: tableColumn) else {
			return nil
		}
		
		// adjust instruction offset for mirrored section so that program
		// offsets are continous throughout both sections
		if row >= self.groupRow {
			entry.offset += 0x1000/2
		}
		
		return self.tableView(tableView, viewFor: entry, column: column)
	}
}

// MARK: -
// MARK: Multi-bank cartridge
private class MultiBankAssemblyViewDelegate: NSObject, AssemblyViewDelegate {
	private var groupRows: [Int] = []
	weak var dataSource: AssemblyViewDataSource? {
		didSet {
			guard let program = self.dataSource?.program,
				  let start = program.first?.offset,
				  let end = program.last?.offset else {
				self.groupRows = []
				return
			}
			
			// calculate row numbers of group rows
			self.groupRows = []
			for index in stride(from: start, through: end, by: 0x1000) {
				if let row = program.firstIndex(where: { $0.offset > index }) {
					self.groupRows.append((row - 1) + self.groupRows.count)
				}
			}
		}
	}
	
	func row(forProgramOffset offset: Int) -> Int {
		guard let program = self.dataSource?.program,
			  let index = program.firstIndex(where: { $0.0 == offset }) else {
			return -1
		}
		
		let bankIndex = offset / 0x1000
		return (bankIndex + 1) + index
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		guard let program = self.dataSource?.program,
			  program.count > 0 else {
			return 0
		}
		return self.groupRows.count + program.count
	}
	
	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return self.groupRows.contains(where: { $0 == row })
	}
	
	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		guard self.tableView(tableView, isGroupRow: row),
			  let groupIndex = self.groupRows.firstIndex(of: row) else {
			// do not return row views for regular rows
			return nil
		}
		
		let view = tableView.makeView(withIdentifier: .assemblyGroupRowView, owner: nil) as! AssemblyGroupRowView
		view.stringValue = "Bank \(groupIndex)"
		return view
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard self.tableView(tableView, isGroupRow: row) == false else {
			// do not return cell views for group rows
			return nil
		}
		
		guard let groupIndex = self.groupRows.lastIndex(where: { row > $0 }),
			  let entry = self.dataSource?.program[row - (groupIndex + 1)],
			  let tableColumn = tableColumn,
			  let column = tableView.tableColumns.firstIndex(of: tableColumn) else {
			return nil
		}
		
		return self.tableView(tableView, viewFor: entry, column: column)
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let assemblyGroupRowView = NSUserInterfaceItemIdentifier("AssemblyGroupRowView")
	static let assemblyAddressCellView = NSUserInterfaceItemIdentifier("AssemblyAddressCellView")
	static let assemblyInstructionCellView = NSUserInterfaceItemIdentifier("AssemblyInstructionCellView")
	static let assemblyTargetCellView = NSUserInterfaceItemIdentifier("AssemblyTargetCellView")
}


// MARK: -
// MARK: User defaults integration
private extension String {
	static let breakpoints = "Breakpoints"
}

extension UserDefaults {
	func breakpoints(forProgramIdentifier identifier: String) -> [Breakpoint] {
		let preferences = self.preferences(forGameIdentifier: identifier)
		let breakpoints = preferences[.breakpoints] as? [String] ?? []
		
		return breakpoints
			.compactMap() { Int($0.dropFirst(), radix: 16) }
	}
	
	func setBreakpoints(_ breakpoints: [Breakpoint], forProgramIdentifier identifier: String) {
		var preferences = self.preferences(forGameIdentifier: identifier)
		preferences[.breakpoints] = breakpoints
			.map() { String(format: "$%04x", $0) }
		
		self.setPreferences(preferences, forGameIdentifier: identifier)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension BidirectionalCollection where Index: Strideable {
	func lastIndex(where predicate: (Element) -> Bool) -> Index? {
		for index in self.indices.reversed() {
			if predicate(self[index]) {
				return index
			}
		}
		return nil
	}
}

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
	private func isRowVisible(_ row: Int) -> Bool {
		let scrollView = self.enclosingScrollView!
		let rowRect = self.rect(ofRow: row)
		
		let viewRect = scrollView.documentVisibleRect
		let insets = scrollView.contentInsets
		
		return rowRect.minY >= viewRect.minY + insets.top
		&& rowRect.maxY <= viewRect.maxY - insets.bottom
	}
	
	func scrollToRow(_ row: Int, offset: Int) {
		// scroll such that the target row ends up offset by the specified
		// number of rows from the table view's top to provide some context
		// to the row data
		let row = min(row - offset, row)
		
		// FIXME: seems to scroll to incorrect row when there are group rows
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
