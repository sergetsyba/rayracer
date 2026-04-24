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
	
	private var suspension: (() -> Bool, () -> Void, SuspensionPriority)?
	private var state: State = .suspended(.normal)
	
	init() {
		self.console = racer_atari2600_create()!
		self.controllers
			.0 = Joystick(console: self.console)
	}
	
	var cartridge: Cartridge? {
		didSet {
			guard let cartridge else {
				self.console.pointee.cartridge = nil
				return
			}
			
			cartridge.data.withUnsafeBytes() {
				let data = $0.bindMemory(to: UInt8.self)
				racer_atari2600_insert_cartridge(self.console, cartridge.kind, data.baseAddress)
			}
		}
	}
	
	func reset() {
		racer_atari2600_reset(self.console)
		NotificationCenter.default
			.post(name: .reset, object: self)
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
		// note: it seems impossible to combine first two cases into one
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
typealias CartridgeKind = racer_cartridge_type

extension CartridgeKind: @retroactive SetAlgebra {}
extension CartridgeKind: @retroactive ExpressibleByArrayLiteral {}
extension CartridgeKind: @retroactive OptionSet {
	static let atari2KB = CARTRIDGE_ATARI_2KB
	static let atari4KB = CARTRIDGE_ATARI_4KB
	static let atari8KB = CARTRIDGE_ATARI_8KB
	static let atari12KB = CARTRIDGE_ATARI_12KB
	static let atari16KB = CARTRIDGE_ATARI_16KB
	static let atari32KB = CARTRIDGE_ATARI_32KB
}

extension CartridgeKind {
	init?(data: Data) {
		switch data.count {
		case 0x1000/2: self = .atari2KB
		case 0x1000: self = .atari4KB
		case 0x1000*2: self = .atari8KB
		case 0x1000*3: self = .atari12KB
		case 0x1000*4: self = .atari16KB
		case 0x1000*8: self = .atari32KB
		default: return nil
		}
	}
}

struct Cartridge {
	var name: String
	var kind: CartridgeKind
	var data: Data
	var ref: UnsafeMutableRawPointer!
	
	init?(at url: URL) {
		guard let data = try? Data(contentsOf: url),
			  let kind = CartridgeKind(data: data) else {
			return nil
		}
		
		self.name = url.deletingPathExtension().lastPathComponent
		self.kind = kind
		self.data = data
	}
	
	var id: String {
		return Insecure.MD5
			.hash(data: self.data)
			.map() { String(format: "%02x", $0) }
			.joined()
	}
	
	var bankIndex: Int {
		switch self.kind {
		case .atari8KB,
				.atari12KB,
				.atari16KB,
				.atari32KB:
			let index = self.ref
				.assumingMemoryBound(to: racer_atari_multi_bank_cartridge.self)
				.pointee
				.bank_index
			
			return Int(index)
		default:
			return 0
		}
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
typealias VideoSync = racer_video_sync

extension VideoSync: @retroactive SetAlgebra {}
extension VideoSync: @retroactive ExpressibleByArrayLiteral {}
extension VideoSync: @retroactive OptionSet {
	static let horizontal = VIDEO_HORIZONTAL_SYNC
	static let vertical = VIDEO_VERTICAL_SYNC
	static let buffer = VIDEO_BUFFER_SYNC
}
