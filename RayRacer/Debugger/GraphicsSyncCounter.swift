//
//  GraphicsSyncCounter.swift
//  RayRacer
//
//  Created by Serge Tsyba on 1.7.2025.
//

class GraphicsSyncCounter: VideoOutput {
	private(set) var counts: (vertical: Int, horizontal: Int) = (0, 0)
	var output: VideoOutput? = nil
	
	func sync(_ sync: VideoSync) {
		if sync.contains(.horizontal) {
			self.counts.horizontal += 1
		}
		if sync.contains(.vertical) {
			self.counts.vertical += 1
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
