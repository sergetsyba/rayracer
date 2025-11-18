//
//  TIA+Missile.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Missile: MovableObject {
		public var size: Int
		public var copyMode: Int
		public var options: Options
		
		public var position: Int = 0 {
			didSet {
				if self.position == 160 {
					self.position = 0
				}
			}
		}
		public var motion: Int = 0
		
		public init(size: Int = 1, copyMode: Int = 0, options: Options = []) {
			self.size = size
			self.copyMode = copyMode
			self.options = options
		}
	}
}

extension TIA.Missile {
	public struct Options: OptionSet {
		public static let enabled = Options(rawValue: 1 << 0)
		public static let resetToPlayer = Options(rawValue: 1 << 1)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Missile {
	var needsDrawing: Bool {
		// ensure missile is enabled and not reset to player
		guard self.options == [.enabled] else {
			return false
		}
		
		// NOTE: performance measurements showed no difference between storing
		// copyMask directly as a property and looking it up each time
		let copyMask = TIA.copyMasks[self.copyMode]
		let section = self.position >> 3	// position / 8
		
		// ensure position counter is within any of the sections where
		// a missile can be drawn
		guard copyMask[section] else {
			return false
		}
		
		return self.position < self.size
	}
}
