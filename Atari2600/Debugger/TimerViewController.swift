//
//  TimerViewController.swift
//  Atari2600
//
//  Created by Serge Tsyba on 6.7.2023.
//

import Cocoa
import Combine
import Atari2600Kit

class TimerViewController: NSViewController {
	private var intervalsLabel = IntervalsLabel()
	private var cyclesLabel = CyclesLabel()
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: nil, bundle: nil)
		self.title = "Timer"
	}
}


// MARK: -
// MARK: View lifecycle
extension TimerViewController {
	override func loadView() {
		self.view = FormView([
			("Intervals:", self.intervalsLabel),
			("Cycles:", self.cyclesLabel)
		])
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension TimerViewController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.cpu.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] _ in
					self.updateCyclesLabel()
					self.updateIntervalsLabel()
				})
	}
	
	func updateCyclesLabel() {
		self.cyclesLabel.isEnabled = self.console.riot.isTimerOn
		self.cyclesLabel.value = (self.console.riot.remainingTimerCycles, self.console.riot.intervalIncrement)
	}
	
	func updateIntervalsLabel() {
		self.intervalsLabel.isEnabled = self.console.riot.isTimerOn
		self.intervalsLabel.value = self.console.riot.remainingTimerIntervals
	}
}


// MARK: -
// MARK: Convenience functionality
private extension MOS6532 {
	var remainingTimerIntervals: Int {
		return self.read(at: 0x0c)
	}
}


// MARK: -
// MARK: Custom controls
private class IntervalsLabel: DebuggerValueLabel {
	var value: Int! {
		didSet {
			let hexFormatted = String(format: "%x", self.value)
			var string1 = AttributedString("\(self.value!)")
			var string2 = AttributedString(hexFormatted)
			
			if self.value != oldValue,
			   self.isEnabled {
				string1.font = .monospacedBold
				string2.font = .monospacedBold
			}
			
			let string = string1 + " (" + string2 + ")"
			self.attributedStringValue = NSAttributedString(string)
		}
	}
}

private class CyclesLabel: DebuggerValueLabel {
	var value: (Int, Int)! {
		didSet {
			let (cycles, increment) = self.value
			var string1 = AttributedString("\(cycles)")
			var string2 = AttributedString("\(increment)")
			
			if cycles != oldValue?.0,
			   self.isEnabled {
				string1.font = .monospacedBold
			}
			if increment != oldValue?.1,
			   self.isEnabled {
				string2.font = .monospacedBold
			}
			
			let string = string1 + " /" + string2
			self.attributedStringValue = NSAttributedString(string)
		}
	}
}
