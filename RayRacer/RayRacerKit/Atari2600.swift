//
//  RayRacer+Atari2600.swift
//  RayRacer
//
//  Created by Serge Tsyba on 15.12.2025.
//

import Foundation
import CryptoKit
import librayracer

class Atari2600 {
	let ref: UnsafeMutablePointer<racer_atari2600>!
	var program: Data?

	private var suspension: (() -> Bool, () -> Void, SuspensionPriority)?
	private var state: State = .suspended(.normal)

	init() {
		self.ref = racer_atari2600_create()!
		self.switches = UserDefaults.standard.consoleSwitches
	}

	var switches: Switches {
		didSet {
			self.ref.pointee
				.switches.1 = UInt8(self.switches.rawValue)
			UserDefaults.standard
				.consoleSwitches = self.switches
		}
	}

	var cartridge: Cartridge? {
		didSet {
			// remove old cartridge when present
			if let _ = oldValue {
				racer_atari2600_remove_cartridge(self.ref)
				self.program = nil
			}
			// insert new cartridge when specified
			guard let cartridge else {
				return
			}
			// load program
			do {
				let (program, kind) = try cartridge.load()
				self.program = program
				self.program?.withUnsafeMutableBytes() {
					racer_atari2600_insert_cartridge(self.ref, kind, $0.baseAddress)
				}
			} catch {
				fatalError(error.localizedDescription)
			}
		}
	}

	var controllers: (Joystick?, Joystick?) {
		didSet {
		}
	}

	func holdSwitch(_ `switch`: Switches, for interval: Int = 500) {
		// set switch to `on`
		self.switches[`switch`] = true

		// set switch to `off` after the interval
		let deadline: DispatchTime = .now()
			.advanced(by: .milliseconds(interval))

		DispatchQueue.main
			.asyncAfter(deadline: deadline) { [unowned self] in
				self.switches[`switch`] = false
			}
	}

	func reset() {
		racer_atari2600_reset(self.ref)

		NotificationCenter.default
			.post(name: .reset, object: self)
	}
}

extension Notification.Name {
	static let reset = NSNotification.Name("ConsoleDidReset")
}

// MARK: -
// MARK: Convenience functionality
extension OptionSet {
	subscript(_ index: Self.Element) -> Bool {
		get {
			return self.contains(index)
		}
		set {
			if newValue {
				self.insert(index)
			} else {
				self.remove(index)
			}
		}
	}
}


// MARK: -
// MARK: [Legacy] Suspend/resume functionality
extension Atari2600 {
	enum SuspensionPriority: Comparable {
		case normal
		case high
	}

	private enum State {
		case resumed
		case suspended(SuspensionPriority)
	}

	/// Returns `true` when emulation is suspended with the specified priority; returns `false`
	/// otherwise.
	func isSuspended(withPriority priority: SuspensionPriority = .normal) -> Bool {
		if case .suspended(let currentPriority) = self.state {
			return priority == currentPriority
		} else {
			return false
		}
	}

	///	Suspends emulation.
	///
	///	When emualtion is already suspended with a lower priority than the specified one, updates
	///	suspension priority to the specified one.
	func suspend(priority: SuspensionPriority = .normal) {
		// note: it seems impossible to combine first two cases into one
		// due to value binding on .suspended case
		switch self.state {
		case .resumed:
			self.state = .suspended(priority)
		case .suspended(let currentPriority) where currentPriority < priority:
			self.state = .suspended(priority)
		default:
			return
		}
	}

	/// Resumes emulation when it is suspended with a priority lower or equal to the specified one.
	func resume(priority: SuspensionPriority = .normal, until suspension: (condition: () -> Bool, callback: () -> Void)? = nil) {
		// do not resume emulation when current suspension priority is higher
		guard case .suspended(let currentPriority) = self.state,
			  currentPriority <= priority else {
			return
		}

		if let (condition, callback) = suspension {
			self.suspension = (condition, callback, priority)
		}

		self.state = .resumed
		if let (condition, callback, priority) = self.suspension {
			while case .resumed = self.state {
				racer_atari2600_advance_clock(self.ref)

				if condition() {
					self.state = .suspended(priority)
					self.suspension = nil
					callback()
				}
			}
		} else {
			while case .resumed = self.state {
				racer_atari2600_advance_clock(self.ref)
			}
		}
	}
}
