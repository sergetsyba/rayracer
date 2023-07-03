//
//  MOS6532.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 1.7.2023.
//

class MOS6532 {
	private(set) public var ram: Data
	
	var timer: Int = 0
	private var divider: Int = 0
	
	private var cycle = 0
	
	init() {
		self.ram = Data(randomOfCount: 0x100)
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
// MARK: Bus integration
extension MOS6532 {
	func readMemory(at address: Int) -> Int {
		return address
	}
	
	func writeMemory(_ data: Int, at address: Int) {
		
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
