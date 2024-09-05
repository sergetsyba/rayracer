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
extension TIA.Player: TIA.GraphicsObject {
	private static let sectionLookUp = [
		0x001, // ●○○○○○○○○○
		0x005, // ●○●○○○○○○○
		0x011, // ●○○●○○○○○○
		0x015, // ●○●○●○○○○○
		0x101, // ●○○○○○○○●○
		0x001, // ●●○○○○○○○○
		0x111, // ●○○○●○○○●○
		0x001  // ●●●●○○○○○○
	]
	
	public func draws(at position: Int) -> Bool {
		// ensure beam position is within possible player graphics
		// positions range
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
		
		return self.reflected
		? graphics[counter % 8]
		: graphics[7 - counter % 8]
	}
}
