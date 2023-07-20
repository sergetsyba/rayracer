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
	@IBOutlet private var intervalsLabel: DebuggerValueLabel!
	@IBOutlet private var cyclesLabel: DebuggerValueLabel!
	
	private let console: Atari2600 = .current
	private var cancellables: Set<AnyCancellable> = []
	
	convenience init() {
		self.init(nibName: "TimerView", bundle: .main)
		self.title = "Timer"
	}
}


// MARK: -
// MARK: View lifecycle
extension TimerViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		self.resetView(self.console.riot)
		self.setUpSinks()
	}
}


// MARK: -
// MARK: UI updates
private extension TimerViewController {
	func setUpSinks() {
		self.cancellables.insert(
			self.console.events
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .reset:
						self.resetView(self.console.riot)
					}
				})
		
		self.cancellables.insert(
			self.console.debugEvents
				.receive(on: DispatchQueue.main)
				.sink() { [unowned self] in
					switch $0 {
					case .break, .step:
						self.updateView(self.console.riot)
					default:
						break
					}
				})
	}
	
	func resetView(_ riot: MOS6532) {
		self.intervalsLabel.reset(intervals: riot.remainingTimerIntervals)
		self.cyclesLabel.reset(
			cycles: riot.remainingTimerCycles,
			increment: riot.intervalIncrement)
	}
	
	func updateView(_ riot: MOS6532) {
		guard riot.isTimerOn else {
			self.resetView(riot)
			return
		}
		
		self.intervalsLabel.update(intervals: riot.remainingTimerIntervals)
		self.cyclesLabel.update(
			cycles: riot.remainingTimerCycles,
			increment: riot.intervalIncrement)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension DebuggerValueLabel {
	func reset(intervals: Int) {
		let newValue = String(format: "%d (%+02x)", intervals, intervals)
		self.reset(newValue)
	}
	
	func reset(cycles: Int, increment: Int) {
		let newValue = String(format: "%d /%d", cycles, increment)
		self.reset(newValue)
	}
	
	func update(intervals: Int) {
		let newValue = String(format: "%d (%+02x)", intervals, intervals)
		self.update(newValue)
	}
	
	func update(cycles: Int, increment: Int) {
		let newValue = String(format: "%d /%d", cycles, increment)
		self.update(newValue)
	}
}

private extension MOS6532 {
	var remainingTimerIntervals: Int {
		return self.read(at: 0x0c)
	}
}
