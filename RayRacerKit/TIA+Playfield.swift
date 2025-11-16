//
//  TIA+Playfield.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Playfield {
		public var graphics: UInt64
		public var options: Options
		
		public init(graphics: UInt64 = 0x00000_00000, options: Options = []) {
			self.graphics = graphics
			self.options = options
		}
	}
}

extension TIA.Playfield {
	public struct Options: OptionSet {
		public static let reflected = Options(rawValue: 1 << 0)
		public static let scoreMode = Options(rawValue: 1 << 1)
		public static let priority = Options(rawValue: 1 << 2)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Playfield {
	func draws(at position: Int) -> Bool {
		// each bit of playfield graphics draws for 4 color clocks
		var bit = position >> 2		// position / 4
		
		// NOTE: performance measurements showed that
		// 	1. looking up playfield graphics bit in 2 halves stored together
		//		is about 3% faster than looking it up in left half and
		//		re-calulating bit for the right half
		//	2. storing right half duplicated and re-calculating bit for when
		//		it is reflected is about 1% faster than storing right half
		//		reflected and looking up graphics bit directly
		if bit >= 20 && self.options[.reflected] {
			bit = 39 - bit
		}
		
		return self.graphics[bit]
	}
}


// MARK: -
// MARK: Convenience functionality
extension UInt64 {
	@inlinable
	@inline(__always)
	subscript(bit: Int) -> Bool {
		let mask: Self = 1 << bit
		return self & mask != 0
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
