//
//  AssemblyViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

typealias Program = [(Address, MOS6507Assembly.Instruction)]
typealias Breakpoint = Address

class AssemblyViewController: NSViewController {
	@IBOutlet private var noProgramView: NSView!
	@IBOutlet private var programView: NSView!
	@IBOutlet private var tableView: NSTableView!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	private(set) var program: Program? {
		didSet {
			if let _ = self.program {
				self.breakpoints = UserDefaults.standard
					.breakpoints()
			} else {
				self.programAddress = nil
				self.breakpoints = []
			}
			if self.isViewLoaded {
				self.updateProgramView()
				self.updateProgramAddressRow()
			}
		}
	}
	
	private(set) var programAddress: Address? {
		didSet {
			if self.isViewLoaded {
				self.updateProgramAddressRow()
			}
		}
	}
	
	@Published
	private(set) var breakpoints: [Breakpoint] = []
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Program Assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.updateTableColumnWidths()
		self.updateProgramView()
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
						if let data = self.console.cartridge {
							self.program = MOS6507Assembly.disassemble(data)
							self.programAddress = self.console.cpu.programCounter
						} else {
							self.program = nil
							self.programAddress = nil
						}
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() {
					switch $0 {
					case .break, .step:
						self.programAddress = self.console.cpu.programCounter
					default:
						self.programAddress = nil
					}
				})
	}
}


// MARK: -
// MARK: UI updates
private extension AssemblyViewController {
	static let tableColumnDataTemplates = ["$0000   ", "adc ", "($a4),y "]
	
	func updateTableColumnWidths() {
		Self.tableColumnDataTemplates
			.map() { $0.size(withFont: .monospacedRegular) }
			.enumerated()
			.forEach() { self.tableView.tableColumns[$0.0].width = $0.1.width }
	}
	
	func updateProgramView() {
		if let _ = self.program {
			// switch to program view
			self.view.setContentView(self.programView, layout: .fill)
			self.view.window?
				.makeFirstResponder(self.tableView)
		} else {
			// switch to no program view
			self.view.setContentView(self.noProgramView, layout: .center)
			self.tableView.resignFirstResponder()
		}
		
		self.tableView.reloadData()
	}
	
	func updateProgramAddressRow() {
		if let program = self.program,
		   let row = program.firstIndex(where: { $0.0 == self.programAddress }) {
			self.tableView.selectRowIndexes([row], byExtendingSelection: false)
			self.tableView.ensureRowVisible(row)
		} else {
			self.tableView.deselectAll(self)
		}
	}
}


// MARK: -
// MARK: Breakpoint management
extension AssemblyViewController {
	@objc func breakpointToggled(_ sender: BreakpointToggle) {
		if sender.state == .on {
			self.breakpoints.append(sender.tag)
		} else {
			if let index = self.breakpoints.firstIndex(of: sender.tag) {
				self.breakpoints.remove(at: index)
			}
		}
		
		// update user defaults
		UserDefaults.standard
			.setBreakpoints(self.breakpoints)
	}
	
	func clearBreakpoints() {
		let rows = self.breakpoints
			.compactMap() { breakpoint in self.program?
				.firstIndex(where: { $0.0 == breakpoint} )}
		
		self.breakpoints = []
		self.tableView.reloadData(in: rows)
		
		// update user defaults
		UserDefaults.standard
			.setBreakpoints(self.breakpoints)
	}
	
