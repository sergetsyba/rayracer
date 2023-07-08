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
	
	@Published private(set)
	public var remainingCycles: Int = .randomWord
	
	private(set)
	public var intervalIncrement: Int = .random(of: [1, 8, 64, 1024])
	
	public init() {
		self.memory = Data(randomOfCount: 128)
	}
	
	/// Advances clock 1 cycle.
	func advanceClock(cycles: Int = 1) {
		// count timer cycles only when interval is on
		if self.remainingCycles > -255 {
			self.remainingCycles -= cycles
			
			// stop timer when it reaches limit
			if self.remainingCycles < -255 {
				self.remainingCycles = -255
			}
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
			return  self.remainingCycles < 0
			? self.remainingCycles
			: self.remainingCycles / self.intervalIncrement
			
		default:
			return 0x00
		}
	}
	
	func write(_ data: Int, at address: Address) {
		switch address {
		case 0x14:
			self.remainingCycles = data
			self.intervalIncrement = 1
			
		case 0x15:
			self.remainingCycles = data * 8
			self.intervalIncrement = 8
			
		case 0x16:
			self.remainingCycles = data * 64
			self.intervalIncrement = 64
			
		case 0x17:
			self.remainingCycles = data * 1024
			self.intervalIncrement = 1024
			
		default:
			break
		}
		
		self.eventSubject.send(.writeMemoty(address))
	}
}


// MARK: -
// MARK: Convenience functionality
private extension UInt8 {
	static var random: Self {
		return Self.random(in: 0...255)
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
