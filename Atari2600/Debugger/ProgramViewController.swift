//
//  ProgramViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Atari2600Kit

typealias Program = [(MOS6507.Address, MOS6507.Instruction)]

class ProgramViewController: NSViewController {
	@IBOutlet private var noProgramView: NSView!
	@IBOutlet private var programView: NSView!
	@IBOutlet private var tableView: NSTableView!
	
	var program: Program? {
		didSet {
			self.updateContentView()
		}
	}
	
	var programAddress: MOS6507.Address? {
		didSet {
			self.tableView.selectedRowIndex = self.program?
				.firstIndex(where: { $0.0 == self.programAddress })
		}
	}
	
	@Published private(set)
	var breakpoints: [MOS6507.Address] = []
	
	convenience init() {
		self.init(nibName: "ProgramView", bundle: .main)
		self.title = "Program Assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.tableView.registerNibs([
			"AssemblyAddressCellView": .addressCell,
			"AssemblyDataCellView": .dataCell
		])
		
		let columnData = ["$0000    ", "adc", "($a4),Y"]
		self.tableView.columnWidths = columnData.map() {
			return $0.size(withAttributes: [
				.font: NSFont.monospacedRegular
			]).width
		}
	}
}


// MARK: -
// MARK: Event management
extension ProgramViewController {
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
private extension ProgramViewController {
	func updateContentView() {
		if let _ = self.program {
			self.tableView.reloadData()
			
			self.view.setContentView(self.programView, layout: .fill)
			self.view.window?
				.makeFirstResponder(self.tableView)
		} else {
			self.tableView.resignFirstResponder()
			self.view.setContentView(self.noProgramView, layout: .center)
		}
	}
}


// MARK: -
// MARK: Table view management
extension ProgramViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.program?.count ?? 0
	}
}

extension ProgramViewController: NSTableViewDelegate {
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
private extension String {
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
	func isVisible(rect: CGRect) -> Bool {
		let viewRect = self.documentVisibleRect
		let insets = self.contentInsets
		
		return rect.minY >= viewRect.minY + insets.top
		&& rect.maxY <= viewRect.maxY - insets.bottom
	}
	
	func scroll(to point: NSPoint, animationDuration duration: CGFloat) {
		NSAnimationContext.beginGrouping()
		NSAnimationContext.current.duration = duration
		
		self.contentView.animator()
			.setBoundsOrigin(point)
		
		NSAnimationContext.endGrouping()
	}
}

private extension NSTableView {
	var columnWidths: [CGFloat] {
		get {
			return self.tableColumns
				.map() { $0.width }
		}
		set {
			self.tableColumns
				.enumerated()
				.forEach() { $0.1.width = newValue[$0.0] }
		}
	}
	
	var selectedRowIndex: Int? {
		get {
			let row = self.selectedRow
			return row < 0 ? nil : row
		}
		set {
			if let index = newValue {
				self.selectRowIndexes([index], byExtendingSelection: false)
			} else {
				let row = self.selectedRow
				self.deselectRow(row)
			}
		}
	}
	
	func registerNibs(_ nibs: [NSNib.Name: NSUserInterfaceItemIdentifier], bundle: Bundle = .main) {
		for (name, id) in nibs {
			let nib = NSNib(nibNamed: name, bundle: bundle)
			self.register(nib, forIdentifier: id)
		}
	}
	
	func ensureRowVisible(_ row: Int) {
		let scrollView = self.enclosingScrollView!
		let rowRect = self.rect(ofRow: row)
		if scrollView.isVisible(rect: rowRect) {
			return
		}
		
		let viewRect = scrollView.documentVisibleRect
		let insets = scrollView.contentInsets
		let viewHieght = viewRect.height - (insets.top + insets.bottom)
		
		// scroll such that row ends up vertically at 1/3 of view's
		// visible content height
		let offset = (viewHieght - rowRect.height) / 3 + insets.top
		let point = NSPoint(x: rowRect.minX, y: rowRect.minY - offset)
		scrollView.scroll(to: point, animationDuration: 0.25)
	}
}
