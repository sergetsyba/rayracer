//
//  Joystick.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 16.11.2024.
//

public struct Joystick {
	private(set) var pressed = Buttons()
	public var eventHanlder: ((Buttons) -> Void)?
	
	var output: Int {
		return self.pressed.rawValue
	}
	
	public mutating func press(_ buttons: Buttons) {
		self.pressed.insert(buttons)
		self.eventHanlder?(self.pressed)
	}
	
	public mutating func release(_ buttons: Buttons) {
		self.pressed.remove(buttons)
		self.eventHanlder?(self.pressed)
	}
}

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


extension Joystick: MOS6532.Peripheral, TIA.Peripheral {
	public func read() -> Int {
		
		
		return 0x0
	}
	
	public func write(_ data: Int) {
		//
	}
}
