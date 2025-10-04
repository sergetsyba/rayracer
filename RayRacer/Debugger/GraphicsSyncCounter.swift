//
//  GraphicsSyncCounter.swift
//  RayRacer
//
//  Created by Serge Tsyba on 1.7.2025.
//

import RayRacerKit

class GraphicsSyncCounter: TIA.GraphicsOutput {
	private(set) var counts: (vertical: Int, horizontal: Int) = (0, 0)
	var output: TIA.GraphicsOutput? = nil
	
	func sync(_ sync: RayRacerKit.TIA.GraphicsSync) {
		switch sync {
		case .vertical:
			self.counts.0 += 1
		case .horizontal:
			self.counts.1 += 1
		}
		
		self.output?
			.sync(sync)
	}
	
	func blank() {
		// does nothing
	}
	
	func write(color: Int) {
		self.output?
			.write(color: color)
	}
}
