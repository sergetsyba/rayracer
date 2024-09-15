//
//  Console.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Foundation

public class Atari2600: ObservableObject {
	private(set) public var cpu: MOS6507!
	private(set) public var riot: MOS6532!
	private(set) public var tia: TIA!
	private(set) public var cartridge: Data? = nil
	private(set) public var frame = Data(count: 262 * 228)
	
	public var switches: Switches = .random()
	public var joystic = Joystick()
	
	public init() {
		self.cpu = MOS6507(bus: self)
		self.riot = MOS6532(ports: (self.joystic, self))
		self.tia = TIA()
	}
	
	// Resets internal state.
	public func reset() {
		self.cpu.reset()
		self.riot.reset()
	}
	
	public func setSwitch(_ switch: Switches, on: Bool) {
		if on {
			self.switches.insert(`switch`)
		} else {
			self.switches.remove(`switch`)
		}
	}
	
	public func insertCartridge(_ data: Data) {
		self.cartridge = data
		self.reset()
	}
}


// MARK: -
// MARK: Debugging
extension Atari2600 {
	public func resume(until breakpoints: any Sequence<Int>) {
		repeat {
			self.stepInstruction()
		} while breakpoints.contains(self.cpu.programCounter) == false
	}
	
	/// Advances console state to the beginning of the first program instruction in the next TV field.
	public func stepField() {
		self.advanceClock()
		while self.tia.screenClock > 0 {
			self.advanceClock()
		}
		
		// finish current instruction when new field begins in
		// the middle of executing it
		while !self.cpu.sync {
			self.advanceClock()
		}
	}
	
	/// Advances console state to the beginning of the first program instruction in the next scan line.
	public func stepScanLine() {
		self.advanceClock()
		while self.tia.colorClock > 0 {
			self.advanceClock()
		}
		
		// finish current instruction when new scan line begins in
		// the middle of executing it
		while !self.cpu.sync {
			self.advanceClock()
		}
	}
	
	/// Advances console state to the beginning of the next program instruction.
	public func stepInstruction() {
		// advance TIA to horizontal sync when WSYNC is on
		while self.tia.waitingHorizontalSync {
			self.advanceClock()
		}
		
		self.advanceClock()
		while !self.cpu.sync {
			self.advanceClock()
		}
	}
	
	private func advanceClock() {
		self.tia.advanceClock()
		self.tia.advanceClock()
		self.tia.advanceClock()
		
		if !self.tia.waitingHorizontalSync {
			self.cpu.advanceClock()
		}
		self.riot.advanceClock()
	}
}


// MARK: -
extension Atari2600: Addressable {
	public func unmirror(_ address: Int) -> Int {
		if (0x0040..<0x0080).contains(address) {
			return address - 0x40
		}
		if (0x5000..<0x6000).contains(address) {
			return address + 0xa000
		}
		return address
	}
	
	public func read(at address: Int) -> Int {
		let address = self.unmirror(address)
		if (0x0000..<0x0040).contains(address) {
			return self.tia.read(at: address)
		}
		if (0x0080..<0x0100).contains(address) {
			let address = address - 0x0080
			let data = self.riot.memory[address]
			return Int(data)
		}
		if (0x0280..<0x0300).contains(address) {
			let address = address - 0x0280
			return self.riot.read(at: address)
		}
		
		let data = self.cartridge?[address - 0xf000]
		?? 0xea//.random(in: 0x00...0xff)
		
		return Int(data)
	}
	
	public func write(_ data: Int, at address: Int) {
		let address = self.unmirror(address)
		if (0x0000..<0x0040).contains(address) {
			return self.tia.write(data, at: address)
		}
		if (0x0080..<0x0100).contains(address) {
			let address = address - 0x0080
			return self.riot.memory[address] = UInt8(data)
		}
		if (0x0280..<0x0300).contains(address) {
			let address = address - 0x0280
			return self.riot.write(data, at: address)
		}
		
		let message = String(format: "Ignoring write at address $%04x", address)
		print(message)
	}
}


// MARK: - Console switches
extension Atari2600 {
	public struct Switches: OptionSet {
		public static let reset = Switches(rawValue: 1 << 0)
		public static let select = Switches(rawValue: 1 << 1)
		public static let color = Switches(rawValue: 1 << 3)
		public static let difficulty0 = Switches(rawValue: 1 << 6)
		public static let difficulty1 = Switches(rawValue: 1 << 7)
		
		public var rawValue: Int
		
		public static func random() -> Switches {
			let value: Int = .random(in: 0x00...0xff)
			return Switches(rawValue: value)
		}
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}

extension Atari2600: MOS6532.Port {
	public func read() -> Int {
		// when switches for `select` and `reset` are on, corresponding
		// bit values are set to 0
		return self.switches.rawValue ^ 0x03
	}
	
	public func write(_ data: Int) {
		// port B is supposed to be read-only, but can be written to
		// nonetheless; writing sets the 3 unassigned bits
		self.switches.rawValue |= data & 0x34
	}
}


// MARK: - Joystick
extension Atari2600 {
	public struct Joystick {
	}
}

extension Atari2600.Joystick: MOS6532.Port {
	public func read() -> Int {
		return 0
	}
	
	public mutating func write(_ data: Int) {
	}
}
