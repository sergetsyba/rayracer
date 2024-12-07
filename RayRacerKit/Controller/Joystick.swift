//
//  Joystick.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 16.11.2024.
//

public class Joystick {
	private(set) var pressed = Buttons()
	
	public init(pressed: Buttons = []) {
		self.pressed = pressed
	}
	
	public func press(_ buttons: Buttons) {
		self.pressed.insert(buttons)
	}
	
	public func release(_ buttons: Buttons) {
		self.pressed.remove(buttons)
	}
}

// MARK: -
// MARK: Buttons
extension Joystick {
	public struct Buttons: OptionSet {
		public static let up = Buttons(rawValue: 1 << 0)
		public static let down = Buttons(rawValue: 1 << 1)
		public static let left = Buttons(rawValue: 1 << 2)
		public static let right = Buttons(rawValue: 1 << 3)
		public static let fire = Buttons(rawValue: 1 << 5)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}

// MARK: -
// MARK: Controller
extension Joystick: Controller {
	public var output: Int {
		let data = self.pressed.rawValue
		return ~data & 0xff
	}
}
