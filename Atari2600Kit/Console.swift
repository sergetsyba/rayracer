//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class Atari2600: ObservableObject {
	private(set) public var cpu: MOS6507
	private(set) public var riot = MOS6532()
	private(set) public var tia: TIA
	
	@Published
	public var cartridge: Data? = nil
	
	public init() {
		let cpu = MOS6507()
		
		self.cpu = cpu
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
		if self.tia.wsync {
			let cycles = self.tia.resumeLine()
			self.cpu.cycles += cycles / 3
		}
		
		let cycles = self.cpu.nextExecutionDuration
		self.tia.resume(cycles: cycles * 3)
		self.cpu.executeNextInstruction()
		self.cpu.cycles += cycles
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


typealias AddressRange = Range<Int>
extension AddressRange {
	static let memory: Self = 0x0080..<0x0100
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
		
		if (0x0000...0x003f).contains(address) {
			return 0x00
		} else if AddressRange.memory.contains(address) {
			return self.riot.readMemory(at: address - 0x0080)
		} else {
			return Int(self.cartridge![address - 0xf000])
		}
	}
	
	func write(_ data: Int, at address: Address) {
		let address = self.unmirror(address)
		
		if (0x0000...0x003f).contains(address) {
			self.tia.write(data, at: address)
		} else if AddressRange.memory.contains(address) {
			self.riot.writeMemory(data, at: address - AddressRange.memory.lowerBound)
		}
	}
}
