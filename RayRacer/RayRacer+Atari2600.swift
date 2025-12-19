//
//  RayRacer+Atari2600.swift
//  RayRacer
//
//  Created by Serge Tsyba on 15.12.2025.
//

import Foundation
import CryptoKit
import librayracer

class Atari2600 {
	let console: UnsafeMutablePointer<racer_atari2600>!
	var controllers: (Joystick?, Joystick?)
	var output: VideoOutput?
	
	private var suspension: (() -> Bool, () -> Void, SuspensionPriority)?
	private var state: State = .suspended(.normal)
	
	init() {
		self.console = racer_atari2600_create()!
		racer_init()
		
		self.console.pointee
			.tia.pointee
			.output = Unmanaged.passUnretained(self)
			.toOpaque()
		self.console.pointee
			.tia.pointee
			.sync_video_output = syncVideoOutput(output:sync:)
		self.console.pointee
			.tia.pointee
			.write_video_output = writeVideoOutput(output:signal:)
		
		self.controllers
			.0 = Joystick(console: self.console)
	}
	
	func reset() {
		racer_atari2600_reset(self.console)
	}
}


// MARK: -
// MARK: Suspend/resume functionality
extension Atari2600 {
	enum SuspensionPriority: Comparable {
		case normal
		case high
	}
	
	private enum State {
		case resumed
		case suspended(SuspensionPriority)
	}
	
	/// Returns `true` when emulation is suspended with the specified priority; returns `false`
	/// otherwise.
	func isSuspended(withPriority priority: SuspensionPriority = .normal) -> Bool {
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
	func suspend(priority: SuspensionPriority = .normal) {
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
	func resume(priority: SuspensionPriority = .normal, until suspension: (condition: () -> Bool, callback: () -> Void)? = nil) {
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
				racer_atari2600_advance_clock(self.console)
				
				if condition() {
					self.state = .suspended(priority)
					self.suspension = nil
					callback()
				}
			}
		} else {
			while case .resumed = self.state {
				racer_atari2600_advance_clock(self.console)
			}
		}
	}
}


// MARK: -
// MARK: Cartridges
extension Atari2600 {
	var program: Data? {
		get {
			guard let program = self.console.pointee.program else {
				return nil
			}
			
			return Data(bytesNoCopy: program, count: 4096, deallocator: .none)
		}
		set {
			newValue?.withUnsafeBytes() {
				self.console.pointee.program = malloc($0.count)
					.assumingMemoryBound(to: CUnsignedChar.self)
				
				memcpy(self.console.pointee.program, $0.baseAddress, $0.count)
			}
		}
	}
	
	var programId: String? {
		guard let program = self.program else {
			return nil
		}
		
		return Insecure.MD5
			.hash(data: program)
			.map() { String(format: "%02x", $0) }
			.joined()
	}
}


// MARK: -
// MARK: Console switches
typealias Switches = racer_atari2600_switch

extension Switches: @retroactive SetAlgebra {}
extension Switches: @retroactive ExpressibleByArrayLiteral {}
extension Switches: @retroactive OptionSet {
	static let reset = ATARI2600_SWITCH_RESET
	static let select = ATARI2600_SWITCH_SELECT
	static let color = ATARI2600_SWITCH_COLOR
	static let difficulty0 = ATARI2600_SWITCH_DIFFICULTY_0
	static let difficulty1 = ATARI2600_SWITCH_DIFFICULTY_1
}

extension Atari2600 {
	var switches: Switches {
		get { Switches(rawValue: UInt32(self.console.pointee.switches.1)) }
		set { self.console.pointee.switches.1 = UInt8(newValue.rawValue) }
	}
}


// MARK: -
// MARK: Controllerss
class Joystick {
	typealias Buttons = racer_joystick_button
	
	private let console: UnsafeMutablePointer<racer_atari2600>!
	private var pressedButtons: Buttons = [] {
		didSet {
			let buttons = UInt8(self.pressedButtons.rawValue)
			racer_joysticks_write_output(self.console, [buttons, 0])
		}
	}
	
	init(console: UnsafeMutablePointer<racer_atari2600>!) {
		self.console = console
	}
	
	func press(_ buttons: Buttons) {
		self.pressedButtons.insert(buttons)
	}
	
	func release(_ buttons: Buttons) {
		self.pressedButtons.remove(buttons)
	}
}

extension Joystick.Buttons: @retroactive SetAlgebra {}
extension Joystick.Buttons: @retroactive ExpressibleByArrayLiteral {}
extension Joystick.Buttons: @retroactive OptionSet {
	static let up = JOYSTICK_BUTTON_UP
	static let down = JOYSTICK_BUTTON_DOWN
	static let left = JOYSTICK_BUTTON_LEFT
	static let right = JOYSTICK_BUTTON_RIGHT
	static let fire = JOYSTICK_BUTTON_FIRE
}

// MARK: -
// MARK: Output
protocol VideoOutput {
	/// Signals the start of a new field or scan line.
	mutating func sync(_ sync: VideoSync)
	/// Signals the absence of color for the next value.
	mutating func blank()
	/// Signals the next color value.
	mutating func write(color: Int)
}

typealias VideoSync = racer_tia_output_sync

extension VideoSync: @retroactive SetAlgebra {}
extension VideoSync: @retroactive ExpressibleByArrayLiteral {}
extension VideoSync: @retroactive OptionSet {
	static let horizontal = TIA_OUTPUT_HORIZONTAL_SYNC
	static let vertical = TIA_OUTPUT_VERTICAL_SYNC
}

func syncVideoOutput(output: UnsafeRawPointer?, sync: VideoSync) {
	guard let output = output else {
		return
	}
	
	let console = Unmanaged<Atari2600>
		.fromOpaque(output)
		.takeUnretainedValue()
	
	console.output?
		.sync(sync)
}

func writeVideoOutput(output: UnsafeRawPointer?, signal: UInt16) {
	guard let output = output else {
		return
	}
	
	let console = Unmanaged<Atari2600>
		.fromOpaque(output)
		.takeUnretainedValue()
	
	let color = Int(signal & 0xff)
	console.output?
		.write(color: color);
}
