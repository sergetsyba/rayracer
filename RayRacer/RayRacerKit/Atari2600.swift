//
//  Atari2600.swift
//  RayRacer
//
//  Created by Serge Tsyba on 15.12.2025.
//

import Foundation
import librayracer

class Atari2600 {
	let ref: UnsafeMutablePointer<racer_atari2600>!
	private var program: Data!

	init() {
		self.ref = racer_atari2600_create()!
		self.switches = UserDefaults.standard.consoleSwitches
	}

	var cartridge: Cartridge? {
		didSet {
			// remove old cartridge, when inserted
			if let program {
				racer_atari2600_remove_cartridge(self.ref)
				self.program = nil
			}

			guard var cartridge else {
				return
			}

			// load propgram when not yet loaded
			self.program = cartridge.program ?? (try! cartridge.load())

			// insert new cartridge
			self.program.withUnsafeBytes() {
				let address = $0.baseAddress?.bindMemory(to: UInt8.self, capacity: self.program.count)
				racer_atari2600_insert_cartridge(self.ref, cartridge.kind, address)
			}
		}
	}

	var controllers: (Joystick?, Joystick?) {
		didSet {
		}
	}

	var switches: Switches {
		didSet {
			self.ref.pointee
				.switches.1 = UInt8(self.switches.rawValue)
			UserDefaults.standard
				.consoleSwitches = self.switches
		}
	}

	func holdSwitch(_ `switch`: Switches, for interval: Int = 500) {
		// set switch to `on`
		self.switches[`switch`] = true

		// set switch to `off` after small interval
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
