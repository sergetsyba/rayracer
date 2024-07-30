//
//  MOS6532.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Foundation

public class MOS6532 {
	internal(set) public var memory: Data
	
	private(set) public var portA: any Port
	private(set) public var portADirection: Bool
	private(set) public var portB: any Port
	private(set) public var portBDirection: Bool
	
	private(set) public var timerClock: Int
	private(set) public var timerInterval: Int
	
	public init(ports: (any Port, any Port)) {
		self.memory = Data(randomOfCount: 128)
		
		self.portA = ports.0
		self.portADirection = .random()
		self.portB = ports.1
		self.portBDirection = .random()
		
		self.timerClock = .random(in: 0x00...0xff)
		self.timerInterval = .random(of: [1, 8, 64, 1024])
	}
	
	// Resets internal state.
	func reset() {
		// TODO: reset MOS6532
	}
	
	/// Advances clock 1 cycle.
	func advanceClock(cycles: Int) {
		// stop timer when it reaches limit
		self.timerClock = max(-255, self.timerClock - cycles)
	}
}


// MARK: -
// MARK: Bus integration
extension MOS6532: Addressable {
	public func read(at address: Int) -> Int {
		switch address % 0x08 {
		case 0x00:
			// MARK: SWCHA
			return self.portA.read()
		case 0x02:
			// MARK: SWCHB
			return self.portB.read()
		case 0x04:
			// MARK: INTIM
			return  self.timerClock < 0
			? Int(signed: self.timerClock, bits: 8)
			: self.timerClock / self.timerInterval
			
		default:
			return 0x00
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		switch address {
		case 0x00:
			// MARK: SWCHA
			self.portA.write(data)
		case 0x01:
			// MARK: SWACNT
			self.portADirection = data == 0x1
		case 0x02:
			// MARK: SWCHB
			self.portB.write(data)
		case 0x03:
			// MARK: SWBCNT
			self.portBDirection = data == 0x1
		case 0x14:
			// MARK: TIM1T
			self.timerInterval = 1
			self.timerClock = data
		case 0x15:
			// MARK: TIM8T
			self.timerInterval = 8
			self.timerClock = self.timerInterval * data
		case 0x16:
			// MARK: TIM64T
			self.timerInterval = 64
			self.timerClock = self.timerInterval * data
		case 0x17:
			// MARK: T1024T
			self.timerInterval = 1024
			self.timerClock = self.timerInterval * data
			
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

public protocol Port {
	func read() -> Int
	mutating func write(_ data: Int)
}
