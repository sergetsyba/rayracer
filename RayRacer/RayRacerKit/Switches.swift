//
//  Switches.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2026.
//

import Foundation
import librayracer

typealias Switches = racer_atari2600_switch
extension Switches: @retroactive OptionSet, SetAlgebra {
	static let reset = ATARI2600_SWITCH_RESET
	static let select = ATARI2600_SWITCH_SELECT
	static let color = ATARI2600_SWITCH_COLOR
	static let difficulty0 = ATARI2600_SWITCH_DIFFICULTY_0
	static let difficulty1 = ATARI2600_SWITCH_DIFFICULTY_1
}

// MARK: -
// MARK: User defaults integration
extension Switches {
	static let `default`: Self = [.color, .difficulty0, .difficulty1]
}

extension UserDefaults {
	var consoleSwitches: Switches {
		get {
			guard let value = self.value(forKey: .consoleSwitches) as? UInt32 else {
				return .default
			}
			return Switches(rawValue: value)
		}
		set {
			self.setValue(newValue.rawValue, forKey: .consoleSwitches)
		}
	}
}

private extension String {
	static let consoleSwitches = "ConsoleSwitches"
}
