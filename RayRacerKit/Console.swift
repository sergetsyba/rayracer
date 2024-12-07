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
	
	public var cartridge: Data? = nil
	public var controllers: (Controller, Controller) = (.none, .none)
	
	private var state: State = .suspended(0)
	private var debug: (condition: () -> Bool, callback: () -> Void)?
	
	public init(switches: Atari2600.Switches = [.color]) {
		self.cpu = MOS6507(bus: self)
		
		self.riot = MOS6532()
		self.riot.peripherals.a = self
		self.riot.peripherals.b = switches
		
		self.tia = TIA()
		self.tia.peripheral = self
	}
	
	public var switches: Switches {
		get { return self.riot.peripherals.b as! Switches }
		set { self.riot.peripherals.b = newValue }
	}
	
	public func isSuspended(withCode code: Int) -> Bool {
		if case .suspended(let currentCode) = self.state {
			return code == currentCode
		} else {
			return false
		}
	}
	
	///	Suspends emulation with the specified suspension code. When emulation is already suspended,
	///	updates suspension code only when it is higher than the current one.
	public func suspend(withCode code: Int = 0) {
		if case .suspended(let currentCode) = self.state,
		   currentCode > code {
			return
		}
		
		self.state = .suspended(code)
	}
	
	/// Resumes emulation when it has been suspended with a code lower than or equal to
	/// the specified one.
	public func resume(withCode code: Int = 0) {
		guard case .suspended(let currentCode) = self.state,
			  currentCode <= code else {
			return
		}
		
		self.state = .on
		if let (condition, callback) = self.debug {
			while case .on = self.state {
				self.advanceCycle()
				
				if condition() {
					self.state = .suspended(2)
					callback()
				}
			}
		} else {
			while case .on = self.state {
				self.advanceCycle()
			}
		}
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
	
	/// Resets internal state of all console components.
	public func reset() {
		self.cpu.reset()
		self.riot.reset()
		self.tia.reset()
	}
	
	private enum State {
		case off
		case on
		case suspended(Int)
	}
}


// MARK: -
// MARK: Debugging
extension Atari2600 {
	/// Resumes program for  the specified number of CPU instructions.
	public func resume(instructions: Int, completionHandler handler: @escaping () -> Void) {
		var remaining = instructions
		self.debug = ({ [unowned self] in
			if self.cpu.sync && !self.tia.awaitsHorizontalSync {
				remaining -= 1
			}
			return remaining == 0
		}, handler)
		
		self.resume(withCode: 2)
	}
	
	/// Resumes program for the specified number of TV scan lines.
	public func resume(scanLines: Int, completionHandler handler: @escaping () -> Void) {
		var remaining = scanLines
		var colorClock = self.tia.colorClock
		
		self.debug = ({ [unowned self] in
			if self.tia.colorClock < colorClock {
				remaining -= 1
			}
			
			colorClock = self.tia.colorClock
			return self.cpu.sync && remaining == 0
		}, handler)
		
		self.resume(withCode: 2)
	}
	
	/// Resumes program for the specified number of TV fields.
	public func resume(fields: Int, completionHandler handler: @escaping () -> Void) {
		var remaining = fields
		var scanLine = self.tia.scanLine
		
		self.debug = ({ [unowned self] in
			if self.tia.scanLine < scanLine {
				remaining -= 1
			}
			
			scanLine = self.tia.scanLine
			return self.cpu.sync && remaining == 0
		}, handler)
		
		self.resume(withCode: 2)
	}
	
	/// Resumes program until an instruction at any of the specified program addresses.
	public func resume(breakpoints: any Sequence<Int>, completionHandler handler: @escaping () -> Void) {
		self.debug = ({ [unowned self] in
			return self.cpu.sync
			&& breakpoints.contains(self.cpu.programCounter)
		}, handler)
		
		self.resume(withCode: 2)
	}
}


// MARK: -
// MARK: Bus routing
extension Atari2600: Addressable {
	public func read(at address: Int) -> Int {
		if address & 0xf000 == 0xf000 {
			let data = self.cartridge?[address & 0x0fff] ?? 0xea
			return Int(data)
		} else if address & 0x280 == 0x280 {
			return self.riot.read(at: address & 0x1f)
		} else if address & 0x80 == 0x80 {
			let data = self.riot.memory[address & 0x7f]
			return Int(data)
		} else {
			return self.tia.read(at: address & 0x3f)
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		if address & 0xf000 == 0xf000 {
			print(format: "Ignoring write at ROM address $%04x.", address)
		} else if address & 0x280 == 0x280 {
			self.riot.write(data, at: address & 0x1f)
		} else if address & 0x80 == 0x80 {
			self.riot.memory[address & 0x7f] = UInt8(data)
		} else {
			self.tia.write(data, at: address & 0x3f)
		}
	}
}


// MARK: -
// MARK: Convenience functionality
func print(format: String, _ arguments: any CVarArg...) {
	let message = String(format: format, arguments)
	print(message)
}
