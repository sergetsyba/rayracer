//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

import Combine

public class TIA {
	private let eventSubject = PassthroughSubject<Event, Never>()
	
	let bus: Bus
	var colorCycle = 0
	
	init(bus: Bus) {
		self.bus = bus
	}
	
	public var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
	
	func step(cycles: Int) {
		for _ in 0..<cycles {
			self.colorCycle += 1
			
			if self.colorCycle % (.frameSize) == 0 {
				var frame = Data(count: .frameSize)
				for index in 0..<frame.count {
					frame[index] = .random(in: 0...255)
				}
				
				self.eventSubject.send(.drawFrame(frame))
			}
		}
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


// MARK: -
// MARK: Registers
private extension TIA {
	var vsync: Bool {
		let data = self.bus.read(at: 0x00)
		return data[1]
	}
}
