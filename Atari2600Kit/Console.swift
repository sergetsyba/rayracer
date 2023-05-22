//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public struct Atari2600 {
	private(set) public var cpu: MOS6507
	private(set) public var memory: Data
	
	public init() {
		self.cpu = MOS6507()
		self.memory = Data(repeating: 0x00, count: 0x1fff)
	}
}
