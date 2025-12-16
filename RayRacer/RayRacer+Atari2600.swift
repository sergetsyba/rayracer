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
	private(set) var ref: UnsafeMutablePointer<racer_atari2600>!
	private var suspension: (() -> Bool, () -> Void, SuspensionPriority)?
	private var state: State = .suspended(.normal)
	
	var switches: Switches = []
	var controllers: (Controller, Controller) = (.none, .none)
	var output: VideoOutput?
	
	init() {
		self.ref = racer_atari2600_create()
		self.ref.pointee
			.tia.pointee
			.output = Unmanaged.passUnretained(self)
			.toOpaque()
		self.ref.pointee
			.tia.pointee
			.sync_video_output = syncVideoOutput(output:sync:)
		self.ref.pointee
			.tia.pointee
			.write_video_output = writeVideoOutput(output:signal:)
	}
	
	func reset() {
		racer_atari2600_reset(self.ref)
	}
}


// MARK: -
// MARK: Suspend/resume functionality
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
				racer_atari2600_advance_clock(self.ref)
				
				if condition() {
					self.state = .suspended(priority)
					self.suspension = nil
					callback()
				}
			}
		} else {
			while case .resumed = self.state {
				racer_atari2600_advance_clock(self.ref)
			}
		}
	}
}


// MARK: -
// MARK: Cartridges
extension Atari2600 {
	var program: Data? {
		get {
			guard let program = self.ref.pointee.program else {
				return nil
			}
			
			return Data(bytesNoCopy: program, count: 4096, deallocator: .none)
		}
		set {
			newValue?.withUnsafeBytes() {
				self.ref.pointee.program = malloc($0.count)
					.assumingMemoryBound(to: CUnsignedChar.self)
				
				memcpy(self.ref.pointee.program, $0.baseAddress, $0.count)
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
// MARK: Input
struct Switches: OptionSet {
	static let reset = Switches(rawValue: 1 << 0)
	static let select = Switches(rawValue: 1 << 1)
	static let color = Switches(rawValue: 1 << 3)
	static let difficulty0 = Switches(rawValue: 1 << 6)
	static let difficulty1 = Switches(rawValue: 1 << 7)
	
	var rawValue: Int
	init(rawValue: Int) {
		self.rawValue = rawValue | 0x34
	}
}

protocol Controller {
	var output: Int { get }
}

extension Controller where Self == NoController {
	static var none: Self {
		return NoController()
	}
}

private struct NoController: Controller {
	var output = 0
}

struct Joystick: Controller {
	private(set) var pressed: Buttons = []
	
	var output: Int {
		return self.pressed.rawValue
	}
	
	mutating func press(_ buttons: Buttons) {
		self.pressed.insert(buttons)
	}
	
	mutating func release(_ buttons: Buttons) {
		self.pressed.remove(buttons)
	}
	
	struct Buttons: OptionSet {
		static let up = Buttons(rawValue: 1 << 0)
		static let down = Buttons(rawValue: 1 << 1)
		static let left = Buttons(rawValue: 1 << 2)
		static let right = Buttons(rawValue: 1 << 3)
		static let fire = Buttons(rawValue: 1 << 5)
		
		var rawValue: Int
		init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
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

struct VideoSync: OptionSet {
	public static let vertical = VideoSync(rawValue: 1 << 0)
	public static let horizontal = VideoSync(rawValue: 1 << 1)
	
	public var rawValue: Int32
	public init(rawValue: Int32) {
		self.rawValue = rawValue
	}
}

func syncVideoOutput(output: UnsafeRawPointer?, sync: Int32) {
	guard let output = output else {
		return
	}
	
	let console = Unmanaged<Atari2600>
		.fromOpaque(output)
		.takeUnretainedValue()
	
	let sync = VideoSync(rawValue: sync)
	console.output?
		.sync(sync)
}

func writeVideoOutput(output: UnsafeRawPointer?, signal: Int32) {
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
