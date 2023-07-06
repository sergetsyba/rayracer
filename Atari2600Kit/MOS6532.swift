//
//  MOS6532.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Combine

public class MOS6532 {
	private var eventSubject = PassthroughSubject<Event, Never>()
	
	internal(set) public var memory: Data
	
	private var intervalTimer: Int = .randomWord
	private var intervalIncrement: Int = -1
	private var cycles: Int = .randomWord
	
	public init() {
		self.memory = Data(randomOfCount: 128)
	}
	
	/// Advances clock 1 cycle.
	func advanceClock(cycles: Int = 1) {
		// count cycles only when interval timer has started
		guard self.intervalIncrement > 0 else {
			return
		}
		
		if self.intervalTimer > 0 {
			let elapsesCycles = self.cycles + cycles
			let remainingCycles = self.intervalTimer * self.intervalIncrement
			
			if elapsesCycles > remainingCycles {
				// when timer reaches 0 during clock advancement, adjust timer
				// to decrement by 1 on each subsequent cycle
				self.intervalTimer = remainingCycles - elapsesCycles
				self.intervalIncrement = 1
				self.cycles = 0
			} else {
				// when timer has not reached 0, decrement by 1 on each interval
				self.intervalTimer -= elapsesCycles / self.intervalIncrement
				self.cycles %= self.intervalIncrement
			}
		} else {
			// when timer has reached 0, decrement by 1 on each cycle
			self.intervalTimer -= cycles
		}
		
		if self.intervalTimer <= -255 {
			// when timer reaches -255, stop timer
			self.intervalTimer = -255
			self.intervalIncrement = -1
		}
	}
}


// MARK: -
// MARK: Event management
public extension MOS6532 {
	enum Event {
		case readMemory(Address)
		case writeMemoty(Address)
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}


// MARK: -
// MARK: Bus integration
extension MOS6532: Bus {
	func read(at address: Address) -> Int {
		switch address {
		case 0x0c:
			return self.intervalTimer
		default:
			return 0x00
		}
	}
	
	func write(_ data: Int, at address: Address) {
		switch address {
		case 0x14:
			self.intervalTimer = data
			self.intervalIncrement = 1
			self.cycles = 0
			
		case 0x15:
			self.intervalTimer = data
			self.intervalIncrement = 8
			self.cycles = 7
			
		case 0x16:
			self.intervalTimer = data
			self.intervalIncrement = 64
			self.cycles = 63
			
		case 0x17:
			self.intervalTimer = data
			self.intervalIncrement = 1024
			self.cycles = 1023
			
		default:
			break
		}
		
		self.eventSubject.send(.writeMemoty(address))
	}
}


// MARK: -
// MARK: Convenience functionality
extension UInt8 {
	static var random: Self {
		return Self.random(in: 0...255)
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
