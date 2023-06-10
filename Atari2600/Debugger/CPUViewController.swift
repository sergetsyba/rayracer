//
//  CPUViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 9.6.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class CPUViewController: NSViewController {
	@IBOutlet private var accumulatorLabel: NSTextField!
	@IBOutlet private var indexXLabel: NSTextField!
	@IBOutlet private var indexYLabel: NSTextField!
	@IBOutlet private var statusLabel: NSTextField!
	
	@IBOutlet private var stackPointerLabel: NSTextField!
	@IBOutlet private var programCounterLabel: NSTextField!
	
	private let cpu: MOS6507 = Atari2600.current.cpu
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: "CPUView", bundle: .main)
		self.title = "MOS6507"
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.updateSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension CPUViewController {
	func updateSinks() {
		self.cpu.$accumulator
			.sink() { [unowned self] in self.accumulatorLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$x
			.sink() { [unowned self] in self.indexXLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$y
			.sink() { [unowned self] in self.indexYLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$status
			.sink() { [unowned self] in self.statusLabel.statusValue = $0 }
			.store(in: &self.cancellables)
		
		self.cpu.$stackPointer
			.sink() { [unowned self] in self.stackPointerLabel.wordValue = $0 }
			.store(in: &self.cancellables)
		self.cpu.$programCounter
			.sink() { [unowned self] in self.programCounterLabel.addressValue = $0 }
			.store(in: &self.cancellables)
	}
}


// MARK: -
// MARK: Data formatting
private extension NSTextField {
	var wordValue: Int {
		get { fatalError("NSTextField.wordValue") }
		set {
			self.stringValue = String(format: "%02x", newValue)
		}
	}
	
	var addressValue: Int {
		get { fatalError("NSTextField.wordValue") }
		set {
			self.stringValue = String(format: "$%04x", newValue)
		}
	}
	
	var statusValue: MOS6507.Status {
		get { fatalError("NSTextField.wordValue") }
		set {
			self.stringValue = "N V   B D I Z C"
		}
	}
}
