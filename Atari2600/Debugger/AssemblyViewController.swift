//
//  AssemblyViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

typealias Program = [(MOS6507.Address, MOS6507.Instruction)]
typealias Breakpoint = MOS6507.Address

class AssemblyViewController: NSViewController {
	@IBOutlet private var noProgramView: NSView!
	@IBOutlet private var programView: NSView!
	@IBOutlet private var tableView: NSTableView!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	var program: Program? {
		didSet {
			self.updateContentView()
		}
	}
	
	var programAddress: MOS6507.Address? {
		didSet {
			self.updateSelectedTableRow()
		}
	}
	
	@Published
	var breakpoints: [Breakpoint] = [] {
		didSet {
			let rows = oldValue.compactMap({ breakpoint in
				self.program?.firstIndex(where: {$0.0 == breakpoint})
			})
			self.tableView.reloadData(in: rows)
		}
	}
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Program Assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.tableView.registerNibs([
			"AssemblyAddressCellView": .addressCell,
			"AssemblyDataCellView": .dataCell
		])
		
		self.updateTableColumnWidths()
		self.setUpSinks()
	}
}


// MARK: -
extension AssemblyViewController {
	@objc func ensureVisible(address: MOS6507.Address) {
		if let row = self.program?.firstIndex(where: { $0.0 == address }),
		   self.tableView.isRowVisible(row) == false {
			self.tableView.scrollToRow(row, offsetRatio: 0.25)
		}
	}
	
	@objc func scrollTo(address: MOS6507.Address) {
		if let row = self.program?.firstIndex(where: { $0.0 == address }) {
			// scroll such that row ends up vertically at 1/4 of view's
			// visible content height
			self.tableView.scrollToRow(row, offsetRatio: 0.25)
		}
	}
}


// MARK: -
// MARK: Event management
extension AssemblyViewController {
	@objc func breakpointToggled(_ sender: BreakpointToggle) {
		if sender.isOn {
			self.breakpoints.append(sender.tag)
		} else {
			if let index = self.breakpoints.firstIndex(of: sender.tag) {
				self.breakpoints.remove(at: index)
			}
		}
	}
}


// MARK: -
// MARK: UI updates
private extension AssemblyViewController {
	func setUpSinks() {
		// TODO: remove delay in showing program after cartridge insert
		self.console.$cartridge
			.delay(for: 0.01, scheduler: RunLoop.current)
			.sink() { [unowned self] in
				if let data = $0 {
					self.program = self.console.cpu.decode(data)
				} else {
					self.program = nil
				}
			}.store(in: &self.cancellables)
		
		self.console.cpu.$programCounter
			.sink() { [unowned self] in
				self.programAddress = $0
				self.ensureVisible(address: $0)
			}.store(in: &self.cancellables)
	}
	
	func updateContentView() {
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
		self.updateSelectedTableRow()
	}
	
	func updateTableColumnWidths() {
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedRegular
		]
		
		["$0000    ", "adc", "($a4),Y"]
			.map() { $0.size(withAttributes: attributes) }
			.enumerated()
			.forEach() { self.tableView.tableColumns[$0.0].width = $0.1.width }
	}
	
	func updateSelectedTableRow() {
		if let row = self.program?
			.firstIndex(where: { $0.0 == self.programAddress }) {
			self.tableView.selectRowIndexes([row], byExtendingSelection: false)
		} else {
			self.tableView.deselectAll(self)
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
			let view = tableView.makeView(withIdentifier: .addressCell, owner: nil) as! AssemblyAddressCellView
			view.toggle.title = String(address: address)
			view.toggle.isOn = self.breakpoints.contains(address)
			
			view.toggle.tag = address
			view.toggle.target = self
			view.toggle.action = #selector(self.breakpointToggled(_:))
			
			return view
			
		case tableView.tableColumns[1]:
			let view = tableView.makeView(withIdentifier: .dataCell, owner: nil) as! AssemblyDataCellView
			view.label.stringValue = String(mnemonic: instruction.mnemonic)
			return view
			
		case tableView.tableColumns[2]:
			let view = tableView.makeView(withIdentifier: .dataCell, owner: nil) as! AssemblyDataCellView
			view.label.stringValue = String(addressingMode: instruction.mode, operand: instruction.operand)
			return view
			
		default:
			return nil
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let addressCell = NSUserInterfaceItemIdentifier("AssemblyAddressCell")
	static let dataCell = NSUserInterfaceItemIdentifier("AssemblyDataCell")
}


// MARK: -
// MARK: Data formatting
extension String {
	init(address: Int) {
		self = .init(format: "$%04x", address)
	}
	
	init(mnemonic: MOS6507.Mnemonic) {
		self = "\(mnemonic)"
	}
	
	init(addressingMode mode: MOS6507.AddressingMode, operand: Int) {
		self = .init(format: mode.formatPattern, operand)
	}
}

private extension MOS6507.AddressingMode {
	var formatPattern: String {
		switch self {
		case .implied:
			return ""
		case .immediate:
			return "#$%02x"
		case .absolute, .relative:
			return "$%04x"
		case .absoluteX:
			return "$%04x,X"
		case .absoluteY:
			return "$%04x,Y"
		case .zeroPage:
			return "$%02x"
		case .zeroPageX:
			return "$%02x,X"
		case .zeroPageY:
			return "$%02x,Y"
		case .indirectX:
			return "($%02x,X)"
		case .indirectY:
			return "($%02x),Y"
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
	func registerNibs(_ nibs: [NSNib.Name: NSUserInterfaceItemIdentifier], bundle: Bundle = .main) {
		for (name, id) in nibs {
			let nib = NSNib(nibNamed: name, bundle: bundle)
			self.register(nib, forIdentifier: id)
		}
	}
	
	func isRowVisible(_ row: Int) -> Bool {
		let scrollView = self.enclosingScrollView!
		let rowRect = self.rect(ofRow: row)
		
		let viewRect = scrollView.visibleRect
		let insets = scrollView.contentInsets
		
		return rowRect.minY >= viewRect.minY + insets.top
		&& rowRect.maxY <= viewRect.maxY - insets.bottom
	}
	
	func scrollToRow(_ row: Int, offsetRatio ratio: CGFloat) {
		let scrollView = self.enclosingScrollView!
		let rowRect = self.rect(ofRow: row)
		
		let viewRect = scrollView.documentVisibleRect
		let insets = scrollView.contentInsets
		let viewHieght = viewRect.height - (insets.top + insets.bottom)
		
		let offset = (viewHieght - rowRect.height) * ratio + insets.top
		let point = NSPoint(x: rowRect.minX, y: rowRect.minY - offset)
		scrollView.scroll(to: point, animationDuration: 0.25)
	}
	
	func reloadData(in rows: [Int]) {
		self.reloadData(
			forRowIndexes: IndexSet(rows),
			columnIndexes: IndexSet(0..<self.tableColumns.count))
	}
}
