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
	
	@Published
	var breakpoints: [Breakpoint] = []
	
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
			self.updateProgramAddressTableRow()
		}
		center.addObserver(forName: .reset, object: nil, queue: .main) { _ in
			self.updateView()
		}
	}
	
	func updateView() {
		if let cartridge = self.console.cartridge {
			let delegate: AssemblyViewDelegate
			switch cartridge.kind {
			case .atari2KB, .atari4KB:
				delegate = SingleBankAssemblyViewDelegate()
			case .atari8KB:
				delegate = MultiBankAssemblyViewDelegate()
			default:
				fatalError("Unsupported cartridge type: \(cartridge.kind).")
			}
			
			delegate.program = self.disassemble(data: cartridge.data)
			delegate.breakpoints = self
			
			self.delegate = delegate
			self.breakpoints = UserDefaults.standard
				.breakpoints(forProgramIdentifier: cartridge.id)
			
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
		self.updateProgramAddressTableRow()
	}
	
	func updateProgramAddressTableRow() {
		let bank = 0 // TODO:
		let address = Int(self.console
			.console.pointee
			.mpu.pointee
			.program_counter)
		
		//		if let row = self.delegate?.row(forProgramOffset: (bank, address)) {
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
extension AssemblyViewController: BreakpointDataSource {
	func isSet(at offset: Int) -> Bool {
		return self.breakpoints.contains(offset)
	}
	
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
protocol BreakpointDataSource {
	func isSet(at offset: Int) -> Bool
}
protocol AssemblyViewDelegate: AnyObject, NSTableViewDataSource, NSTableViewDelegate {
	var program: Program! { get set }
	var breakpoints: BreakpointDataSource? { get set }
	func row(forProgramOffset: Int) -> Int
}

// MARK: -
class SingleBankAssemblyViewDelegate: NSObject, AssemblyViewDelegate {
	var program: Program!
	var breakpoints: BreakpointDataSource?
	
	func row(forProgramOffset offset: Int) -> Int {
		return self.program
			.firstIndex(where: { $0.0 == offset })!
	}
	
	// MARK: TableView management
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.program.count
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let tableColumn = tableColumn,
			  let column = tableView.tableColumns.firstIndex(of: tableColumn) else {
			return nil
		}
		
		let (offset, instruction) = self.program[row]
		switch column {
		case 0:
			let view = tableView.makeView(withIdentifier: .assemblyAddressCellView, owner: nil) as! AssemblyAddressCellView
			view.objectValue = offset % 0x1000
			
			view.toggle.tag = offset
			view.toggle.state = self.breakpoints?
				.isSet(at: offset) == false ? .off : .on
			
			return view
			
		case 1:
			let view = tableView.makeView(withIdentifier: .assemblyInstructionCellView, owner: nil) as! NSTableCellView
			view.objectValue = instruction
			return view
			
		case 2:
			let view = tableView.makeView(withIdentifier: .assemblyTargetCellView, owner: nil) as! NSTableCellView
			view.objectValue = instruction
			return view
			
		default:
			return nil
		}
	}
}


// MARK: -
class MultiBankAssemblyViewDelegate: SingleBankAssemblyViewDelegate {
	private var groupRows: [Int] = []
	
	override var program: Program! {
		didSet {
			let start = program.first!.offset
			let end = program.last!.offset
			
			self.groupRows = []
			for index in stride(from: start, through: end, by: 0x1000) {
				if let row = program.firstIndex(where: { $0.offset > index }) {
					self.groupRows.append((row - 1) + self.groupRows.count)
				}
			}
		}
	}
	
	override func row(forProgramOffset offset: Int) -> Int {
		let bankIndex = offset / 0x1000
		let row = self.program
			.firstIndex(where: { $0.0 == offset })
		
		return (bankIndex + 1) + row!
	}
	
	// MARK: TableView management
	override func numberOfRows(in tableView: NSTableView) -> Int {
		return self.groupRows.count + self.program.count
	}
	
	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		return self.groupRows.contains(where: { $0 == row })
	}
	
	func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
		guard let bankIndex = self.groupRows.firstIndex(of: row) else {
			// do not return row views for regular rows
			return nil
		}
		
		let view = tableView.makeView(withIdentifier: .assemblyGroupRowView, owner: nil) as! AssemblyGroupRowView
		view.objectValue = bankIndex
		return view
	}
	
	override func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let isGroupRow = self.tableView(tableView, isGroupRow: row)
		guard !isGroupRow else {
			// do not return cell views for group rows
			return nil
		}
		
		let offset = self.groupRows.firstIndex(where: { row < $0 })
		?? self.groupRows.count
		
		return super.tableView(tableView, viewFor: tableColumn, row: row - offset)
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