	func showBreakpoint(_ breakpoint: Address) {
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
			view.textField?.stringValue = "\(instruction.mnemonic)"
			return view
			
		case tableView.tableColumns[2]:
			let view = tableView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as! DebugValueTableCellView
			view.textField?.stringValue = self.formatOperand(of: instruction)
			return view
			
		case tableView.tableColumns[3]:
			let view = tableView.makeView(withIdentifier: .debugValueTableCellView, owner: nil) as! DebugValueTableCellView
			view.textField?.stringValue = self.formatTarget(of: instruction) ?? ""
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
	func formatOperand(of instruction: MOS6507Assembly.Instruction) -> String {
		return String(format: instruction.operandFormat, instruction.operand)
	}
	
	func formatTarget(of instruction: MOS6507Assembly.Instruction) -> String? {
		switch instruction.mode {
		case .zeroPage, .absolute:
			let address = self.console.unmirrorAddress(instruction.operand)
			if let target = self.formatTarget(at: address) {
				return "→ \(target)"
			} else {
				return nil
			}
			
		default:
			return nil
		}
	}
	
	private func formatTarget(at address: Int) -> String? {
		if (0x0000..<0x0040).contains(address) {
			return Self.tiaLabels[address]
		} else if (0x080..<0x0100).contains(address) {
			return String(format: "$%02x mem", address - 0x0080)
		} else if (0x0280..<0x0300).contains(address) {
			return Self.riotLabels[address - 0x0280]
		} else {
			return nil
		}
	}
	
	private static let tiaLabels = [
		0x00: "vsync",
		0x01: "vblank",
		0x02: "wsync",
		0x03: "rsync",
		0x04: "nusiz0",
		0x05: "nusiz1",
		0x06: "colup0",
		0x07: "colup1",
		0x08: "colupf",
		0x09: "colubk",
		0x0a: "ctrlpf",
		0x0b: "refp0",
		0x0c: "refp1",
		0x0d: "pf0",
		0x0e: "pf1",
		0x0f: "pf2",
		0x10: "resp0",
		0x11: "resp1",
		0x12: "resm0",
		0x13: "resm1",
		0x14: "resbl",
		0x15: "audc0",
		0x16: "audc1",
		0x17: "audf0",
		0x18: "audf1",
		0x19: "audv0",
		0x1a: "audv1",
		0x1b: "grp0",
		0x1c: "grp1",
		0x1d: "enam0",
		0x1e: "enam1",
		0x1f: "enabl",
		0x20: "hmp0",
		0x21: "hmp1",
		0x22: "hmm0",
		0x23: "hmm1",
		0x24: "hmbl",
		0x25: "vdelp0",
		0x26: "vdelp1",
		0x27: "vdelbl",
		0x28: "resmp0",
		0x29: "resmp1",
		0x2a: "hmove",
		0x2b: "hmclr",
		0x2c: "cxclr",
		0x30: "cxm0p",
		0x31: "cxm1p",
		0x32: "cxp0fb",
		0x33: "cxp1fb",
		0x34: "cxm0fb",
		0x35: "cxm1fb",
		0x36: "cxblpf",
		0x37: "cxppmm",
		0x38: "inpt0",
		0x39: "inpt1",
		0x3a: "inpt2",
		0x3b: "inpt3",
		0x3c: "inpt4",
		0x3d: "inpt5"
	]
	
	static let riotLabels = [
		0x00: "swcha",
		0x01: "swacnt",
		0x02: "swchb",
		0x03: "swbcnt",
		0x04: "intim",
		0x06: "intim"
	]
}

private extension MOS6507Assembly.Instruction {
	var operandFormat: String {
		switch self.mode {
		case .implied:
			return ""
		case .immediate:
			return "#$%02x"
		case .zeroPage:
			return "$%02x"
		case .zeroPageX:
			return "$%02x,x"
		case .zeroPageY:
			return "$%02x,y"
		case .absolute:
			return "$%04x"
		case .absoluteX:
			return "$%04x,x"
		case .absoluteY:
			return "$%04x,y"
		case .indirectX:
			return "($%02x,x)"
		case .indirectY:
			return "($%02x),y"
		case .relative:
			return "$%04x"
		}
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
	
	func isRowVisible(_ row: Int) -> Bool {
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

private extension Bus {
	func unmirrorAddress(_ address: Int) -> Int {
		// TODO: unmirror
		return address
	}
}
