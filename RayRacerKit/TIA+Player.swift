//
//  TIA+Player.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Player: MovableObject {
		public var graphics: (UInt8, UInt8)
		public var copyMask: Int
		public var scale: Int
		public var options: Options
		
		public var position: Int = 0 {
			didSet {
				if self.position == 160 {
					self.position = 0
					self.missile?.pointee
						.position = 0
				}
			}
		}
		public var motion: Int = 0
		
		var missile: UnsafeMutablePointer<Missile>?
		
		init(graphics: (UInt8, UInt8) = (0x00, 0x00), copyMask: Int = 0x001, scale: Int = 0, options: Options = []) {
			self.graphics = graphics
			self.copyMask = copyMask
			self.scale = scale
			self.options = options
		}
		
		mutating func reset() {
			// player takes an extra color clock cycle to latch position
			// counter value
			self.position = 160-4-1
		}
	}
}

extension TIA.Player {
	public struct Options: OptionSet {
		public static let reflected = Options(rawValue: 1 << 0)
		public static let delayed = Options(rawValue: 1 << 1)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Player {
	var needsDrawing: Bool {
		var section = self.position >> 3	// position / 8
		section >>= self.scale				// position / size
		
		// ensure position counter is within any of the sections where
		// a player can be drawn
		guard self.copyMask[section] else {
			return false
		}
		
		let graphics = self.options[.delayed]
		? self.graphics.1
		: self.graphics.0
		
		var bit = self.position & 0x7		// position % 8
		if self.options[.reflected] {
			bit = 7 - bit
		}
		
		return graphics[bit]
	}
}
