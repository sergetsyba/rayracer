//
//  Console.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Combine

public class Atari2600: ObservableObject {
	private var eventSubject = PassthroughSubject<Event, Never>()
	private var debugEventSubject = PassthroughSubject<DebugEvent, Never>()
	
	private(set) public var cpu: MOS6507!
	private(set) public var riot: MOS6532!
	private(set) public var tia: TIA!
	private(set) public var cartridge: Data? = nil
	
	private(set) public var frame = Data(count: 262 * 228)
	private(set) public var frameClock = 0
	
	public init() {
		self.cpu = MOS6507(bus: self)
		self.riot = MOS6532()
		self.tia = TIA(screen: self)
	}
	
	// Resets internal state.
	public func reset() {
		self.cpu.reset()
		self.riot.reset()
		self.tia.reset()
		
		self.frameClock = 0
		self.eventSubject.send(.reset)
	}
	
	// Loads cartridge data as ROM from a file at the specified URL.
	public func insertCartridge(fromFileAt url: URL) throws {
		self.cartridge = try Data(contentsOf: url)
	}
	
	public func insertCartridge(_ data: Data) {
		self.cartridge = data
	}
}


// MARK: -
// MARK: Events
public extension Atari2600 {
	enum Event {
		case reset
		case frame
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}

public extension Atari2600 {
	enum DebugEvent {
		case `break`
		case resume
	}
	
	var debugEvents: some Publisher<DebugEvent, Never> {
		return self.debugEventSubject
	}
}


// MARK: -
// MARK: Debugging
public extension Atari2600 {
	func stepProgram() {
		// when stepping a CPU instruction and WSYNC is on, advance TIA to
		// horizontal sync with CPU instruction
		if self.tia.waitingHorizontalSync {
			self.tia.advanceClockToHorizontalSync()
		}
		
		self.executeNextCPUInstruction()
		self.debugEventSubject.send(.break)
	}
	
	func stepScanLine() {
		let scanLine = self.scanLine
		repeat {
			// when stepping a scan line and WSYNC is on, advance TIA to
			// horizontal sync but break before CPU instruction
			if self.tia.waitingHorizontalSync {
				self.tia.advanceClockToHorizontalSync()
			} else {
				self.executeNextCPUInstruction()
			}
		} while self.scanLine == scanLine
		
		self.debugEventSubject.send(.break)
	}
	
	func stepFrame() {
		var clock1 = self.frameClock
		var clock2 = self.frameClock
		
		// keep executing CPU instructions until frame clock decreases
		repeat {
			clock1 = clock2
			if self.tia.waitingHorizontalSync {
				self.tia.advanceClockToHorizontalSync()
			}
			
			self.executeNextCPUInstruction()
			clock2 = self.frameClock
		} while clock1 < clock2
		
		self.debugEventSubject.send(.break)
	}
	
	func resumeProgram(until breakpoints: [Address]) {
		repeat {
			self.stepProgram()
		} while breakpoints.contains(self.cpu.programCounter) == false
		
		self.debugEventSubject.send(.break)
	}
	
	private func executeNextCPUInstruction() {
		let cycles = self.cpu.nextInstructionDuration
		self.tia.advanceClock(cycles: cycles * 3)
		self.riot.advanceClock(cycles: cycles)
		self.cpu.executeNextInstruction()
	}
}


// MARK: -
extension Atari2600: Bus {
	public func unmirror(_ address: Address) -> Address {
		if (0x0040..<0x0080).contains(address) {
			return address - 0x40
		}
		if (0x5000..<0x6000).contains(address) {
			return address + 0xa000
		}
		return address
	}
	
	public func read(at address: Address) -> Int {
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
	
	public func write(_ data: Int, at address: Address) {
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


// MARK: -
extension Atari2600: Screen {
	public var height: Int {
		return 262
	}
	
	public var width: Int {
		return 228
	}
	
	private var scanLine: Int {
		return self.frameClock / self.width
	}
	
	public func sync() {
		self.eventSubject.send(.frame)
		self.frameClock = 0
	}
	
	public func write(color: Int) {
		if self.frameClock < self.frame.count {
			self.frame[self.frameClock] = UInt8(color) >> 1
		}
		self.frameClock += 1
	}
}
