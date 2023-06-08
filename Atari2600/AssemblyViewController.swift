//
//  AssemblyViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 5.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class AssemblyViewController: NSViewController {
	@IBOutlet private var tableView: NSTableView!
	
	private var cancellables: Set<AnyCancellable> = []
	private let console: Atari2600 = .current
	
	private var instructions: [(MOS6507.Address, MOS6507.Instruction)]? {
		didSet {
			if self.isViewLoaded {
				self.tableView.reloadData()
			}
		}
	}
	
	private var highlightedRow: Int? = nil {
		didSet {
			if let row = self.highlightedRow,
			   self.isViewLoaded {
				self.tableView.selectRowIndexes([row], byExtendingSelection: false)
				self.tableView.ensureRowVisible(row)
			}
		}
	}
	
	convenience init() {
		self.init(nibName: "AssemblyView", bundle: .main)
		self.title = "Assembly"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.updateTableColumnWidths()
		self.setUpSinks()
	}
}

// MARK: -
// MARK: Event management
private extension AssemblyViewController {
	func setUpSinks() {
		self.console.$isCartridgeInserted
			.sink() { [unowned self] in
				self.instructions = $0
				? self.console.cpu.decodeROM()
				: nil
			}
			.store(in: &self.cancellables)
		
		self.console.cpu
			.$programCounter
			.sink() { [unowned self] address in
				self.highlightedRow = self.instructions?
					.firstIndex(where: { $0.0 == address })
			}
			.store(in: &self.cancellables)
	}
}


// MARK: -
// MARK: Custom functionality
private extension AssemblyViewController {
	static let font: NSFont = .monospacedSystemFont(ofSize: 11.0, weight: .regular)
	
	func updateTableColumnWidths() {
		let sizes = ["$0000", "adc", "($a4),Y"]
			.map() {
				return $0.size(withAttributes: [
					.font: Self.font
				])
			}
		
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
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		return row == self.highlightedRow
	}
	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard let cellView = tableView.makeView(withIdentifier: .cell, owner: nil) as? AssemblyTableCellView,
			  let (address, instruction) = self.instructions?[row] else {
			return nil
		}
		
		switch tableColumn {
		case tableView.tableColumns[0]:
			cellView.label.stringValue = String(format: "$%04x", address)
		case tableView.tableColumns[1]:
			cellView.label.stringValue = "\(instruction.mnemonic)"
		case tableView.tableColumns[2]:
			cellView.label.stringValue = String(format: instruction.mode.formatPattern, instruction.operand)
		default:
			return nil
		}
		
		cellView.label.font = Self.font
		return cellView
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let cell = NSUserInterfaceItemIdentifier("AssemblyTableCellView")
}


// MARK: -
// MARK: Table view cells
class AssemblyTableCellView: NSTableCellView {
	@IBOutlet var label: NSTextField!
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
