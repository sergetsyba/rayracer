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
	
	init(size: Int) {
		self.data = Data(count: size)
		for index in 0..<data.count {
			self.data[index] = .random(in: 0x00..<0xff)
		}
	}
}


// MARK: -
// MARK: Access
public extension Memory {
	subscript (address: Int) -> Int {
		get {
			let event: Event = .read(address)
			self.eventSubject.send(event)
			
			let data = self.data[address]
			return Int(data)
		}
		set {
			self.data[address] = UInt8(newValue)
			
			let event: Event = .write(address)
			self.eventSubject.send(event)
		}
	}
	
	subscript (range: Range<Int>) -> Memory {
		let data = self.data[range]
		
		// TODO: send read event
		return Memory(data: data)
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
