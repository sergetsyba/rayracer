//
//  TIA+Player.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Player: MovableObject {
		public var position: Int = 0
		public var motion: Int = 0
		
		public var graphics: (UInt8, UInt8) = (0, 0)
		public var delayed: Bool = false
		public var reflected: Bool = false
		public var copies: Int = 1
		
		var draws: Bool {
			// ensure player copy appears in the current 8-point section
			guard Self.sections[self.copies][self.position / 8] else {
				return false
			}
			
			let graphics = self.delayed
			? self.graphics.1
			: self.graphics.0
			
			let bit = (self.position / self.scale) % 8
			
			return self.reflected
			? graphics[bit]
			: graphics[7 - bit]
		}
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Player {
	/// A look-up table of 8 color clock wide screen sections, where a player can or cannot be drawn,
	/// based on the value in a corresponding NUSIZ register.
	private static let sections = [
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
}
