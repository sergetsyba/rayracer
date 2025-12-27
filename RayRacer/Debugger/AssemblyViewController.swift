//
//  AssemblyViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import librayracer

class AssemblyViewController: NSViewController {
	@IBOutlet private var noProgramView: NSView!
	@IBOutlet private var programView: NSView!
	@IBOutlet private var tableView: NSTableView!
	
	private var delegate: (NSTableViewDataSource & NSTableViewDelegate)? {
		didSet {
			self.tableView.dataSource = self.delegate
			self.tableView.delegate = self.delegate
		}
	}
	
	private var breakpointTableRows: [Int] = []
	
	private var console: Atari2600 {
		let delegate = NSApplication.shared.delegate as! RayRacerDelegate
		return delegate.console
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

typealias ProgramEntry = (offset: Int, instruction: Instruction?)
typealias Breakpoint = (bank: Int, offset: Int)
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
			self.updateProgramAddressTableRow()
		}
		center.addObserver(forName: .reset, object: nil, queue: .main) { _ in
			self.updateView()
		}
	}
	
	func updateView() {
		if let data = self.console.cartridge,
		   let cartridgeType = CartridgeType(data: data),
		   let gameId = self.console.programId {
			
			// disassemble program
			let program = self.disassemble(data: data)
			switch cartridgeType {
			case .atari4KB:
				let delegate = SingleBankAssemblyViewDelegate()
				delegate.program = program.first
				self.delegate = delegate
				
			case .atari8KB:
				let delegate = MultiBankAssemblyViewDelegate()
				delegate.program = program
				self.delegate = delegate
				
			default:
				fatalError()
			}
			
			// load breakpoints and convert to table row indexes
			//			self.breakpointTableRows = UserDefaults.standard
			//				.breakpoints(forGameIdentifier: gameId)
			//				.compactMap(self.tableRow(forProgramEntryAt:))
			
			// switch to program view
			self.view.setContentView(self.programView, layout: .fill)
			self.view.window?
				.makeFirstResponder(self.tableView)
		} else {
			self.delegate = nil
			self.breakpointTableRows = []
			
			// switch to no program view
			self.view.setContentView(self.noProgramView, layout: .center)
			self.tableView.resignFirstResponder()
		}
		
		self.tableView.reloadData()
		self.updateProgramAddressTableRow()
	}
	
	func updateProgramAddressTableRow() {
		let bank = 0 // TODO:
		let address = Int(self.console
			.console.pointee
			.mpu.pointee
			.program_counter)
		
		//		if let row = self.tableRow(forProgramEntryAt: (bank, address)) {
		//			self.tableView.selectRowIndexes([row], byExtendingSelection: false)
		//			self.tableView.ensureRowVisible(row)
		//
		//			// reload data for the current program address row to update
		//			// operand address target
		//			self.tableView.reloadData(in: [row])
		//		} else {
		//			self.tableView.deselectAll(self)
		//		}
	}
}


// MARK: -
// MARK: Breakpoint management
extension AssemblyViewController {
	@IBAction func breakpointToggled(_ sender: BreakpointToggle) {
		if sender.state == .on {
			self.breakpointTableRows.append(sender.tag)
		} else {
			self.breakpointTableRows.remove(at: sender.tag)
		}
		
		// update user defaults
		//		let breakpoints = self.breakpointTableRows
		//			.map(self.programEntryAddress(forTableRow:))
		//		UserDefaults.standard
		//			.setBreakpoints(breakpoints, forGameIdentifier: self.console.programId!)
	}
	
	func clearBreakpoints() {
		let rows = self.breakpointTableRows
		self.breakpointTableRows = []
		self.tableView.reloadData(in: rows)
		
		// update user defaults
		//		let breakpoints = self.breakpointTableRows
		//			.map(self.programEntryAddress(forTableRow:))
		//		UserDefaults.standard
		//			.setBreakpoints(breakpoints, forGameIdentifier: self.console.programId!)
	}
	
