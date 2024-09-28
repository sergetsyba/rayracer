//
//  StepperViewController.swift
//  RayRacer
//
//  Created by Serge Tsyba on 24.9.2024.
//

import Cocoa

class StepperViewController: NSViewController {
	// TODO: make label update its intrinsic content size to avoid extra space when switching steppers
	@IBOutlet private var label: NSTextField!
	@IBOutlet private var textField: NSTextField!
	@IBOutlet private var stepper: NSStepper!
	
	var handler: ((NSApplication.ModalResponse, Int) -> Void)?
	var prompt: String? {
		didSet {
			if self.isViewLoaded {
				self.label.stringValue = self.prompt ?? ""
			}
		}
	}
	
	convenience init() {
		self.init(nibName: "StepperView", bundle: .main)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		if let prompt = self.prompt {
			self.label.stringValue = prompt
		}
	}
}

extension StepperViewController {
	@IBAction func didPressCancelButton(sender: NSButton!) {
		self.handler?(.cancel, self.textField.integerValue)
	}
	
	@IBAction func didPressStepButton(sender: NSButton!) {
		self.handler?(.OK, self.textField.integerValue)
	}
}
