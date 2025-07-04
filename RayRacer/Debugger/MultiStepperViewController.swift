//
//  MultiStepperViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 5.10.2024.
//

import Cocoa

class MultiStepperViewController: NSTitlebarAccessoryViewController {
	@IBOutlet var popUpButton: NSPopUpButton!
	@IBOutlet var textField: NSTextField!
	
	private let defaults: UserDefaults = .standard
	var handler: ((Step, Int) -> Void)? = nil
	
	convenience init() {
		self.init(nibName: "MultiStepperView", bundle: .main)
		self.identifier = NSUserInterfaceItemIdentifier("MultiStepperViewController")
	}
}

extension MultiStepperViewController {
	enum Step: Int {
		case instructions
		case scanLines
		case fields
	}
}


// MARK: -
// MARK: View lifecycle
extension MultiStepperViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.popUpButton.selectItem(at: self.defaults.debugStep.rawValue)
		self.textField.integerValue = self.defaults.debugStepCount
		self.textField.cell?.focusRingType = .none
	}
	
	override func viewDidAppear() {
		super.viewDidAppear()
		_ = self.becomeFirstResponder()
	}
}


// MARK: -
// MARK: Target actions
extension MultiStepperViewController {
	@IBAction func didPressStepButton(_ sender: NSButton) {
		if let handler = self.handler,
		   let step = Step(rawValue: self.popUpButton.indexOfSelectedItem) {
			let count = self.textField.integerValue
			handler(step, count)
			
			self.defaults.debugStep = step
			self.defaults.debugStepCount = count
		}
	}
	
	@IBAction func didPressDoneButton(_ sender: NSButton) {
		if let window = self.view.window,
		   let index = window.titlebarAccessoryViewControllers.firstIndex(of: self) {
			window.removeTitlebarAccessoryViewController(at: index)
		}
	}
}


// MARK: -
// MARK: Data formatting
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


// MARK: -
// MARK: Preferences
extension UserDefaults {
	var debugStep: MultiStepperViewController.Step {
		get {
			guard let value = self.value(forKey: .debugStep) as? Int,
				  let step = MultiStepperViewController.Step(rawValue: value) else {
				return .instructions
			}
			return step
		}
		set {
			self.set(newValue.rawValue, forKey: .debugStep)
		}
	}
	
	var debugStepCount: Int {
		get { self.value(forKey: .debugStepCount) as? Int ?? 1 }
		set { self.set(newValue, forKey: .debugStepCount) }
	}
}

extension String {
	static let debugStep = "DebugStep"
	static let debugStepCount = "DebugStepCount"
}
