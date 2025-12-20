//
//  DebugItemTableCellView.swift
//  RayRacer
//
//  Created by Serge Tsyba on 23.6.2024.
//

import Cocoa

class DebugItemTableCellView: NSTableCellView {
	private static let valueAttributes: [NSAttributedString.Key: Any] = [
		.font: NSFont.monospacedRegular
	]
	
	var attributedStringValue: (any CustomStringConvertible, NSAttributedString) {
		get { fatalError() }
		set {
			let string = NSMutableAttributedString(attributedString: newValue.1)
			string.addAttributes(Self.valueAttributes)
			self.textField?.attributedStringValue = "\(newValue.0) = " + string
		}
	}
	
	var stringValue: (String, String) {
		get { fatalError() }
		set {
			let string = NSMutableAttributedString(string: newValue.1)
			string.addAttributes(Self.valueAttributes)
			self.textField?.attributedStringValue = "\(newValue.0) = " + string
		}
	}
	
	var boolValue: (String, Bool) {
		get { fatalError() }
		set {
			let string = newValue.1 ? "Yes" : "No"
			self.stringValue = (newValue.0, string)
		}
	}
	
	var wordValue: (String, Int32) {
		get { fatalError() }
		set {
			let string = String(format: "%02x", newValue.1)
			self.stringValue = (newValue.0, string)
		}
	}
	
	var addressValue: (String, Int32) {
		get { fatalError() }
		set {
			let string = String(format: "$%04x", newValue.1)
			self.stringValue = (newValue.0, string)
		}
	}
	
	var positionValue: (String, Int, Int32) {
		get { fatalError() }
		set {
			let string = String(format: "%d, %+d", newValue.1, newValue.2)
			self.stringValue = (newValue.0, string)
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?.font = .systemRegular
	}
}


// MARK: -
// MARK: Convenience functionality
private extension NSMutableAttributedString {
	func addAttributes(_ attributes: [NSAttributedString.Key: Any]) {
		let range = NSRange(location: 0, length: self.string.count)
		self.addAttributes(attributes, range: range)
	}
}

private func + (lhs: String, rhs: NSAttributedString) -> NSAttributedString {
	let string = NSMutableAttributedString(string: lhs)
	string.append(rhs)
	
	return string
}
