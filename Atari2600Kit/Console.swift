//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	@Published private(set)
	public var cpu: MOS6507
	private var riot = MOS6532()
	
	@Published private(set)
	public var memory: Memory
	
	private(set) public var tia: TIA!
	
	@Published
	public var cartridge: Data?
	
	@Published private(set)
	public var cycles: Int = 0
	
	private var waitSync = false
	
	public init() {
		let cpu = MOS6507()
		
		self.cpu = cpu
		self.memory = Memory(size: 0xffff)
		self.tia = TIA(cpu: cpu)
		
		// TODO: move to CPU init
		self.cpu.bus = self
	}
	
	public func insertCartridge(fromFileAt url: URL) throws {
		self.cartridge = try Data(contentsOf: url)
		self.cpu.reset()
	}
}


// MARK: -
// MARK: Debugging
public extension Atari2600 {
	func stepProgram() {
		let cycles = self.cpu.nextOperationDuration
		self.tia.advanceClock(cycles: cycles * 3)
		self.cpu.stepProgram()
		self.cycles += cycles
	}
	
	func resumeProgram(until breakpoints: [Address]) {
		repeat {
			self.stepProgram()
		} while breakpoints.contains(self.cpu.programCounter) == false
	}
}


// MARK: -
public typealias Address = Int

protocol Bus {
	func read(at address: Address) -> Int
	func write(_ value: Int, at address: Address)
}


// MARK: -
// MARK: Memory segments
extension MOS6507: CPU {
}

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
	
	public func unmirror(_ address: Address) -> Address {
		for (mirror, target) in Self.mirrors {
			if mirror.contains(address) {
				return address - (mirror.lowerBound - target.lowerBound)
			}
		}
		return address
	}
	
	func read(at address: Address) -> Int {
		let address = self.unmirror(address)
		
		switch address {
		case 0x284:
			return self.riot.timer
		case _ where address < 0xf000:
			return self.memory[address]
		default:
			return Int(self.cartridge![address - 0xf000])
		}
	}
	
	func write(_ data: Int, at address: Address) {
		let address = self.unmirror(address)
		
		if (0x0000...0x003f).contains(address) {
			self.tia.write(data, at: address)
		}
	}
}
