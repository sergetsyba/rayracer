//
//  TIA+Missile.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Missile {
		public var enabled: Bool
		public var size: Int
		public var color: Int
		public var position: Int
		public var motion: Int
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Missile: TIA.GraphicsObject {
	public func draws(at position: Int) -> Bool {
		guard self.enabled else {
			return false
		}
		
		let counter = position - self.position
		return (0..<self.size)
			.contains(counter)
	}
}
