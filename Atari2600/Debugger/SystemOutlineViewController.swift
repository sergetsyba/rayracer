//
//  SystemViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 29.5.2024.
//

import Cocoa

class SystemViewController: NSViewController {
	@IBOutlet private var outlineView: NSOutlineView!
	
	convenience init() {
		self.init(nibName: "SystemView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.outlineView.reloadData()
	}
}

extension SystemViewController: NSOutlineViewDataSource {
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

extension SystemViewController: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		let view = outlineView.makeView(withIdentifier: .systemViewCell, owner: self) as? NSTableCellView
		view?.textField?.stringValue = item as? String ?? ""
		return view
	}
}

private extension NSUserInterfaceItemIdentifier {
	static let systemViewCell = NSUserInterfaceItemIdentifier("SystemViewCell")
}
