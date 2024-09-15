//
//  MOS6532.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Foundation

public class MOS6532 {
	internal(set) public var memory: Data
	private(set) public var ports: (a: (Port, direction: DataDirection), b: (Port, direction: DataDirection))
	private(set) public var timer: Timer
	
	public init(ports: (Port, Port)) {
		self.memory = Data(randomOfCount: 128)
		self.ports = ((ports.0, .read), (ports.1, .read))
		self.timer = .random()
	}
	
	/// Resets internal state.
	func reset() {
		self.memory = Data(randomOfCount: 128)
		self.timer = .random()
	}
	
	/// Advances clock by the speciied number of cycles.
	func advanceClock(cycles: Int = 1) {
		self.timer.advanceClock(cycles: cycles)
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
				interval: .random(of: [1, 8, 64, 1024]))
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
	
	public protocol Port {
		func read() -> Int
		mutating func write(_ data: Int)
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
		case 0x00:
			// MARK: SWCHA
			return self.ports.a.0.read()
		case 0x02:
			// MARK: SWCHB
			return self.ports.b.0.read()
		case 0x04:
			// MARK: INTIM
			return  self.timer.value
		default:
			return 0x00
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		switch address {
		case 0x00:
			// MARK: SWCHA
			self.ports.a.0.write(data)
		case 0x01:
			// MARK: SWACNT
			self.ports.a.direction = data == 0x1 ? .write : .read
		case 0x02:
			// MARK: SWCHB
			self.ports.b.0.write(data)
		case 0x03:
			// MARK: SWBCNT
			self.ports.b.direction = data == 0x1 ? .write : .read
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
