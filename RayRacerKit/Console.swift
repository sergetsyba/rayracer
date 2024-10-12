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
	
	private(set) public var paused = true
	
	public init() {
		self.cpu = MOS6507(bus: self)
		self.riot = MOS6532(ports: (self.joystic, self))
		self.tia = TIA()
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
	}
	
	/// Pauses program execution when it is being executed.
	public func pause() {
		self.paused = true
	}
	
	/// Resumes program execution when it is paused.
	public func resume() {
		guard self.paused else {
			return
		}
		
		self.paused = false
		while self.paused == false {
			self.advanceCycle()
		}
	}
	
	/// Resets internal state.
	public func reset() {
		self.cpu.reset()
		self.riot.reset()
		self.tia.reset()
	}
}


// MARK: -
// MARK: Debugging
extension Atari2600 {
	/// Resumes program execution until the first instruction at one of the specified addresses.
	public func resume(until breakpoints: any Sequence<Int>) {
		repeat {
			self.stepInstruction()
		} while !self.cpu.sync || !breakpoints.contains(self.cpu.programCounter)
	}
	
	/// Resumes program execution until the first instruction in the next TV field.
	public func stepField() {
		self.stepScanLine()
		repeat {
			self.advanceCycle()
		} while !self.cpu.sync || self.tia.scanLine > 0
	}
	
	/// Resumes program execution until the first instruction in the next TV scan line.
	public func stepScanLine() {
		let scanLine = self.tia.scanLine
		repeat {
			self.advanceCycle()
		} while !self.cpu.sync || self.tia.scanLine == scanLine
	}
	
	/// Resumes program execution for a single instruction.
	public func stepInstruction() {
		repeat {
			self.advanceCycle()
		} while !self.cpu.sync || self.tia.awaitsHorizontalSync
	}
	
	/// Advances TIA clock by 3 units and RIOT and CPU clock by 1, unless CPU is halted by the TIA.
	private func advanceCycle() {
		// NOTE: even when color clock resets during any of the three TIA clock
		// cycles and WSYNC switches off, CPU clock cycle should not be
		// executed, since in hardware these happen simulatenously;
		// so the check for CPU being ready or halted has to happen first
		let cpuReady = !self.tia.awaitsHorizontalSync
		
		self.tia.advanceClock()
		self.tia.advanceClock()
		self.tia.advanceClock()
		
		self.riot.advanceClock()
		if cpuReady {
			self.cpu.advanceClock()
		}
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
