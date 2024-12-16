//
//  TIA+Player.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Player {
		public var graphics: (Int, Int)
		public var reflected: Bool
		public var copies: Int
		public var color: Int = 0
		public var position: Int
		public var motion: Int
		public var delayed: Bool
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Player: TIA.Drawable {
	private static let sectionLookUp = [
		0x001, // ●○○○○○○○○○
		0x005, // ●○●○○○○○○○
		0x011, // ●○○●○○○○○○
		0x015, // ●○●○●○○○○○
		0x101, // ●○○○○○○○●○
		0x003, // ●●○○○○○○○○
		0x111, // ●○○○●○○○●○
		0x00f  // ●●●●○○○○○○
	]
	
	private var scale: Int {
		switch self.copies {
		case 5: return 2
		case 7: return 4
		default: return 1
		}
	}
	
	public func draws(at position: Int) -> Bool {
		let counter = position - self.position
		guard (0..<80).contains(counter) else {
			return false
		}
		
		// ensure player copy appears in the current 8-point section
		guard Self.sectionLookUp[self.copies][counter / 8] else {
			return false
		}
		
		let graphics = self.delayed
		? self.graphics.1
		: self.graphics.0
		
		let bit = (counter / self.scale) % 8
		
		return self.reflected
		? graphics[bit]
		: graphics[7 - bit]
	}
}
