//
//  Console+Switches.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 19.11.2024.
//

extension Atari2600 {
	public struct Switches: OptionSet {
		public static let reset = Switches(rawValue: 1 << 0)
		public static let select = Switches(rawValue: 1 << 1)
		public static let color = Switches(rawValue: 1 << 3)
		public static let difficulty0 = Switches(rawValue: 1 << 6)
		public static let difficulty1 = Switches(rawValue: 1 << 7)
		
		public var rawValue: Int
		
		public init(rawValue: Int = 0x8) {
			self.rawValue = rawValue
		}
	}
}

extension Atari2600.Switches: MOS6532.Peripheral {
	public func read() -> Int {
		// when switches for `select` and `reset` are on, corresponding
		// bits are 0
		return self.rawValue ^ 0x03
	}
	
	public mutating func write(_ data: Int) {
		// switches are supposed to be read-only, but can be written to
		// nonetheless; writing sets the 3 unused bits
		self.rawValue &= ~0x34
		self.rawValue |= data & 0x34
	}
}
