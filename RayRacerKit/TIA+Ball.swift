//
//  TIA+Ball.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Ball: MovableObject {
		public var position: Int = 0 {
			didSet { self.position %= 160 }
		}
		public var motion: Int = 0
		
		public var enabled: (Bool, Bool) = (false, false)
		public var delayed: Bool = false
		public var size: Int = 1
		
		var graphics: UInt8 {
			return (1 << self.size) - 1
		}
		
		var needsDrawing: Bool {
			let enabled = self.delayed
			? self.enabled.1
			: self.enabled.0
			
			return enabled && self.position < self.size
		}
	}
}
