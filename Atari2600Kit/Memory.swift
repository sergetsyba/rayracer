//
//  Memory.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Combine

public class Memory {
	private let eventSubject = PassthroughSubject<Event, Never>()
	private var data: Data
	
	private init(data: Data) {
		self.data = data
	}
	
	init() {
		self.data = Data(count: 0xffff)
		for index in 0..<data.count {
			self.data[index] = .random(in: 0x00..<0xff)
		}
	}
}


// MARK: -
// MARK: Memory segments
public extension Memory {
	subscript (address: Int) -> Int {
		get {
			defer {
				let event: Event = .read(address)
				self.eventSubject.send(event)
			}
			
			let data = self.data[address]
			return Int(data)
		}
		set {
			defer {
				let event: Event = .write(address)
				self.eventSubject.send(event)
			}
			
			self.data[address] = UInt8(newValue)
		}
	}
	
	subscript (range: Range<Int>) -> Memory {
		let data = self.data[range]
		return Memory(data: data)
	}
	
	var tiaRegisters: Memory {
		return self[0x0000..<0x007f]
	}
	
	var ram: Memory {
		return self[0x0080..<0x00ff]
	}
	
	var riotRegisters: Memory {
		return self[0xf000..<0xffff]
	}
	
	func stride(by count: Int) -> any Sequence<Data> {
		return Swift.stride(from: self.data.startIndex, through: self.data.endIndex, by: count)
			.map() {
				let endIndex = min($0 + count, self.data.endIndex)
				return self.data[$0..<endIndex]
			}
	}
}


// MARK: -
// MARK: Events
public extension Memory {
	enum Event {
		case read(Int)
		case write(Int)
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}
