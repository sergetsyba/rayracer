//
//  TIA+Ball.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Ball: MovableObject {
		public var position = 0
		public var motion = 0
		
		public var enabled = (false, false)
		public var delayed = false
		public var size = 1
		public var color = 0
		
		var draws: Bool {
			let enabled = self.delayed
			? self.enabled.1
			: self.enabled.0
			
			return enabled
			&& self.position < self.size
		}
	}
}
