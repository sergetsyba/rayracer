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
	
	var backgroundColor: Int {
		return self.colubk
	}
	
	var playfield: Playfield {
		return Playfield(
			graphics: [self.pf0, self.pf1, self.pf2],
			reflected: self.ctrlpf[0],
			color: self.colupf)
	}
	
	var missiles: (Missile, Missile) {
		return (
			Missile(
				enabled: self.enam0,
				size: 1 << ((self.nusiz0 >> 4) & 0x3),
				color: self.colup0,
				position: (self.resm0, Int(signed: self.hmm0 >> 4, bits: 4))),
			Missile(
				enabled: self.enam1,
				size: 1 << ((self.nusiz1 >> 4) & 0x3),
				color: self.colup1,
				position: (self.resm1, Int(signed: self.hmm1 >> 4, bits: 4)))
		)
	}
	
	var ball: Ball {
		return Ball(
			enabled: self.enabl >= 0,
			size: 0x1 << Int(bits: self.ctrlpf[4...5]),
			color: self.colupf,
			position: (0, 0),
			verticalDelay: false)
	}
}

public struct Playfield {
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

public struct Missile {
	public var enabled: Bool
	public var size: Int
	public var color: Int
	public var position: (Int, Int)
}

public struct Ball {
	public var enabled: Bool
	public var size: Int
	public var color: Int
	public var position: (Int, Int)
	public var verticalDelay: Bool
}
