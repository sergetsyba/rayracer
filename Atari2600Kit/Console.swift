//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Combine

public class Atari2600: ObservableObject {
	public var cpu: MOS6507
	public var memory: Memory
	private var rom: Data?
	
	@Published private(set) public var isCartridgeInserted = false
	
	public init() {
		self.cpu = MOS6507()
		self.memory = Data(repeating: 0x00, count: 0xffff)
		
		self.cpu.bus = self
	}
	
	public func insertCartridge(fromFileAt url: URL) throws {
		self.rom = try Data(contentsOf: url)
		self.isCartridgeInserted = true
	}
}

// MARK: -
extension Atari2600: MOS6502Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word {
		return address < 0xf000
		? MOS6507.Word(self.memory[Int(address)])
		: MOS6507.Word(self.rom![Int(address - 0xf000)])
	}
	
	func write(_ value: MOS6507.Word, at address: MOS6507.Address) {
		// TODO: write
	}
}
