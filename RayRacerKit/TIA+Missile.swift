//
//  TIA+Missile.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Missile: MovableObject {
		public var position = 0
		public var motion = 0
		
		public var enabled = false
		public var size = 1
		
		var draws: Bool {
			return self.enabled
			&& self.position < self.size
		}
	}
}
