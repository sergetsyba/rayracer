//
//  TIA+Playfield.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Playfield {
		public var graphics: Int
		public var control: PlayfieldControl
		public var color: Int
	}

	public struct PlayfieldControl: OptionSet {
		public static let reflected = PlayfieldControl(rawValue: 1 << 0)
		public static let scoreMode = PlayfieldControl(rawValue: 1 << 1)
		public static let priority = PlayfieldControl(rawValue: 1 << 2)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Playfield: TIA.Drawable {
	public func draws(at position: Int) -> Bool {
		let bit = (position / 4) % 20
		if position < 80 {
			// left playfield side
			return self.graphics[bit]
		} else {
			// right playfield side
			return self.control.contains(.reflected)
			? self.graphics[19 - bit]
			: self.graphics[bit]
		}
	}
}
