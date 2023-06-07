//
//  AssemblyViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Atari2600Kit

class AssemblyViewController: NSViewController {
	@IBOutlet private var tableView: NSTableView!
	
	private var instructions: [(MOS6507.Address, MOS6507.Instruction)]?
	var console: Atari2600? {
		didSet {
			self.instructions = self.console?
				.cpu
				.decodeROM()
			
			if self.isViewLoaded {
				self.tableView.reloadData()
			}
		}
	}
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedSystemFont(ofSize: 11.0, weight: .regular)
		]
		
		let sizes = ["$0000", "adc", "($a4),Y"]
			.map() { $0.size(withAttributes: attributes) }
		
		self.tableView.tableColumns[0].width = sizes[0].width * 1.5
		self.tableView.tableColumns[1].width = sizes[1].width
		self.tableView.tableColumns[2].width = sizes[2].width
	}
}


// MARK: -
// MARK: Table view management
extension AssemblyViewController: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
		return self.instructions?.count ?? 0
	}
}

extension AssemblyViewController: NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, cellIdentifierFor tableColumn: NSTableColumn?) -> NSUserInterfaceItemIdentifier? {
		switch tableColumn {
		case tableView.tableColumns[0]:
			return .addressCell
		case tableView.tableColumns[1]:
			return .mnemonicCell
		case tableView.tableColumns[2]:
			return .operandCell
		default:
			return nil
		}
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let identifier = self.tableView(tableView, cellIdentifierFor: tableColumn),
			  let cellView = tableView.makeView(withIdentifier: identifier, owner: nil) as? AssemblyTableCellView else {
			return nil
		}
		
		cellView.label.font = .monospacedSystemFont(ofSize: 11.0, weight: .regular)
		return cellView
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		let (address, instruction) = self.instructions![row]
		
		switch tableColumn {
		case tableView.tableColumns[0]:
			return address
		case tableView.tableColumns[1]:
			return instruction.mnemonic
		case tableView.tableColumns[2]:
			return (instruction.mode, instruction.operand)
		default:
			return nil
		}
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let addressCell = NSUserInterfaceItemIdentifier("AssemblyViewAddressCell")
	static let mnemonicCell = NSUserInterfaceItemIdentifier("AssemblyViewMnemonicCell")
	static let operandCell = NSUserInterfaceItemIdentifier("AssemblyViewOperandCell")
}


// MARK: -
// MARK: Table view cells
class AssemblyTableCellView: NSTableCellView {
	@IBOutlet var label: NSTextField!
}

class AssemblyAddressTableCellView: AssemblyTableCellView {
	override var objectValue: Any? {
		didSet {
			if let address = self.objectValue as? Int {
				self.label.stringValue = String(format: "$%04x", address)
			}
		}
	}
}

class AssemblyMnemonicTableCellView: AssemblyTableCellView {
	override var objectValue: Any? {
		didSet {
			if let mnemonic = self.objectValue as? MOS6507.Mnemonic {
				self.label.stringValue = String(describing: mnemonic)
			}
		}
	}
}

class AssemblyOperandTableCellView: AssemblyTableCellView {
	override var objectValue: Any? {
		didSet {
			if let (mode, operand) = self.objectValue as? (MOS6507.AddressingMode, Int) {
				self.label.stringValue = String(format: mode.formatPattern, operand)
			}
		}
	}
}


// MARK: -
// MARK: Data formatting
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
