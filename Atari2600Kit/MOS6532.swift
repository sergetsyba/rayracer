//
//  MOS6532.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 1.7.2023.
//

import Combine

public class MOS6532 {
	private var eventSubject = PassthroughSubject<Event, Never>()
	
	private(set) public var memory: Data
	
	var timer: Int = 0
	private var divider: Int = 0
	
	private var cycle = 0
	
	init() {
		self.memory = Data(randomOfCount: 0x80)
	}
	
	/// Advances clock 1 cycle.
	func step() {
		self.cycle += 1
		
		if self.divider > 0 {
			if self.cycle % self.divider == 0 {
				self.timer -= 1
			}
		}
	}
}

extension MOS6532 {
	func setTimer(_ time: Int, divider: Int) {
		self.timer = time
		self.divider = divider
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
extension MOS6532 {
	func readMemory(at address: Address) -> Int {
		self.eventSubject.send(.readMemory(address))
		return Int(self.memory[address])
	}
	
	func writeMemory(_ data: Int, at address: Address) {
		self.memory[address] = UInt8(data)
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