	func showBreakpoint(_ breakpoint: Breakpoint) {
		//		if let row = self.tableRow(forProgramEntryAt: breakpoint) {
		//			self.tableView.scrollToRow(row)
		//		}
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
			.compactMap() {
				let values = $0.split(separator: "/")
				let bankIndex = Int(values[0])
				let address = Int(values[1].dropFirst(), radix: 16)
				
				return (bankIndex!, address!)
			}
	}
	
	func setBreakpoints(_ breakpoints: [Breakpoint], forGameIdentifier identifier: String) {
		var preferences = self.preferences(forGameIdentifier: identifier)
		preferences[.breakpoints] = breakpoints
			.map() { String(format: "%d/$%04x", $0.0, $0.1) }
		
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

protocol BreakpointDelegate: AnyObject {
	func breakpointToggled(_ sender: BreakpointToggle)
}


// MARK: -
// MARK: Table view management
private extension NSUserInterfaceItemIdentifier {
	static let assemblyGroupRowView = NSUserInterfaceItemIdentifier("AssemblyGroupRowView")
	static let assemblyAddressCellView = NSUserInterfaceItemIdentifier("AssemblyAddressCellView")
	static let assemblyInstructionCellView = NSUserInterfaceItemIdentifier("AssemblyInstructionCellView")
	static let assemblyTargetCellView = NSUserInterfaceItemIdentifier("AssemblyTargetCellView")
}

class AssemblyViewDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, viewFor entry: ProgramEntry, tableColumn: NSTableColumn?) -> NSView? {
		guard let tableColumn = tableColumn,
			  let column = tableView.tableColumns.firstIndex(of: tableColumn) else {
			return nil
		}
		
		let view: NSTableCellView!
		switch column {
		case 0:
			let view = tableView.makeView(withIdentifier: .assemblyAddressCellView, owner: nil) as! AssemblyAddressCellView
			view.objectValue = entry.offset
			
			//			view.toggle.state = self.breakpointTableRows.contains(row) ? .on : .off
			//			view.toggle.tag = row
			//			view.toggle.target = self
			//			view.toggle.action = #selector(self.breakpointToggled(_:))
			return view
			
		case 1:
			view = tableView.makeView(withIdentifier: .assemblyInstructionCellView, owner: nil) as? NSTableCellView
			view.objectValue = entry.instruction
			
		case 2:
			view = tableView.makeView(withIdentifier: .assemblyTargetCellView, owner: nil) as? NSTableCellView
			view.objectValue = entry.instruction
			
		default:
			return nil
		}
		
		return view
	}
}

class SingleBankAssemblyViewDelegate: AssemblyViewDelegate {
	var program: [ProgramEntry]!
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.program?.count ?? 0
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let entry = self.program[row]
		return self.tableView(tableView, viewFor: entry, tableColumn: tableColumn)
	}
}

class MultiBankAssemblyViewDelegate: AssemblyViewDelegate {
	var program: [[ProgramEntry]]! {
		didSet {
			self.rowCounts = [0]
			var count = 0
			
			for entries in self.program {
				count += entries.count + 1
				self.rowCounts.append(count)
			}
		}
	}
	
	private var rowCounts: [Int] = []
	
	private func programRow(forTableRow row: Int) -> (bank: Int, Int) {
		let bank = self.rowCounts
			.firstIndex(where: { row < $0 })! - 1
		
		let row = (row - 1) - self.rowCounts[bank]
		return (bank, row)
	}
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.rowCounts.last!
	}
	
	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return self.rowCounts.contains(where: { $0 == row })
	}
	
	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		guard let bank = self.rowCounts.firstIndex(of: row),
			  let view = tableView.makeView(withIdentifier: .assemblyGroupRowView, owner: nil) as? AssemblyGroupRowView else {
			return nil
		}
		
		view.textField.stringValue = "Bank \(bank)"
		return view
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let (bank, row) = self.programRow(forTableRow: row)
		guard row > -1 else {
			// do not return any cells for group rows
			return nil
		}
		
		// convert absolute program offset to relative to current bank
		var entry = self.program[bank][row]
		entry.offset -= bank * 0x1000
		
		return self.tableView(tableView, viewFor: entry, tableColumn: tableColumn)
	}
}
