//
//  MultiStepperViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 5.10.2024.
//

import Cocoa

class MultiStepperViewController: NSTitlebarAccessoryViewController {
	@IBOutlet private var kindPopUpButton: NSPopUpButton!
	@IBOutlet private var textField: NSTextField!
	
	var handler: ((Action) -> Void)? = nil
	
	var kind: Kind = .instructions {
		didSet {
			if self.isViewLoaded {
				self.updateView()
			}
		}
	}
	
	convenience init() {
		self.init(nibName: "MultiStepperView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.textField.cell?
			.focusRingType = .none
	}
	
	private func updateView() {
		self.kindPopUpButton.selectItem(at: self.kind.rawValue)
	}
}


// MARK: -
// MARK: Target actions
extension MultiStepperViewController {
	@IBAction func didPressStepButton(_ sender: NSButton) {
		let kind = Kind(rawValue: self.kindPopUpButton.indexOfSelectedItem)
		let count = self.textField.integerValue
		self.handler?(.step(kind!, count))
	}
	
	@IBAction func didPressDoneButton(_ sender: NSButton) {
		self.handler?(.done)
	}
}

extension MultiStepperViewController {
	enum Kind: Int {
		case instructions = 0
		case scanLines = 1
		case fields = 2
	}
	
	enum Action {
		case step(Kind, Int)
		case done
	}
}


// MARK: -
class PositiveIntegerFormatter: Formatter {
	override func string(for obj: Any?) -> String? {
		guard let number = obj as? Int else {
			return nil
		}
		
		return "\(number)"
	}
	
	override func getObjectValue(_ obj: AutoreleasingUnsafeMutablePointer<AnyObject?>?, for string: String, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
		guard let number = Int(string) else {
			return false
		}
		
		obj?.pointee = NSNumber(value: number)
		return true
	}
	
	override func isPartialStringValid(_ partialStringPtr: AutoreleasingUnsafeMutablePointer<NSString>, proposedSelectedRange proposedSelRangePtr: NSRangePointer?, originalString origString: String, originalSelectedRange origSelRange: NSRange, errorDescription error: AutoreleasingUnsafeMutablePointer<NSString?>?) -> Bool {
		return String(partialStringPtr.pointee)
			.contains(where: { !$0.isNumber }) == false
	}
}
