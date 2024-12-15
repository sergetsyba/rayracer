//
//  MOS6532.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Foundation

public class MOS6532 {
	public var peripherals: (a: Peripheral, b: Peripheral)
	
	internal(set) public var memory: Data
	internal(set) public var data: (a: Int, b: Int)
	internal(set) public var dataDirection: (a: Int, b: Int)
	internal(set) public var timer: (Int, interval: Int)
	
	public init() {
		self.peripherals = (.none, .none)
		
		self.memory = .random(count: 128)
		self.data = (.random(), .random())
		self.dataDirection = (0x00, 0x00)
		self.timer = (1024 * .random(), 1024)
	}
	
	/// Resets internal state.
	public func reset() {
		self.memory = .random(count: 128)
		self.data = (.random(), .random())
		
		// both ports are set as input on reset
		self.dataDirection = (0x00, 0x00)
		self.timer = (1024 * .random(), 1024)
	}
	
	/// Advances clock by the speciied number of cycles.
	public func advanceClock() {
		if self.timer.0 > -0xff {
			self.timer.0 -= 1
		}
	}
}


// MARK: -
// MARK: Bus integration
extension MOS6532 {
	/// Reads data at the specified address in this chip.
	public func read(at address: Int) -> Int {
		switch address % 0x08 {
			// MARK: Data A
		case 0x00, 0x08, 0x10, 0x18:
			// read data from peripheral for input pins
			var input = self.peripherals.a.read()
			input &= ~self.dataDirection.a
			
			// read data from data register for output pins
			let output = self.data.a & self.dataDirection.a
			return input | output
			
			// MARK: Data direction A
		case 0x01, 0x09, 0x11, 0x19:
			return self.dataDirection.a
			
			// MARK: Data B
		case 0x02:
			// read data from peripheral for input pins
			var input = self.peripherals.b.read()
			input &= ~self.dataDirection.b
			
			// read data from data register for output pins
			let output = self.data.b & self.dataDirection.b
			return input | output
			
			// MARK: Data direction B
		case 0x03, 0x0b, 0x13, 0x1b:
			return self.dataDirection.b
			
		case 0x04:
			// MARK: Timer
			return self.timer.0 < 0
			? Int(signed: 0xff - self.timer.0)
			: self.timer.0 / self.timer.interval
			
		default:
			return 0x00
		}
	}
	
	/// Writes the specified data at the specified address in this chip.
	public func write(_ data: Int, at address: Int) {
		switch address {
			// MARK: Data A
		case 0x00, 0x08, 0x10, 0x18:
			self.data.a = data
			self.peripherals.a.write(self.data.a, mask: self.dataDirection.a)
			
			// MARK: Data direction A
		case 0x01, 0x09, 0x11, 0x19:
			self.dataDirection.a = data
			self.peripherals.a.write(self.data.a, mask: self.dataDirection.a)
			
			// MARK: Data B
		case 0x02, 0x0a, 0x12, 0x1a:
			self.data.b = data
			self.peripherals.a.write(self.data.b, mask: self.dataDirection.b)
			
			// MARK: Data direction B
		case 0x03, 0xb, 0x13, 0x1b:
			self.dataDirection.b = data
			self.peripherals.b.write(self.data.b, mask: self.dataDirection.b)
			
		case 0x14:
			// MARK: Timer x1
			self.timer = (data, 1)
		case 0x15:
			// MARK: Timer x8
			self.timer = (8 * data, 8)
		case 0x16:
			// MARK: Timer x64
			self.timer = (64 * data, 64)
		case 0x17:
			// MARK: Timer x1024
			self.timer = (1024 * data, 1024)
			
		default:
			break
		}
	}
}


// MARK: -
// MARK: Peripheral
extension MOS6532 {
	public protocol Peripheral {
		func read() -> Int
		mutating func write(_ data: Int, mask: Int)
	}
}

extension MOS6532.Peripheral where Self == NoPeripheral {
	static var none: Self {
		return NoPeripheral()
	}
}

private struct NoPeripheral: MOS6532.Peripheral {
	func read() -> Int {
		return .random(in: 0x00...0xff)
	}
	
	mutating func write(_ data: Int, mask: Int) {
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Int {
	static func random() -> Self {
		return .random(in: 0x00...0xff)
	}
	
	static func random(of values: [Int]) -> Self {
		let index: Int = .random(in: 0..<values.count)
		return values[index]
	}
}

extension Data {
	static func random(count: Int) -> Self {
		var data = Data(count: 128)
		for index in data.indices {
			data[index] = .random(in: 0x00...0xff)
		}
		
		return data
	}
}
