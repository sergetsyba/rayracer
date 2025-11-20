//
//  Console.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Foundation

@_implementationOnly
import librayracer

public class Atari2600 {
	private(set) public var cpu: MOS6507!
	private(set) public var riot: MOS6532!
	private(set) public var tia: TIA!
	
	private var tia0 = rr_tia_init()!;
	private var output: Int32 = 0 {
		didSet {
			let sync = (~(oldValue >> 8) & (self.output >> 8)) & 0x3
			if sync > 0 {
				self.tia.output?
					.sync(TIA.GraphicsSync(rawValue: Int(sync)))
			}
			
			let color = self.output & 0x7f
			self.tia.output?
				.write(color: Int(color))
		}
	}
	
	public var cartridge: Data? = nil
	public var controllers: (Controller, Controller) = (.none, .none)
	
	private var state: State = .suspended(.normal)
	private var suspension: (() -> Bool, () -> Void, SuspensionPriority)?
	
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
	
	/// Resets internal state of all console components.
	public func reset() {
		self.cpu.reset()
		self.riot.reset()
		self.tia.reset()
	}
}

// MARK: - Suspend/resume functionality
extension Atari2600 {
	public enum SuspensionPriority: Comparable {
		case normal
		case high
	}
	
	private enum State {
		case resumed
		case suspended(SuspensionPriority)
	}
	
	/// Returns `true` when emulation is suspended with the specified priority; returns `false`
	/// otherwise.
	public func isSuspended(withPriority priority: SuspensionPriority = .normal) -> Bool {
		if case .suspended(let currentPriority) = self.state {
			return priority == currentPriority
		} else {
			return false
		}
	}
	
	///	Suspends emulation.
	///
	///	When emualtion is already suspended with a lower priority than the specified one, updates
	///	suspension priority to the specified one.
	public func suspend(priority: SuspensionPriority = .normal) {
		// note: it seems impossible to combine first to cases into one
		// due to value binding on .suspended case
		switch self.state {
		case .resumed:
			self.state = .suspended(priority)
		case .suspended(let currentPriority) where currentPriority < priority:
			self.state = .suspended(priority)
		default:
			return
		}
	}
	
	/// Resumes emulation when it is suspended with a priority lower or equal to the specified one.
	// TODO: explain suspension context
	public func resume(priority: SuspensionPriority = .normal, until suspension: (condition: () -> Bool, callback: () -> Void)? = nil) {
		// do not resume emulation when current suspension priority is higher
		guard case .suspended(let currentPriority) = self.state,
			  currentPriority <= priority else {
			return
		}
		
		if let (condition, callback) = suspension {
			self.suspension = (condition, callback, priority)
		}
		
		self.state = .resumed
		if let (condition, callback, priority) = self.suspension {
			while case .resumed = self.state {
				self.advanceCycle()
				
				if condition() {
					self.state = .suspended(priority)
					self.suspension = nil
					callback()
				}
			}
		} else {
			while case .resumed = self.state {
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
		//		let cpuReady = !self.tia.awaitsHorizontalSync
		//
		//		self.tia.advanceClock()
		//		self.tia.advanceClock()
		//		self.tia.advanceClock()
		
		let cpuReady = self.tia0
			.pointee
			.awaits_horizontal_sync == false
		
		rr_tia_advance_clock(self.tia0)
		self.output = self.tia0.pointee.output
		rr_tia_advance_clock(self.tia0)
		self.output = self.tia0.pointee.output
		rr_tia_advance_clock(self.tia0)
		self.output = self.tia0.pointee.output
		
		self.riot.advanceClock()
		if cpuReady {
			self.cpu.advanceClock()
		}
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
			//			return self.tia.read(at: address & 0x3f)
			return Int(rr_tia_read(self.tia0.pointee, Int32(address & 0x3f)))
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		if address & 0xf000 == 0xf000 {
			// print(format: "Ignoring write at ROM address $%04x.", address)
		} else if address & 0x280 == 0x280 {
			self.riot.write(data, at: address & 0x1f)
		} else if address & 0x80 == 0x80 {
			self.riot.memory[address & 0x7f] = UInt8(data)
		} else {
			//			self.tia.write(data, at: address & 0x3f)
			rr_tia_write(self.tia0, Int32(address & 0x3f), Int32(data))
		}
	}
}


// MARK: -
// MARK: Convenience functionality
func print(format: String, _ arguments: any CVarArg...) {
	let message = String(format: format, arguments)
	print(message)
}
