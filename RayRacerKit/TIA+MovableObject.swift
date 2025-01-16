//
//  TIA+MovableObject.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 16.1.2025.
//

extension TIA {
	protocol MovableObject {
		var position: Int { get set }
		var motion: Int { get set }
	}
}

extension TIA.MovableObject {
	mutating func advanceClock() {
		self.position += 1
		self.position %= 160
	}
	
	/// Resets position counter of this object.
	mutating func reset() {
		self.position = 160-4
	}
	
	/// Applies horizontal motion to the position counter of this object.
	mutating func move() {
		self.position += self.motion
		self.position %= 160
	}
}
