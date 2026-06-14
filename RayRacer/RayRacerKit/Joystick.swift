//
//  Joystick.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2026.
//

import librayracer

class Joystick {
	typealias Buttons = racer_joystick_button

	private let console: UnsafeMutablePointer<racer_atari2600>!
	private var pressedButtons: Buttons = [] {
		didSet {
			let buttons = UInt8(self.pressedButtons.rawValue)
			racer_joysticks_write_output(self.console, [buttons, 0])
		}
	}

	init(console: UnsafeMutablePointer<racer_atari2600>!) {
		self.console = console
	}

	func press(_ buttons: Buttons) {
		self.pressedButtons.insert(buttons)
	}

	func release(_ buttons: Buttons) {
		self.pressedButtons.remove(buttons)
	}
}

extension Joystick.Buttons: @retroactive SetAlgebra {}
extension Joystick.Buttons: @retroactive ExpressibleByArrayLiteral {}
extension Joystick.Buttons: @retroactive OptionSet {
	static let up = JOYSTICK_BUTTON_UP
	static let down = JOYSTICK_BUTTON_DOWN
	static let left = JOYSTICK_BUTTON_LEFT
	static let right = JOYSTICK_BUTTON_RIGHT
	static let fire = JOYSTICK_BUTTON_FIRE
}
