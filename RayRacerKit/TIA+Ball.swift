//
//  TIA+Ball.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Ball {
		public var enabled: (Bool, Bool)
		public var size: Int
		public var position: Int
		public var motion: Int
		public var delayed: Bool
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Ball: TIA.Drawable {
	public func draws(at position: Int) -> Bool {
		let enabled = self.delayed
		? self.enabled.1
		: self.enabled.0
		
		guard enabled else {
			return false
		}
		
		let counter = position - self.position
		return (0..<self.size)
			.contains(counter)
	}
}
