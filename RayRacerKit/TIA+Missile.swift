//
//  TIA+Missile.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Missile: MovableObject {
		public var position: Int = 0 {
			didSet { self.position %= 160 }
		}
		public var motion: Int = 0
		
		public var enabled: Bool = false
		public var copies: Int = 1
		public var size: Int = 1
		
		var needsDrawing: Bool {
			return Self.sections[self.copies][self.position / 8]
			&& self.enabled
			&& self.position < self.size
		}
	}
}

private extension TIA.Missile {
	/// A look-up table of 8 color clock wide screen sections, where a missile can or cannot be drawn,
	/// based on the value in a corresponding NUSIZ register.
	static let sections = [
		0x001, // ●○○○○○○○○○
		0x005, // ●○●○○○○○○○
		0x011, // ●○○●○○○○○○
		0x015, // ●○●○●○○○○○
		0x101, // ●○○○○○○○●○
		0x001, // ●○○○○○○○○○
		0x111, // ●○○○●○○○●○
		0x001  // ●○○○○○○○○○
	]
}
