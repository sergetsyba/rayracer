//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

import Combine

protocol CPU {
	var ready: Bool { get set }
}

public class TIA {
	private let eventSubject = PassthroughSubject<Event, Never>()
	
	private var cpu: CPU
	private var cycles = 0
	
	init(cpu: CPU) {
		self.cpu = cpu
	}
	
	var wsync: Bool = false
	
	/// Reset sync strobe register.
	/// Writing any value resets color clock to its value at the beginning of the current scanline.
	var rsync: Bool {
		get { return false }
		set { self.cycles -= self.cycles % 228 }
	}
	
	public var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
	
	func advanceClock(cycles: Int) {
		self.cycles += cycles
	}
}

// MARK: -
// MARK: Bus integration
extension TIA {
	func write(_ data: Int, at address: Int) {
		switch address {
		case 0x02:
			// wsync
			self.cpu.ready = false
			
			
		default:
			break
		}
	}
}

// MARK: -
// MARK: Debugging
extension TIA {
	func step(colorCycles cycles: Int) {
		self.cycles += cycles
		print("color clock: \(self.cycles % 228)")
	}
	
	func stepLine() -> Int {
		print("color clock: \(self.cycles % 228)")
		
		let cycles = 228 - self.cycles % 228
		self.cycles += cycles
		
		
		print("remains: \(cycles)")
		
		self.wsync = false
		return cycles
	}
}

extension Int {
	static let frameSize = 262 * 228
}

extension TIA {
	public enum Event {
		case drawFrame(Data)
	}
}
