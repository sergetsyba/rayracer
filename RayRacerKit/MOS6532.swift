//
//  MOS6532.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Foundation

public class MOS6532 {
	var peripherals: (a: Peripheral, b: Peripheral)
	var data: (a: Int, b: Int) = (.random, .random)
	var dataDirection: (a: Int, b: Int) = (.random, .random)
	
	internal(set) public var memory: Data
	private(set) public var timer: Timer
	
	public init() {
		self.peripherals.a = NoPeripheral()
		self.peripherals.b = NoPeripheral()
		
		self.memory = Data(randomOfCount: 128)
		self.timer = .random()
	}
	
	/// Resets internal state.
	func reset() {
		// both ports are set as input on reset
		self.dataDirection = (0x0, 0x0)
		self.memory = Data(randomOfCount: 128)
		self.timer = .random()
	}
	
	/// Advances clock by the speciied number of cycles.
	func advanceClock(cycles: Int = 1) {
		self.timer.advanceClock(cycles: cycles)
	}
}

extension MOS6532 {
	public protocol Peripheral {
		func read() -> Int
		mutating func write(_ data: Int)
	}
}

private struct NoPeripheral: MOS6532.Peripheral {
	func read() -> Int {
		return .random(in: 0x00...0xff)
	}
	
	mutating func write(_ data: Int) {
	}
}

private extension Int {
	static var random: Self {
		return .random(in: 0x00...0xff)
	}
}


// MARK: -
extension MOS6532 {
	public struct Timer {
		private(set) public var clock: Int
		private(set) public var interval: Int
		
		public init(value: Int, interval: Int) {
			self.clock = value * interval
			self.interval = interval
		}
		
		public static func random() -> Self {
			return Timer(
				value: .random(in: 0x00...0xff),
				interval: 1024)
		}
		
		public var value: Int {
			return self.clock < 0
			? Int(signed: 0xff - self.clock, bits: 8)
			: self.clock / self.interval
		}
		
		public mutating func advanceClock(cycles: Int) {
			// stop timer when it reaches limit
			self.clock = max(-0xff, self.clock - cycles)
		}
	}
	
	public enum DataDirection {
		case read
		case write
	}
}


// MARK: -
// MARK: Bus integration
extension MOS6532: Addressable {
	public func read(at address: Int) -> Int {
		switch address % 0x08 {
			// MARK: Data A
		case 0x00, 0x08, 0x10, 0x18:
			// read data from peripheral for input pins
			// read data from data register for output pins
			let input = self.peripherals.a.read() & ~self.dataDirection.a
			let output = self.data.a & self.dataDirection.a
			return input | output
			
			// MARK: Data direction A
		case 0x01, 0x09, 0x11, 0x19:
			return self.dataDirection.a
			
			// MARK: Data B
		case 0x02:
			// read data from peripheral for input pins
			// read data from data register for output pins
			let input = self.peripherals.b.read() & ~self.dataDirection.b
			let output = self.data.b & self.dataDirection.b
			return input | output
			
			// MARK: Data direction B
		case 0x03, 0x0b, 0x13, 0x1b:
			return self.dataDirection.b
			
		case 0x04:
			// MARK: INTIM
			return  self.timer.value
		default:
			return 0x00
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		switch address {
			// MARK: Data A
		case 0x00, 0x08, 0x10, 0x18:
			self.data.a = data
			// write data to peripheral for output pins
			let output = data & self.dataDirection.a
			self.peripherals.a.write(output)
			
			// MARK: Data direction A
		case 0x01, 0x09, 0x11, 0x19:
			self.dataDirection.a = data
			// write data to peripheral for output pins
			let output = self.data.a & data
			self.peripherals.a.write(output)
			
			// MARK: Data B
		case 0x02, 0x0a, 0x12, 0x1a:
			self.data.b = data
			// write data to peripheral for output pins
			let output = data & self.dataDirection.b
			self.peripherals.b.write(output)
			
			// MARK: Data direction B
		case 0x03, 0xb, 0x13, 0x1b:
			self.dataDirection.b = data
			// write data to peripheral for output pins
			let output = self.data.b & data
			self.peripherals.b.write(output)
			
		case 0x14:
			// MARK: TIM1T
			self.timer = Timer(value: data, interval: 1)
		case 0x15:
			// MARK: TIM8T
			self.timer = Timer(value: data, interval: 8)
		case 0x16:
			// MARK: TIM64T
			self.timer = Timer(value: data, interval: 64)
		case 0x17:
			// MARK: T1024T
			self.timer = Timer(value: data, interval: 1-24)
			
		default:
			break
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension UInt8 {
	static var random: Self {
		return Self.random(in: 1...255)
	}
}

private extension Int {
	static func random(of values: [Int]) -> Int {
		let index: Int = .random(in: 0..<values.count)
		return values[index]
	}
}

extension Data {
	init(randomOfCount count: Int) {
		self.init(count: count)
		for index in self.indices {
			self[index] = .random
		}
	}
}
