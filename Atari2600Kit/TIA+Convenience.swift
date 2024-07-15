//
//  TIA+Convenience.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 24.6.2024.
//

public extension TIA {
	var beamPosition: (Int, Int) {
		return (self.cycle / 228, self.cycle % 228)
	}
	
	var verticalSync: (Bool, Int) {
		return (self.vsync > -1, self.cycle - self.vsync)
	}
	
	var verticalBlank: Bool {
		return self.vblank
	}
	
	var awaitingHorizontalSync: Bool {
		return self.wsync
	}
	
	var ball: Ball {
		return Ball(
			enabled: false,
			size: 0x1 << Int(bits: self.playfieldControl[4...5]),
			color: self.playfieldColor,
			position: (0, 0),
			verticalDelay: false)
	}
}

public struct Ball {
	public var enabled: Bool
	public var size: Int
	public var color: Int
	public var position: (Int, Int)
	public var verticalDelay: Bool
}
