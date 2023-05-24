//
//  CPU.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public struct MOS6507 {
	public typealias Word = UInt8
	public typealias Address = UInt16
	
	private(set) public var accumulator: Word
	private(set) public var X: Word
	private(set) public var Y: Word
	private(set) public var status: Status
	
	private(set) public var stackPointer: Word
	private(set) public var programCounter: Address
	
	var bus: MOS6502Bus!
	
	public init() {
		self.accumulator = 0x00
		self.X = 0x00
		self.Y = 0x00
		self.status = []
		
		self.stackPointer = 0x00
		self.programCounter = 0x0000
	}
}

protocol MOS6502Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word
}

public extension MOS6507 {
	mutating func reset() {
		self.programCounter = Address(
			self.bus.read(at: 0xfffc),
			self.bus.read(at: 0xfffd))
	}
}

public extension MOS6507 {
	struct Status: OptionSet {
		public var rawValue: UInt8
		
		public init(rawValue: UInt8) {
			self.rawValue = rawValue
		}
		
		static let carry = Status(rawValue: 1 << 0)
		static let zero = Status(rawValue: 1 << 1)
		static let interrupt = Status(rawValue: 1 << 2)
		static let decimal = Status(rawValue: 1 << 3)
		static let `break` = Status(rawValue: 1 << 4)
		static let overflow = Status(rawValue: 1 << 6)
		static let negative = Status(rawValue: 1 << 7)
	}
}

private extension MOS6507.Address {
	init(_ low: MOS6507.Word, _ high: MOS6507.Word) {
		self = Self(low) | Self(high) << 8
	}
}
