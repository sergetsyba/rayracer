//
//  TIA+Playfield.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Playfield {
		public var graphics: [UInt8] = [0, 0, 0]
		public var control: Control = []
		
		func draws(at position: Int) -> Bool {
			let position = self.control[.reflected] && position >= 80
			? 23 - (position % 80) / 4
			: (position % 80) / 4 + 4
			
			return self.graphics[position / 8][position % 8]
		}
	}
}

extension TIA.Playfield {
	public struct Control: OptionSet {
		public static let reflected = Control(rawValue: 1 << 0)
		public static let scoreMode = Control(rawValue: 1 << 1)
		public static let priority = Control(rawValue: 1 << 2)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}

extension UInt8 {
	subscript(bit: Int) -> Bool {
		get {
			let mask: Self = 0x01 << bit
			return self & mask == mask
		}
		set {
			let mask: Self = 0x01 << bit
			if newValue {
				self |= mask
			} else {
				self &= ~mask
			}
		}
	}
}
