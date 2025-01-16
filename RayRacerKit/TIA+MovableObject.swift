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
	mutating func resetPosition() {
		self.position = 160-4
	}
	
	mutating func advanceClock() {
		self.position += 1
		self.position %= 160
	}
	
	mutating func applyMotion() {
		self.position += self.motion
		self.position %= 160
	}
}
