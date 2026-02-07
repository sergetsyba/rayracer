//
//  DebugItemTableCellView.swift
//  RayRacer
//
//  Created by Serge Tsyba on 23.6.2024.
//

import Cocoa
import SwiftUI

class DebugItemTableCellView: NSTableCellView {
	override var objectValue: Any? {
		didSet {
			switch self.objectValue {
			case let (label, value) as (String, NSAttributedString):
				self.textField?
					.attributedStringValue = (label + " = ") + self.format(valueString: value)
			case let value as NSAttributedString:
				self.textField?
					.attributedStringValue = self.format(valueString: value)
			default:
				self.textField?
					.stringValue = ""
			}
		}
	}
	
	func format(valueString string: NSAttributedString) -> NSAttributedString {
		let size = self.textField?.font?.pointSize ?? 11.0
		var font: NSFont = .monospacedSystemFont(ofSize: size, weight: .regular)
		
		// set monospaced font on the whole string
		let string = NSMutableAttributedString(attributedString: string)
		let range = NSRange(location: 0, length: string.length)
		string.addAttribute(.font, value: font, range: range)
		
		// set bold font style on value changes and disabled control text
		// color on disabled values in string
		font = .monospacedSystemFont(ofSize: size, weight: .bold)
		string.enumerateAttributes(in: range) { attributes, range, _ in
			if let _ = attributes[.change] {
				string.addAttribute(.font, value: font, range: range)
			}
			if let _ = attributes[.marker]
				?? attributes[.disabled] {
				string.addAttribute(.foregroundColor, value: NSColor.disabledControlTextColor, range: range)
			}
		}
		
		return string
	}
	
	//	var stringValue: (String, String)? {
	//		didSet {
	//			guard let (label, value) = self.stringValue else {
	//				self.attributedStringValue = nil
	//				return
	//			}
	//
	//			// make value text monospaced
	//			var string = AttributedString("\(value)")
	//			string.font = self.font.monospaced()
	//
	//			// make value text bold when it differs from previous value
	//			if let oldValue, self.stringValue?.1 != oldValue.1 {
	//				string.font = string.font?.bold()
	//			}
	//
	//			// merge label and value strings
	//			self.attributedStringValue = (label, string)
	//		}
	//	}
	
	private var font: Font {
		let font = self.textField?.font ??
			.systemFont(ofSize: NSFont.systemFontSize)
		
		return Font(font)
	}
	
	var boolValue: (String, Bool) {
		get { fatalError() }
		set {
			//			let string = newValue.1 ? "Yes" : "No"
			//			self.stringValue = (newValue.0, string)
		}
	}
	
	var wordValue: (String, Int32) {
		get { fatalError() }
		set {
			//			let string = String(format: "%02x", newValue.1)
			//			self.stringValue = (newValue.0, string)
		}
	}
	
	var addressValue: (String, Int32) {
		get { fatalError() }
		set {
			//			let string = String(format: "$%04x", newValue.1)
			//			self.stringValue = (newValue.0, string)
		}
	}
	
	var positionValue: (String, Int, Int32) {
		get { fatalError() }
		set {
			//			let string = String(format: "%d, %+d", newValue.1, newValue.2)
			//			self.stringValue = (newValue.0, string)
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.textField?.font = .systemRegular
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Font {
	static let monospacedSmall: Self = .system(size: NSFont.smallSystemFontSize)
		.monospaced()
}

private func + (lhs: String, rhs: NSAttributedString) -> NSAttributedString {
	let string = NSMutableAttributedString(string: lhs)
	string.append(rhs)
	
	return string
}
