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
	
	var awaitingHorizontalSync: Bool {
		return self.wsync
	}
	
	var backgroundColor: Int {
		return self.colubk
	}
	
	var playfield: PlayField {
		return PlayField(
			graphics: [self.pf0, self.pf1, self.pf2],
			reflected: self.ctrlpf[0],
			color: self.colupf)
	}
}

public struct PlayField {
	public var graphics: [Int]
	public var reflected: Bool
	public var color: Int
}

public struct Player {
	public var enabled: Bool
	public var graphics: Int
	public var copies: Int
	public var reflected: Bool
	public var color: Int
	public var position: Int
	public var horizontalMotion: Int
	public var verticalDelay: Int
	public var reset: Bool
}
