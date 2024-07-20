//
//  TIA+Convenience.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 20.7.2024.
//

public extension TIA {
	var verticalSync: (Bool, Int) {
		return (self.verticalSyncClock > -1, self.verticalSyncClock)
	}
	
	var playfieldReflected: Bool {
		return self.playfieldControl[0]
	}
	
	var player0Copies: Int {
		return self.numberSize0 & 0x3
	}
	
	var player1Copies: Int {
		return self.numberSize1 & 0x3
	}
	
	var missile0Size: Int {
		return 1 << ((self.numberSize0 >> 4) & 0x3)
	}
	
	var missile1Size: Int {
		return 1 << ((self.numberSize1 >> 4) & 0x3)
	}
}
