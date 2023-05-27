//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	@Published public var cpu: MOS6507
	@Published public var memory: Memory
	
	public init() {
		self.cpu = MOS6507()
		self.memory = Data(repeating: 0x00, count: 0xffff)
		
		self.cpu.bus = self
	}
}


// MARK: -
extension Atari2600: MOS6502Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word {
		return self.memory[Int(address)]
	}
}
