//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	@Published private(set) public var cpu: MOS6507
	@Published private(set) public var memory: Memory
	private(set) public var tia: TIA!
	@Published public var cartridge: Data?
	
	public init() {
		self.cpu = MOS6507()
		self.memory = Memory(size: 0xffff)
		self.tia = TIA(bus: self)
		
		// TODO: move to CPU init
		self.cpu.bus = self
	}
	
	public func insertCartridge(fromFileAt url: URL) throws {
		self.cartridge = try Data(contentsOf: url)
		self.cpu.reset()
	}
	
	public func step() {
		let clockCycles = self.cpu.step()
		let colorCycles = 3 * clockCycles
		self.tia.step(cycles: colorCycles)
	}
	
	public func resume(until breakpoints: [MOS6507.Address]) {
		repeat {
			self.step()
		} while breakpoints.contains(self.cpu.programCounter) == false
	}
}


// MARK: -
protocol Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word
	func write(_ value: MOS6507.Word, at address: MOS6507.Address)
}


// MARK: -
// MARK: Memory segments
public extension Memory {
	var tiaRegisters: Memory {
		return self[0x0000..<0x0040]
	}
	
	var ram: Memory {
		return self[0x0080..<0x0100]
	}
	
	var riotRegisters: Memory {
		return self[0xf000..<0xffff]
	}
}


// MARK: -
extension Atari2600: Bus {
	static let mirrors: [ClosedRange<Int>: ClosedRange<Int>] = [
		0x0000...0x003f: 0x0000...0x003f,
		0x0040...0x007f: 0x0000...0x003f,
		// RAM
		0x0080...0x00ff: 0x0080...0x00ff,
		0x0180...0x01ff: 0x0080...0x00ff
	]
	
	public func unmirror(_ address: MOS6507.Address) -> MOS6507.Address {
		for (mirror, _) in Self.mirrors {
			if mirror.contains(address) {
				return address - mirror.lowerBound
			}
		}
		return address
	}
	
	func read(at address: MOS6507.Address) -> MOS6507.Word {
		if address < 0xf000 {
			let address = self.unmirror(address)
			return self.memory[address]
		} else {
			return MOS6507.Word(self.cartridge![address - 0xf000])
		}
	}
	
	func write(_ value: MOS6507.Word, at address: MOS6507.Address) {
		let address = self.unmirror(address)
		self.memory[address] = value
	}
}
