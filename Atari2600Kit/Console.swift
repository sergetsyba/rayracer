//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	@Published private(set) public var cpu: MOS6507
	@Published private(set) public var memory: Memory
	@Published public var cartridge: Data?
	
	public init() {
		self.cpu = MOS6507()
		self.memory = Memory(size: 0xffff)
		self.cpu.bus = self
	}
	
	public func insertCartridge(fromFileAt url: URL) throws {
		self.cartridge = try Data(contentsOf: url)
		self.cpu.reset()
	}
}


// MARK: -
// MARK: Memory segments
public extension Memory {
	var tiaRegisters: Memory {
		return self[0x0000..<0x007f]
	}
	
	var ram: Memory {
		return self[0x0080..<0x00ff]
	}
	
	var riotRegisters: Memory {
		return self[0xf000..<0xffff]
	}
}


// MARK: -
extension Atari2600: MOS6502Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word {
		return address < 0xf000
		? MOS6507.Word(self.memory[Int(address)])
		: MOS6507.Word(self.cartridge![Int(address - 0xf000)])
	}
	
	func write(_ value: MOS6507.Word, at address: MOS6507.Address) {
		// TODO: restrict address
		self.memory[address] = value
	}
}
