//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	@Published private(set) public var cpu: MOS6507
	@Published private(set) public var memory: Memory
	
	public init() {
		self.cpu = MOS6507()
		self.memory = Data(repeating: 0x00, count: 0x1fff)
	}
}

public extension Atari2600 {
	func insertCartridge(data: Data) {
		self.memory.rom = data
	}
}
