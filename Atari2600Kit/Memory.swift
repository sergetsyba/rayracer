//
//  Memory.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public typealias Memory = Data

public extension Memory {
	var tiaRegisters: Self.SubSequence {
		return self[.tiaRegistersRange]
	}
	
	var ram: Self.SubSequence {
		return self[.ramRange]
	}
	
	var riotRegisters: Self.SubSequence {
		return self[.riotRegistersRange]
	}
	
	var rom: Self.SubSequence {
		get {
			return self[.romRange]
		}
		set {
			self[.romRange] = newValue
		}
	}
}

private extension Range<Memory.Index> {
	static let tiaRegistersRange = 0x0000..<0x007f
	static let ramRange = 0x0080..<0x00ff
	static let riotRegistersRange = 0x0200..<0x02ff
	static let romRange = 0xf000..<0xffff
}
