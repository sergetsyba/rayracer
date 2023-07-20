//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Combine

public class Atari2600: ObservableObject {
	private var debugEventSubject = PassthroughSubject<DebugEvent, Never>()
	private var eventSubject = PassthroughSubject<Event, Never>()
	
	private(set) public var cpu: MOS6507
	private(set) public var riot: MOS6532
	private(set) public var tia: TIA
	private(set) public var cartridge: Data? = nil
	
	public init() {
		let cpu = MOS6507()
		
		self.cpu = cpu
		self.riot = MOS6532()
		self.tia = TIA(cpu: cpu)
		
		// TODO: move to CPU init
		self.cpu.bus = self
	}
	
	public func insertCartridge(fromFileAt url: URL) throws {
		self.cartridge = try Data(contentsOf: url)
		self.cpu.reset()
		self.eventSubject.send(.reset)
	}
}


// MARK: -
// MARK: Events
public extension Atari2600 {
	enum Event {
		case reset
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}


// MARK: -
// MARK: Debugging
public extension Atari2600 {
	enum DebugEvent {
		case `break`
		case step
		case resume
	}
	
	var debugEvents: some Publisher<DebugEvent, Never> {
		return self.debugEventSubject
	}
	
	func advanceProgram() {
		if self.tia.wsync {
			self.tia.advanceLine()
		}
		
		let cycles = self.cpu.nextExecutionDuration
		self.tia.advanceClock(cycles: cycles * 3)
		self.riot.advanceClock(cycles: cycles)		
		self.cpu.executeNextInstruction()
	}
	
	func stepProgram() {
		self.advanceProgram()
		self.debugEventSubject.send(.break)
	}
	
	func resumeProgram(until breakpoints: [Address]) {
		repeat {
			self.stepProgram()
		} while breakpoints.contains(self.cpu.programCounter) == false
		self.debugEventSubject.send(.break)
	}
}


// MARK: -
public typealias Address = Int

protocol Bus {
	func read(at address: Address) -> Int
	mutating func write(_ value: Int, at address: Address)
}


// MARK: -
// MARK: Memory segments
extension MOS6507: CPU {
}


// MARK: -
extension Atari2600: Bus {
	private func unmirror(_ address: Address) -> Address {
		if (0x0040..<0x0080).contains(address) {
			return address - 0x40
		}
		if (0x5000..<0x6000).contains(address) {
			return address + 0xa000
		}
		return address
	}
	
	func read(at address: Address) -> Int {
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
		
		let data = self.cartridge![address - 0xf000]
		return Int(data)
	}
	
	func write(_ data: Int, at address: Address) {
		let address = self.unmirror(address)
		if (0x0000..<0x0040).contains(address) {
			if address == 0x09 {
				let message = String(format: "$%04x colubk: #%02x", self.cpu.programCounter, data)
				print(message)
			}
			
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
