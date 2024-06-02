//
//  SystemViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 29.5.2024.
//

import Cocoa

class SystemOutlineViewController: NSViewController {
	@IBOutlet private var outlineView: NSOutlineView!
	
	convenience init() {
		self.init(nibName: "SystemOutlineView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.outlineView.reloadData()
	}
}

extension SystemOutlineViewController: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if item == nil {
			return 1
		} else {
			return 6
		}
	}
	
	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if item == nil {
			return "CPU"
		} else {
			return 0
		}
	}
}

extension SystemOutlineViewController: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .debuggerCellView, owner: self) as? DebuggerCellView2
		view?.textField?.stringValue = "CPU"
		return view
	}
}

class DebuggerCellView2: NSTableCellView {
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?.font = .monospacedRegular
	}
}
