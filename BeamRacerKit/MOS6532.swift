//
//  MOS6532.swift
//  BeamRacerKit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Foundation

public class MOS6532 {
	internal(set) public var memory: Data
	
	private(set) public var remainingTimerCycles: Int
	private(set) public var intervalIncrement: Int
	private(set) public var isTimerOn: Bool
	
	public init() {
		self.memory = Data(randomOfCount: 128)
		
		self.remainingTimerCycles = .randomWord
		self.intervalIncrement = .random(of: [1, 8, 64, 1024])
		self.isTimerOn = false
	}
	
	// Resets internal state.
	func reset() {
		self.isTimerOn = false
	}
	
	/// Advances clock 1 cycle.
	func advanceClock(cycles: Int = 1) {
		// count timer cycles only when interval timer is on
		if self.isTimerOn {
			self.remainingTimerCycles -= cycles
			
			// stop timer when it reaches limit
			if self.remainingTimerCycles < -255 {
				self.remainingTimerCycles = .randomWord
				self.isTimerOn = false
			}
		}
	}
}


// MARK: -
// MARK: Bus integration
extension MOS6532: Bus {
	public func read(at address: Address) -> Int {
		switch address % 0x08 {
		case 0x02:
			return 0x3f
		case 0x04:
			return  self.remainingTimerCycles < 0
			? self.remainingTimerCycles
			: self.remainingTimerCycles / self.intervalIncrement
			
		default:
			return 0x00
		}
	}
	
	public func write(_ data: Int, at address: Address) {
		switch address {
		case 0x14:
			self.remainingTimerCycles = data
			self.intervalIncrement = 1
			self.isTimerOn = true
			
		case 0x15:
			self.remainingTimerCycles = data * 8
			self.intervalIncrement = 8
			self.isTimerOn = true
			
		case 0x16:
			self.remainingTimerCycles = data * 64
			self.intervalIncrement = 64
			self.isTimerOn = true
			
		case 0x17:
			self.remainingTimerCycles = data * 1024
			self.intervalIncrement = 1024
			self.isTimerOn = true
			
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
