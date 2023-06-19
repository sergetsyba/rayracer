//
//  CPU.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

import Combine

public  extension MOS6507 {
	enum Event {
		case reset
		case sync
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
	
	class Status {
		@Published fileprivate(set) public var carry: Bool
		@Published fileprivate(set) public var zero: Bool
		@Published fileprivate(set) public var interruptDisabled: Bool
		@Published fileprivate(set) public var decimalMode: Bool
		@Published fileprivate(set) public var `break`: Bool
		@Published fileprivate(set) public var overflow: Bool
		@Published fileprivate(set) public var negative: Bool
		
		required init() {
			self.carry = false
			self.zero = false
			self.interruptDisabled = false
			self.decimalMode = false
			self.break = false
			self.overflow = false
			self.negative = false
		}
		
		static var random: Self {
			// TODO: Status.random
			return .init()
		}
	}
}

public class MOS6507 {
	@Published private(set) public var accumulator: Word
	@Published private(set) public var x: Word
	@Published private(set) public var y: Word
	@Published private(set) public var status: Status
	
	@Published private(set) public var stackPointer: Word
	@Published private(set) public var programCounter: Address
	
	private let eventSubject = PassthroughSubject<Event, Never>()
	
	
	
	var bus: MOS6502Bus!
	
	public init() {
		self.accumulator = .randomWord
		self.x = .randomWord
		self.y = .randomWord
		self.status = .random
		
		self.stackPointer = .randomWord
		self.programCounter = .randomAddress
	}
	
	private lazy var operations2: [Mnemonic: (AddressingMode) -> Int] = {[
		.adc: { [unowned self] mode in
			self.perform(addressing: mode) { address in
				self.adc(mode)
			}
		},
		.and: { [unowned self] mode in
			self.perform(addressing: mode) { address in
				let operand = self.bus.read(at: address)
				let result = self.accumulator & operand
				
				self.accumulator = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
				
				return 1
			}
		}
	]}()
	
	private func perform(addressing: AddressingMode, operation: (Address) -> Int) -> Int {
		return 0
	}
	
	lazy var operations: [Int: () -> Int] = {
		[
			// ADC
			0x69: { [unowned self] in self.and(.immediate) },
			0x65: { [unowned self] in self.and(.zeroPage) },
			0x75: { [unowned self] in self.and(.zeroPageX) },
			0x6d: { [unowned self] in self.and(.absolute) },
			0x7d: { [unowned self] in self.and(.absoluteX) },
			0x79: { [unowned self] in self.and(.absoluteY) },
			0x61: { [unowned self] in self.and(.indirectX) },
			0x71: { [unowned self] in self.and(.indirectY) },
			// AND
			0x29: { [unowned self] in self.and(.immediate) },
			0x25: { [unowned self] in self.and(.zeroPage) },
			0x35: { [unowned self] in self.and(.zeroPageX) },
			0x2d: { [unowned self] in self.and(.absolute) },
			0x3d: { [unowned self] in self.and(.absoluteX) },
			0x39: { [unowned self] in self.and(.absoluteY) },
			0x21: { [unowned self] in self.and(.indirectX) },
			0x31: { [unowned self] in self.and(.indirectY) },
			// ASL
			0x0a: { [unowned self] in self.asl() },
			0x06: { [unowned self] in self.asl(.zeroPage) },
			0x16: { [unowned self] in self.asl(.zeroPageX) },
			0x0e: { [unowned self] in self.asl(.absolute) },
			0x1e: { [unowned self] in self.asl(.absoluteX) },
			// BEQ
			0xf0: { [unowned self] in self.beq() },
			// BIT
			0x24: { [unowned self] in self.bit(.zeroPage) },
			0x2C: { [unowned self] in self.bit(.absolute) },
			// BMI
			0x30: { [unowned self] in self.bmi() },
			// BNE
			0xd0: { [unowned self] in self.bne() },
			// BPL
			0x10: { [unowned self] in self.bpl() },
			// BVC
			0x50: { [unowned self] in self.bvc() },
			// BVS
			0x70: { [unowned self] in self.bvs() },
			// CLC
			0x18: { [unowned self] in self.clc() },
			// CLD
			0xd8: { [unowned self] in self.cld() },
			// CLI
			0x58: { [unowned self] in self.cli() },
			// CLV
			0xb8: { [unowned self] in self.clv() },
			// CMP
			0xc9: { [unowned self] in self.cmp(.immediate) },
			0xc5: { [unowned self] in self.cmp(.zeroPage) },
			0xd5: { [unowned self] in self.cmp(.zeroPageX) },
			0xcd: { [unowned self] in self.cmp(.absolute) },
			0xdd: { [unowned self] in self.cmp(.absoluteX) },
			0xd9: { [unowned self] in self.cmp(.absoluteY) },
			0xc1: { [unowned self] in self.cmp(.indirectX) },
			0xd1: { [unowned self] in self.cmp(.indirectY) },
			// CPX
			0xe0: { [unowned self] in self.cpx(.immediate) },
			0xe4: { [unowned self] in self.cpx(.zeroPage) },
			0xec: { [unowned self] in self.cpx(.absolute) },
			// CPY
			0xc0: { [unowned self] in self.cpy(.immediate) },
			0xc4: { [unowned self] in self.cpy(.zeroPage) },
			0xcc: { [unowned self] in self.cpy(.absolute) },
			// DEC
			0xc6: { [unowned self] in self.dec(.zeroPage) },
			0xd6: { [unowned self] in self.dec(.zeroPageX) },
			0xce: { [unowned self] in self.dec(.absolute) },
			0xde: { [unowned self] in self.dec(.absoluteX) },
			// DEX
			0xca: { [unowned self] in self.dex() },
			// DEY
			0x88: { [unowned self] in self.dey() },
			// EOR
			0x49: { [unowned self] in self.eor(.immediate) },
			0x45: { [unowned self] in self.eor(.zeroPage) },
			0x55: { [unowned self] in self.eor(.zeroPageX) },
			0x4d: { [unowned self] in self.eor(.absolute) },
			0x5d: { [unowned self] in self.eor(.absoluteX) },
			0x59: { [unowned self] in self.eor(.absoluteY) },
			0x41: { [unowned self] in self.eor(.indirectX) },
			0x51: { [unowned self] in self.eor(.indirectY) },
			// INC
			0xe6: { [unowned self] in self.inc(.zeroPage) },
			0xf6: { [unowned self] in self.inc(.zeroPageX) },
			0xee: { [unowned self] in self.inc(.absolute) },
			0xfe: { [unowned self] in self.inc(.absoluteX) },
			// INX
			0xe8: { [unowned self] in self.inx() },
			// INY
			0xc8: { [unowned self] in self.iny() },
			// JSR
			0x20: { [unowned self] in self.jsr(.absolute) },
			// LDA
			0xa9: { [unowned self] in self.lda(.immediate) },
			0xa5: { [unowned self] in self.lda(.zeroPage) },
			0xb5: { [unowned self] in self.lda(.zeroPageX) },
			0xad: { [unowned self] in self.lda(.absolute) },
			0xbd: { [unowned self] in self.lda(.absoluteX) },
			0xb9: { [unowned self] in self.lda(.absoluteY) },
			0xa1: { [unowned self] in self.lda(.indirectX) },
			0xb1: { [unowned self] in self.lda(.indirectY) },
			// LDX
			0xa2: { [unowned self] in self.ldx(.immediate) },
			0xa6: { [unowned self] in self.ldx(.zeroPage) },
			0xb6: { [unowned self] in self.ldx(.zeroPageY) },
			0xae: { [unowned self] in self.ldx(.absolute) },
			0xbe: { [unowned self] in self.ldx(.absoluteY) },
			// LDY
			0xa0: { [unowned self] in self.ldy(.immediate) },
			0xa4: { [unowned self] in self.ldy(.zeroPage) },
			0xb4: { [unowned self] in self.ldy(.zeroPageX) },
			0xac: { [unowned self] in self.ldy(.absolute) },
			0xbc: { [unowned self] in self.ldy(.absoluteX) },
			// LSR
			0x4a: { [unowned self] in self.lsr() },
			0x46: { [unowned self] in self.lsr(.zeroPage) },
			0x56: { [unowned self] in self.lsr(.zeroPageX) },
			0x4e: { [unowned self] in self.lsr(.absolute) },
			0x5e: { [unowned self] in self.lsr(.absoluteX) },
			// ORA
			0x09: { [unowned self] in self.ora(.immediate) },
			0x05: { [unowned self] in self.ora(.zeroPage) },
			0x15: { [unowned self] in self.ora(.zeroPageX) },
			0x0d: { [unowned self] in self.ora(.absolute) },
			0x1d: { [unowned self] in self.ora(.absoluteX) },
			0x19: { [unowned self] in self.ora(.absoluteY) },
			0x01: { [unowned self] in self.ora(.indirectX) },
			0x11: { [unowned self] in self.ora(.indirectY) },
			// ROL
			0x2a: { [unowned self] in self.rol() },
			0x26: { [unowned self] in self.rol(.zeroPage) },
			0x36: { [unowned self] in self.rol(.zeroPage) },
			0x2e: { [unowned self] in self.rol(.absolute) },
			0x3e: { [unowned self] in self.rol(.absoluteX) },
			// ROR
			0x6a: { [unowned self] in self.ror() },
			0x66: { [unowned self] in self.ror(.zeroPage) },
			0x76: { [unowned self] in self.ror(.zeroPageX) },
			0x6e: { [unowned self] in self.ror(.absolute) },
			0x7e: { [unowned self] in self.ror(.absoluteX) },
			// RTS
			0x60: { [unowned self] in self.rts() },
			// SBC
			0xe9: { [unowned self] in self.sbc(.immediate) },
			0xe5: { [unowned self] in self.sbc(.zeroPage) },
			0xf5: { [unowned self] in self.sbc(.zeroPageX) },
			0xed: { [unowned self] in self.sbc(.absolute) },
			0xfd: { [unowned self] in self.sbc(.absoluteX) },
			0xf9: { [unowned self] in self.sbc(.absoluteY) },
			0xe1: { [unowned self] in self.sbc(.indirectX) },
			0xf1: { [unowned self] in self.sbc(.indirectY) },
			// SEC
			0x38: { [unowned self] in self.sec() },
			// SED
			0xf8: { [unowned self] in self.sed() },
			// SEI
			0x78: { [unowned self] in self.sei() },
			// STA
			0x85: { [unowned self] in self.sta(.zeroPage) },
			0x95: { [unowned self] in self.sta(.zeroPageX) },
			0x8d: { [unowned self] in self.sta(.absolute) },
			0x9d: { [unowned self] in self.sta(.absoluteX) },
			0x99: { [unowned self] in self.sta(.absoluteY) },
			0x81: { [unowned self] in self.sta(.indirectX) },
			0x91: { [unowned self] in self.sta(.indirectY) },
			// STX
			0x86: { [unowned self] in self.stx(.zeroPage) },
			0x96: { [unowned self] in self.stx(.zeroPageY) },
			0x8e: { [unowned self] in self.stx(.absolute) },
			// STY
			0x84: { [unowned self] in self.sty(.zeroPage) },
			0x94: { [unowned self] in self.sty(.zeroPageX) },
			0x8c: { [unowned self] in self.sty(.absolute) },
			// TAX
			0xaa: { [unowned self] in self.tax() },
			// TAY
			0xa8: { [unowned self] in self.tay() },
			// TSX
			0xba: { [unowned self] in self.tsx() },
			// TXA
			0x8a: { [unowned self] in self.txa() },
			// TXS
			0x9a: { [unowned self] in self.txs() },
			// TYA
			0x98: { [unowned self] in self.tya() }
		]
	}()
}


// MARK: -
// MARK: Memory addressing
protocol MOS6502Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word
	func write(_ value: MOS6507.Word, at address: MOS6507.Address)
}

private extension MOS6507 {
	func resolveAddress(using addressing: AddressingMode) -> (Address, Int, Int) {
		switch addressing {
		case .immediate:
			let address = self.programCounter + 1
			return (address, 2, 1)
			
		case .absolute:
			let address = Address(
				self.bus.read(at: self.programCounter + 1),
				self.bus.read(at: self.programCounter + 2))
			
			return (address, 3, 3)
			
		case .absoluteX:
			var address = Address(
				self.bus.read(at: self.programCounter + 1),
				self.bus.read(at: self.programCounter + 2))
			
			let page = address.high
			address += self.y
			
			let cycles = address.high == page ? 3 : 4
			return (address, 3, cycles)
			
		case .absoluteY:
			var address = Address(
				self.bus.read(at: self.programCounter + 1),
				self.bus.read(at: self.programCounter + 2))
			
			let page = address.high
			address += self.y
			
			let cycles = address.high == page ? 3 : 4
			return (address, 3, cycles)
			
		case .zeroPage:
			let address = Address(
				self.bus.read(at: self.programCounter + 1),
				0x00)
			
			return (address, 2, 2)
			
		case .zeroPageX:
			var address = Address(
				self.bus.read(at: self.programCounter + 1),
				0x00)
			
			address.low += self.x
			return (address, 2, 3)
			
		case .zeroPageY:
			var address = Address(
				self.bus.read(at: self.programCounter + 1),
				0x00)
			
			address.low += self.y
			return (address, 2, 3)
			
		case .indirectX:
			var address = Address(
				self.bus.read(at: self.programCounter + 1),
				0x00)
			
			address.low += self.x
			address = Address(
				self.bus.read(at: address),
				self.bus.read(at: address + 1))
			
			return (address, 2, 5)
			
		case .indirectY:
			var address = Address(
				self.bus.read(at: self.programCounter + 1),
				0x00)
			
			address = Address(
				self.bus.read(at: address),
				self.bus.read(at: address + 1))
			
			let page = address.high
			address += self.y
			
			let cycles = address.high == page ? 5 : 6
			return (address, 2, cycles)
			
		case .relative:
			var offset = self.bus.read(at: self.programCounter + 1)
			if offset[7] {
				offset -= (0xff + 0x01)
			}
			
			var address = self.programCounter + 2
			
			let page = address.high
			address += offset
			
			let cycles = address.high == page ? 4 : 3
			return (address, 2, cycles)
			
		default:
			fatalError("Cannot resolve operand address using \(addressing) addressing mode.")
		}
	}
}


// MARK: -
// MARK: Operations
private extension MOS6507 {
	/// Add a value in memory to accumulator with carry.
	func adc(_ addressing: AddressingMode) -> Int {
		let (_, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		// TODO: ADC
		
		return cycles
	}
	
	/// Conjunct Accumulator with a value in memory.
	func and(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.accumulator & operand
		
		self.accumulator = result & 0xff
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 1
	}
	
	/// Shift bits of Accumulator 1 position to the left.
	func asl() -> Int {
		self.programCounter += 1
		
		let result = self.accumulator << 1
		
		self.accumulator = result & 0xff
		self.status.carry = result[8]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return 2
	}
	
	/// Shift bits of value in memory 1 position to the left.
	func asl(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = operand << 1
		
		self.bus.write(result & 0xff, at: address)
		self.status.carry = result[8]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 3
	}
	
	/// Branch on zero status set.
	func beq() -> Int {
		if self.status.zero {
			let (address, _, cycles) = self.resolveAddress(using: .relative)
			
			self.programCounter = address
			return cycles
		} else {
			self.programCounter += 2
			return 2
		}
	}
	
	/// Test Accumulator bits against bits of a value in memory.
	func bit(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.accumulator & operand
		
		self.status.overflow = operand[6]
		self.status.zero = result == 0x00
		self.status.negative = operand[7]
		
		return cycles + 1
	}
	
	/// Branch on negative status set.
	func bmi() -> Int {
		if self.status.negative {
			let (address, _, cycles) = self.resolveAddress(using: .relative)
			
			self.programCounter = address
			return cycles
		} else {
			self.programCounter += 2
			return 2
		}
	}
	
	/// Branch on zero status clear.
	func bne() -> Int {
		if self.status.zero == false {
			let (address, _, cycles) = self.resolveAddress(using: .relative)
			
			self.programCounter = address
			return cycles
		} else {
			self.programCounter += 2
			return 2
		}
	}
	
	/// Branch on negative status clear.
	func bpl() -> Int {
		if self.status.negative == false {
			let (address, _, cycles) = self.resolveAddress(using: .relative)
			
			self.programCounter = address
			return cycles
		} else {
			self.programCounter += 2
			return 2
		}
	}
	
	/// Branch on zero overflow clear.
	func bvc() -> Int {
		if self.status.zero == false {
			let (address, _, cycles) = self.resolveAddress(using: .relative)
			
			self.programCounter = address
			return cycles
		} else {
			self.programCounter += 2
			return 2
		}
	}
	
	/// Branch on overflow status set.
	func bvs() -> Int {
		if self.status.overflow {
			let (address, _, cycles) = self.resolveAddress(using: .relative)
			
			self.programCounter = address
			return cycles
		} else {
			self.programCounter += 2
			return 2
		}
	}
	
	/// Clear carry status.
	func clc() -> Int {
		self.programCounter += 1
		
		self.status.carry = false
		return 2
	}
	
	/// Clear decimal mode status.
	func cld() -> Int {
		self.programCounter += 1
		
		self.status.decimalMode = false
		return 2
	}
	
	/// Clear intterupt disabled status.
	func cli() -> Int {
		self.programCounter += 1
		
		self.status.interruptDisabled = false
		return 2
	}
	
	/// Clear overflow status.
	func clv() -> Int {
		self.programCounter += 1
		
		self.status.overflow = false
		return 2
	}
	
	/// Compare Accumulator to a value in memory.
	func cmp(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.accumulator - operand
		
		self.status.carry = result >= 0x00
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 1
	}
	
	/// Compare X register to a value in memory.
	func cpx(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.x - operand
		
		self.status.carry = result >= 0x00
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 1
	}
	
	/// Compare Y register to a value in memory.
	func cpy(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.y - operand
		
		self.status.carry = result >= 0x00
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 1
	}
	
	/// Decrement a value in memory by 1.
	func dec(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		var result = operand - 0x01
		if result < 0x00 {
			result = 0xff
		}
		
		self.bus.write(result, at: address)
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 3
	}
	
	/// Decrement value of X register by 1,
	func dex() -> Int {
		self.programCounter += 1
		
		var result = self.x - 0x01
		if result < 0x00 {
			result = 0xff
		}
		
		self.x = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return 2
	}
	
	/// Decrement value of Y register by 1,
	func dey() -> Int {
		self.programCounter += 1
		
		var result = self.y - 0x01
		if result < 0x00 {
			result = 0xff
		}
		
		self.y = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return 2
	}
	
	/// Exclusive-disjunct Accumulator with a value in memory.
	func eor(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.accumulator ^ operand
		
		self.accumulator = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 1
	}
	
	/// Increment a value in memory by 1.
	func inc(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		
		var result = operand + 0x01
		if result > 0xff {
			result = 0x00
		}
		
		self.bus.write(result, at: address)
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 3
	}
	
	/// Increment value of X register by 1,
	func inx() -> Int {
		self.programCounter += 1
		
		var result = self.x + 0x01
		if result > 0xff {
			result = 0x00
		}
		
		self.x = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return 2
	}
	
	/// Increment value of Y register by 1,
	func iny() -> Int {
		self.programCounter += 1
		
		var result = self.y + 0x01
		if result > 0xff {
			result = 0x00
		}
		
		self.y = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return 2
	}
	
	/// Jump to subroutine.
	func jsr(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		self.pushStack(self.programCounter.high)
		self.pushStack(self.programCounter.low)
		self.programCounter = address
		
		return cycles + 3
	}
	
	/// Load a value from memory into Accumulator.
	func lda(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		
		self.accumulator = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return cycles + 1
	}
	
	/// Load a value from memory into X register.
	func ldx(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		
		self.x = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return cycles + 1
	}
	
	/// Load a value from memory into Y register.
	func ldy(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		
		self.y = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return cycles + 1
	}
	
	/// Shift bits of Accumulator 1 position to the right.
	func lsr() -> Int {
		let (_, bytes, cycles) = self.resolveAddress(using: .implied)
		self.programCounter += bytes
		
		let carry = self.accumulator[0]
		let result = self.accumulator >> 1
		
		self.accumulator = result
		self.status.carry = carry
		self.status.zero = result == 0x00
		self.status.negative = false
		
		return cycles
	}
	
	/// Shift bits of value in memory 1 position to the right.
	func lsr(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = operand >> 1
		
		self.bus.write(result, at: address)
		self.status.carry = operand[0]
		self.status.zero = result == 0x00
		self.status.negative = false
		
		return cycles + 3
	}
	
	/// Disjunct Accumulator with a value in memory.
	func ora(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		let result = self.accumulator & operand
		
		self.accumulator = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 1
	}
	
	/// Rotate bits of Accumulator 1 position to the left.
	func rol() -> Int {
		let (_, bytes, cycles) = self.resolveAddress(using: .implied)
		self.programCounter += bytes
		
		let operand = self.accumulator
		var result = operand << 1
		result[0] = self.status.carry
		
		self.accumulator = result & 0xff
		self.status.carry = operand[7]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles
	}
	
	/// Rotate bits of a value in memory 1 position to the left.
	func rol(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		var result = operand << 1
		result[0] = self.status.carry
		
		self.bus.write(result & 0xff, at: address)
		self.status.carry = operand[7]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles + 3
	}
	
	/// Rotate bits of Accumulator 1 position to the right.
	func ror() -> Int {
		let (_, bytes, cycles) = self.resolveAddress(using: .implied)
		self.programCounter += bytes
		
		let operand = self.accumulator
		var result = operand >> 1
		result[7] = self.status.carry
		
		self.accumulator = result
		self.status.carry = operand[0]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles
	}
	
	/// Rotate bits of a value in memory 1 position to the right.
	func ror(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: .implied)
		self.programCounter += bytes
		
		let operand = self.bus.read(at: address)
		var result = operand >> 1
		result[7] = self.status.carry
		
		self.bus.write(result, at: address)
		self.status.carry = operand[0]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
		
		return cycles
	}
	
	/// Return from subroutine.
	func rts() -> Int {
		let address = Address(
			self.pullStack(),
			self.pullStack())
		
		self.programCounter = address + 1
		return 6
	}
	
	/// Substract a value in memory from accumulator with borrow.
	func sbc(_ addressing: AddressingMode) -> Int {
		let (_, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		// TODO: SBC
		
		return cycles
	}
	
	/// Set carry status.
	func sec() -> Int {
		self.programCounter += 1
		
		self.status.carry = false
		return 2
	}
	
	/// Set decimal mode status.
	func sed() -> Int {
		self.programCounter += 1
		
		self.status.decimalMode = false
		return 2
	}
	
	/// Set interrupt disabled status.
	func sei() -> Int {
		self.programCounter += 1
		
		self.status.interruptDisabled = true
		return 2
	}
	
	/// Store accumulator in memory.
	func sta(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		self.bus.write(self.accumulator, at: address)
		return cycles + 1
	}
	
	/// Store X register in memory.
	func stx(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		self.bus.write(self.x, at: address)
		return cycles + 1
	}
	
	/// Store Y register in memory.
	func sty(_ addressing: AddressingMode) -> Int {
		let (address, bytes, cycles) = self.resolveAddress(using: addressing)
		self.programCounter += bytes
		
		self.bus.write(self.y, at: address)
		return cycles + 1
	}
	
	/// Transfer Accumulator into X register.
	func tax() -> Int {
		self.programCounter += 1
		
		let operand = self.accumulator
		
		self.x = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return 2
	}
	
	/// Transfer Accumulator into Y register.
	func tay() -> Int {
		self.programCounter += 1
		
		let operand = self.accumulator
		
		self.y = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return 2
	}
	
	/// Transfer Stack pointer into X register.
	func tsx() -> Int {
		self.programCounter += 1
		
		let operand = self.stackPointer
		
		self.x = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return 2
	}
	
	/// Transfer X register into Accumulator.
	func txa() -> Int {
		self.programCounter += 1
		
		let operand = self.x
		
		self.accumulator = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return 2
	}
	
	/// Transfer X register into Stack pointer.
	func txs() -> Int {
		self.programCounter += 1
		
		let operand = self.x
		
		self.stackPointer = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return 2
	}
	
	/// Transfer Y register into Accumulator.
	func tya() -> Int {
		self.programCounter += 1
		
		let operand = self.y
		
		self.accumulator = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
		
		return 2
	}
}

public extension MOS6507 {
	func reset() {
		self.eventSubject.send(.reset)
		self.status.interruptDisabled = true
		
		self.programCounter = Address(
			self.bus.read(at: 0xfffe),
			self.bus.read(at: 0xfffd))
	}
	
	func step() {
		self.eventSubject.send(.sync)
		
		let code = self.bus.read(at: self.programCounter)
		if let operation = self.operations[code] {
			let message = String(format: "$%04x \(Mnemonic(opcode: code)!)", self.programCounter)
			print(message)
			let _ = operation()
		} else {
			let message = String(format: "Illegal opcode %02x at $%04x.", code, self.programCounter)
			fatalError(message)
		}
	}
	
	func run(until breakpoints: [MOS6507.Address]) {
		while !breakpoints.contains(self.programCounter) {
			self.step()
		}
	}
	
	private func pushStack(_ data: Word) {
		let address = 0x0100 + self.stackPointer
		self.bus.write(data, at: address)
		self.stackPointer -= 0x01
	}
	
	private func pullStack() -> Word {
		let address = 0x0100 + self.stackPointer
		let data = self.bus.read(at: address)
		self.stackPointer += 0x01
		
		return data
	}
	//
	//	private func pushToStack(_ value: Word) {
	//
	//	}
	//
	//	private func pushToStack(_ address: Address) {
	//
	//	}
	//
	//	private func pullFromStack() -> Word {
	//		return 0x00
	//	}
	//
	//	private func read(at adress: Address, using adressing: Addressing) -> Word {
	//		return 0x00
	//	}
	//
	//	private func operand(adressed adressing: Addressing) -> (Word, Address) {
	//		return (0x00, 0x0000)
	//	}
	//
	//	private mutating func perform(_ operation: Operation, _ addressing: Addressing) {
	//		switch operation {
	//		case .adc:
	//			// TODO:
	//			break
	//
	//		case .and:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = self.accumulator & operand
	//
	//			self.accumulator = result
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .asl:
	//			let (operand, address) = self.operand(adressed: addressing)
	//			let result = operand << 1
	//
	//			if addressing == .accumulator {
	//				self.accumulator = result
	//			} else {
	//				self.bus.write(result, at: address)
	//			}
	//
	//			self.status.carry = result[8]
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .bcc:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.carry == false {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .bcs:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.carry {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .beq:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.zero {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .bit:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = operand & self.accumulator
	//
	//			self.status.overflow = operand[6]
	//			self.status.zero = result == 0x00
	//			self.status.negative = operand[7]
	//
	//		case .bmi:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.negative {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .bne:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.zero == false {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .bpl:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.negative == false {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .brk:
	//			self.pushToStack(self.programCounter)
	//			self.pushToStack(self.status)
	//			self.status.interrupt = true
	//
	//		case .bvc:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.overflow == false {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .bvs:
	//			let (offset, _) = self.operand(adressed: addressing)
	//			if self.status.overflow {
	//				self.programCounter += Address(offset, 0x00)
	//			}
	//
	//		case .clc:
	//			self.status.carry = false
	//		case .cld:
	//			self.status.decimal = false
	//		case .cli:
	//			self.status.interrupt = false
	//		case .clv:
	//			self.status.overflow = false
	//
	//		case .cmp:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = self.accumulator + (~operand + 1)
	//
	//			self.status.carry = self.accumulator > operand
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .cpx:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = self.x + (~operand + 1)
	//
	//			self.status.carry = self.x >= operand
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .cpy:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = self.y + (~operand + 1)
	//
	//			self.status.carry = self.y >= operand
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .dec:
	//			let (operand, address) = self.operand(adressed: addressing)
	//			let result = operand + (~0x01 + 1)
	//
	//			self.bus.write(result, at: address)
	//
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .dex:
	//			let result = self.x + (~0x01 + 1)
	//
	//			self.x = result
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .dey:
	//			let result = self.y + (~0x01 + 1)
	//
	//			self.y = result
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .eor:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = self.accumulator ^ operand
	//
	//			self.accumulator = result
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .inc:
	//			let (operand, address) = self.operand(adressed: addressing)
	//			let result = operand + 1
	//
	//			self.bus.write(result, at: address)
	//
	//			self.status.zero = result == 0
	//			self.status.negative = result[7]
	//
	//		case .inx:
	//			let result = self.x + 1
	//
	//			self.x = result
	//			self.status.zero = result == 0
	//			self.status.negative = result[7]
	//
	//		case .iny:
	//			let result = self.y + 1
	//
	//			self.y = result
	//			self.status.zero = result == 0
	//			self.status.negative = result[7]
	//
	//		case .jmp:
	//			// TODO: JMP
	//			break
	//
	//		case .jsr:
	//			// TODO: JSR
	//			break
	//
	//		case .lda:
	//			let (operand, _) = self.operand(adressed: addressing)
	//
	//			self.accumulator = operand
	//			self.status.zero = operand == 0x00
	//			self.status.negative = operand[7]
	//
	//		case .ldx:
	//			let (operand, _) = self.operand(adressed: addressing)
	//
	//			self.x = operand
	//			self.status.zero = operand == 0x00
	//			self.status.negative = operand[7]
	//
	//		case .ldy:
	//			let (operand, _) = self.operand(adressed: addressing)
	//
	//			self.y = operand
	//			self.status.zero = operand == 0x00
	//			self.status.negative = operand[7]
	//
	//		case .lsr:
	//			let (operand, address) = self.operand(adressed: addressing)
	//			let result = operand >> 1
	//
	//			if addressing == .accumulator {
	//				self.accumulator = result
	//			} else {
	//				self.bus.write(result, at: address)
	//			}
	//
	//			self.status.carry = operand[0]
	//			self.status.zero = result == 0x00
	//			self.status.negative = false
	//
	//		case .nop:
	//			// does nothing
	//			break
	//
	//		case .ora:
	//			let (operand, _) = self.operand(adressed: addressing)
	//			let result = self.accumulator & operand
	//
	//			self.accumulator = result
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .pha:
	//			self.pushToStack(self.accumulator)
	//		case .php:
	//			self.pushToStack(self.status)
	//		case .pla:
	//			self.accumulator = self.pullFromStack()
	//		case .plp:
	//			self.status = self.pullFromStack()
	//
	//		case .rol:
	//			let (operand, address) = self.operand(adressed: addressing)
	//			let carry: UInt8 = self.status.carry ? 0x01 : 0x00
	//			let result = (operand << 1) & carry
	//
	//			if addressing == .accumulator {
	//				self.accumulator = result
	//			} else {
	//				self.bus.write(result, at: address)
	//			}
	//
	//			self.status.carry = operand[7]
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .ror:
	//			let (operand, address) = self.operand(adressed: addressing)
	//			let carry: UInt8 = self.status.carry ? 0x80 : 0x00
	//			let result = (operand >> 1) & carry
	//
	//			if addressing == .accumulator {
	//				self.accumulator = result
	//			} else {
	//				self.bus.write(result, at: address)
	//			}
	//
	//			self.status.carry = operand[0]
	//			self.status.zero = result == 0x00
	//			self.status.negative = result[7]
	//
	//		case .rti:
	//			// TODO: RTI
	//			break
	//
	//		case .rts:
	//			// TODO: RTS
	//			break
	//
	//		case .sbc:
	//			// TODO: SBC
	//			break
	//
	//		case .sec:
	//			self.status.carry = true
	//		case .sed:
	//			self.status.decimal = true
	//		case .sei:
	//			self.status.interrupt = true
	//
	//		case .sta:
	//			let (_, address) = self.operand(adressed: addressing)
	//			self.bus.write(self.accumulator, at: address)
	//
	//		case .stx:
	//			let (_, address) = self.operand(adressed: addressing)
	//			self.bus.write(self.x, at: address)
	//
	//		case .sty:
	//			let (_, address) = self.operand(adressed: addressing)
	//			self.bus.write(self.y, at: address)
	//
	//		case .tax:
	//			let value = self.accumulator
	//			self.x = value
	//
	//			self.status.zero = value == 0x00
	//			self.status.negative = value[7]
	//
	//		case .tay:
	//			let value = self.accumulator
	//			self.y = value
	//
	//			self.status.zero = value == 0x00
	//			self.status.negative = value[7]
	//
	//		case .tya:
	//			let value = self.y
	//			self.accumulator = value
	//
	//			self.status.zero = value == 0x00
	//			self.status.negative = value[7]
	//
	//		case .tsx:
	//			let value = self.stackPointer.low
	//			self.x = value
	//
	//			self.status.zero = value == 0x00
	//			self.status.negative = value[7]
	//
	//		case .txa:
	//			let value = self.x
	//			self.accumulator = value
	//
	//			self.status.zero = value == 0x00
	//			self.status.negative = value[7]
	//
	//		case .txs:
	//			let value = self.x
	//			self.stackPointer = Address(value, 0x00)
	//
	//			self.status.zero = value == 0x00
	//			self.status.negative = value[7]
	//		}
	//	}
	//
	struct Instruction {
		public var mnemonic: Mnemonic
		public var mode: AddressingMode
		public var operand: Int
		
		var encodedLenght: Int {
			switch self.mode {
			case .implied:
				return 1
			case .immediate,
					.relative,
					.zeroPage, .zeroPageX, .zeroPageY,
					.indirectX, .indirectY:
				return 2
			case .absolute, .absoluteX, .absoluteY:
				return 3
			}
		}
	}
	
	enum DecodeError: Error {
		case unknownOpcode(Int)
	}
	
	func decodeInstruction(at address: Address) throws -> Instruction {
		let opcode = self.bus.read(at: address)
		
		if let mnemonic = Mnemonic(opcode: opcode),
		   let mode = AddressingMode(opcode: opcode) {
			let operand = self.readOperand(at: address, addressed: mode)
			return Instruction(mnemonic: mnemonic, mode: mode, operand: operand)
		} else {
			throw DecodeError.unknownOpcode(opcode)
		}
	}
	
	func decode(_ data: Data) -> [(Address, Instruction)] {
		var instructions: [(Address, Instruction)] = []
		var address = 0xf000
		
		while address < 0xffff {
			let opcode = self.bus.read(at: address)
			
			guard let mnemonic = Mnemonic(opcode: opcode),
				  let mode = AddressingMode(opcode: opcode) else {
				address += 1
				continue
			}
			
			let operand = self.readOperand(at: address, addressed: mode)
			let instruction = Instruction(mnemonic: mnemonic, mode: mode, operand: operand)
			instructions.append((address, instruction))
			
			address += instruction.encodedLenght
		}
		
		return instructions
	}
	
	func readOperand(at address: Address, addressed mode: AddressingMode) -> Int {
		switch mode {
		case .implied:
			return 0x00
			
		case .immediate,
				.relative,
				.zeroPage, .zeroPageX, .zeroPageY,
				.indirectX, .indirectY:
			return self.bus.read(at: address + 1)
			
		case .absolute, .absoluteX, .absoluteY:
			return Int(
				self.bus.read(at: address + 1),
				self.bus.read(at: address + 2))
		}
	}
	
	func decode(data: Data) {
		var index = data.startIndex
		
		while index < data.endIndex {
			let opcode = data[index]
			guard let operation = Mnemonic(opcode: MOS6507.Word(opcode)),
				  let addressing = AddressingMode(opcode: MOS6507.Word(opcode)) else {
				
				print(String(format: "%04x\t%02x\t\t?", index, opcode))
				index += 1
				continue
			}
			
			switch addressing {
			case .implied:
				print(String(format: "%04x\t%02x\t\t\(operation)", index, opcode))
				index += 1
			case .immediate:
				let operand = data[index + 1]
				print(String(format: "%04x\t%02x %02x\t\(operation) #$%02x", index, opcode, operand, operand))
				index += 2
				
			case .relative:
				let operand = data[index + 1]
				var address = UInt16(index + 2)
				if operand > 0x7f {
					address -= UInt16(~operand + 1) & 0x7f
				} else {
					address += UInt16(operand)
				}
				
				print(String(format: "%04x\t%02x %02x\t\(operation) $%04x", index, opcode, operand, address))
				index += 2
				
			case .zeroPage:
				let operand = data[index + 1]
				print(String(format: "%04x\t%02x %02x\t\(operation) $%02x", index, opcode, operand, operand))
				index += 2
			case .zeroPageX:
				let operand = data[index + 1]
				print(String(format: "%04x\t%02x %02x\t\(operation) $%02x,X", index, opcode, operand, operand))
				index += 2
			case .zeroPageY:
				let operand = data[index + 1]
				print(String(format: "%04x\t%02x %02x\t\(operation) $%02x,Y", index, opcode, operand, operand))
				index += 2
				
			case .absolute:
				let operand = Address(data[index + 1], data[index + 2])
				print(String(format: "%04x\t%02x %04x\t\(operation) $%04x", index, opcode, operand, operand))
				index += 3
			case .absoluteX:
				let operand = Address(data[index + 1], data[index + 2])
				print(String(format: "%04x\t%02x %04x\t\(operation) $%04x,X", index, opcode, operand, operand))
				index += 3
			case .absoluteY:
				let operand = Address(data[index + 1], data[index + 2])
				print(String(format: "%04x\t%02x %04x\t\(operation) $%04x,Y", index, opcode, operand, operand))
				index += 3
				
			case .indirectX:
				let operand = data[index + 1]
				print(String(format: "%04x\t%02x %02x\t\(operation) ($%02x,X)", index, opcode, operand, operand))
				index += 2
			case .indirectY:
				let operand = data[index + 1]
				print(String(format: "%04x\t%02x %02x\t\(operation) ($%02x),Y", index, opcode, operand, operand))
				index += 2
			}
		}
	}
}


public extension MOS6507 {
	typealias Word = Int
	typealias Address = Int
//	typealias Status = UInt8
}

private extension Int {
	subscript(bit: Int) -> Bool {
		get {
			let mask = 0x01 << bit
			return self & mask == mask
		}
		set {
			let mask = 0x01 << bit
			if newValue {
				self |= mask
			} else {
				self &= ~mask
			}
		}
	}
}

//public extension MOS6507.Status {
//	subscript(bit: Int) -> Bool {
//		get {
//			let mask: Self = 0x01 << bit
//			return self & mask == mask
//		}
//		set {
//			let mask: Self = 0x01 << bit
//			if newValue {
//				self |= mask
//			} else {
//				self &= ~mask
//			}
//		}
//	}
//}
//
//public extension MOS6507.Status {
//	var carry: Bool {
//		get { return self[0] }
//		set { self[0] = newValue }
//	}
//
//	var zero: Bool {
//		get { return self[1] }
//		set { self[1] = newValue }
//	}
//
//	var interruptDisabled: Bool {
//		get { return self[2] }
//		set { self[2] = newValue }
//	}
//
//	var decimal: Bool {
//		get { return self[3] }
//		set { self[3] = newValue }
//	}
//
//	var `break`: Bool {
//		get { return self[4] }
//		set { self[4] = newValue }
//	}
//
//	var overflow: Bool {
//		get { return self[6] }
//		set { self[6] = newValue }
//	}
//
//	var negative: Bool {
//		get { return self[7] }
//		set { self[7] = newValue }
//	}
//}

extension MOS6507.Word {
	var isNegative: Bool {
		return self & 0x80 == 0x80
	}
}

public extension MOS6507 {
	enum Mnemonic {
		// group 1
		case adc
		case and
		case cmp
		case eor
		case lda
		case ora
		case sbc
		case sta
		
		// group 2
		case lsr
		case asl
		case rol
		case ror
		
		case inc
		case dec
		case ldx
		case stx
		
		// group 3
		case ldy
		case sty
		case cpy
		case cpx
		case bit
		case jmp
		
		// refister operations
		case dey
		case tay
		case inx
		case iny
		case tya
		case txa
		case txs
		case tax
		case tsx
		case dex
		case nop
		
		// branch operations
		case bcc
		case bcs
		case beq
		case bmi
		case bne
		case bpl
		case bvc
		case bvs
		
		// flag operations
		case clc
		case sec
		case cld
		case sed
		case cli
		case sei
		case clv
		
		// push/pull and stack operations
		case brk
		case jsr
		case rti
		case rts
		case pha
		case php
		case pla
		case plp
	}
	
	enum AddressingMode {
		case implied
		case immediate
		case absolute
		case absoluteX
		case absoluteY
		case zeroPage
		case zeroPageX
		case zeroPageY
		case relative
		case indirectX
		case indirectY
	}
}


// MARK: -
// MARK: Convenience functionality
private extension MOS6507.Address {
	init(_ low: MOS6507.Word, _ high: MOS6507.Word) {
		self = Self(low) | Self(high) << 8
	}
	
	init(_ low: UInt8, _ high: UInt8) {
		self = (Self(low) | Self(high) << 8)
	}
	
	var low: MOS6507.Word {
		get {
			return self % 0xff
		}
		set {
			self = self.high + (newValue % 0xff)
		}
	}
	
	var high: MOS6507.Word {
		get {
			return self / 0xff
		}
		set {
			self = self.low + (newValue % 0xff) * 0xff
		}
	}
}


// MARK: -
// MARK: Operation decoding
public extension MOS6507.Mnemonic {
	init?(opcode: MOS6507.Word) {
		switch opcode {
		case 0x10: self = .bpl
		case 0x30: self = .bmi
		case 0x50: self = .bvc
		case 0x70: self = .bvs
		case 0x90: self = .bcc
		case 0xb0: self = .bcs
		case 0xd0: self = .bne
		case 0xf0: self = .beq
			
		case 0x00: self = .brk
		case 0x20: self = .jsr
		case 0x40: self = .rti
		case 0x60: self = .rts
			
		case 0x08: self = .php
		case 0x28: self = .plp
		case 0x48: self = .pha
		case 0x68: self = .pla
			
		case 0x18: self = .clc
		case 0x38: self = .sec
		case 0x58: self = .cli
		case 0x78: self = .sei
		case 0xb8: self = .clv
		case 0xd8: self = .cld
		case 0xf8: self = .sed
			
		case 0xaa: self = .tax
		case 0x8a: self = .txa
		case 0x9a: self = .txs
		case 0xba: self = .tsx
		case 0xa8: self = .tay
		case 0x98: self = .tya
		case 0xc8: self = .iny
		case 0xe8: self = .inx
		case 0x88: self = .dey
		case 0xca: self = .dex
			
		case 0xea: self = .nop
			
		default:
			let group = opcode & 0x3
			let subcode = opcode >> 5
			
			switch group {
			case 1:
				switch subcode {
				case 0: self = .ora
				case 1: self = .and
				case 2: self = .eor
				case 3: self = .adc
				case 4: self = .sta
				case 5: self = .lda
				case 6: self = .cmp
				case 7: self = .sbc
				default:
					return nil
				}
			case 2:
				switch subcode {
				case 0: self = .asl
				case 1: self = .rol
				case 2: self = .lsr
				case 3: self = .ror
				case 4: self = .stx
				case 5: self = .ldx
				case 6: self = .dec
				case 7: self = .inc
				default:
					return nil
				}
			case 0:
				switch subcode {
				case 1: self = .bit
				case 2: self = .jmp
				case 3: self = .jmp
				case 4: self = .sty
				case 5: self = .ldy
				case 6: self = .cpy
				case 7: self = .cpx
				default:
					return nil
				}
			default:
				return nil
			}
		}
	}
}

public extension MOS6507.AddressingMode {
	init?(opcode: MOS6507.Word) {
		switch opcode {
			// BPL, BMI, BVC, BVS, BCC, BCS, BNE, BEQ
		case 0x10, 0x30, 0x50, 0x70, 0x90, 0xb0, 0xd0, 0xf0:
			self = .relative
			// BRK, RTI, RTS
		case 0x00, 0x40, 0x60,
			// PHP, PLP, PHA, PLA
			0x08, 0x28, 0x48, 0x68,
			// CLC, SEC, CLI, SEI, CLV, CLD, SED
			0x18, 0x38, 0x58, 0x78, 0xb8, 0xd8, 0xf8,
			// TAX, TXA, TXS, TSX, TAY, TYA, INY, INX, DEY, DEX
			0xaa, 0x8a, 0x9a, 0xba, 0xa8, 0x98, 0xc8, 0xe8, 0x88, 0xca,
			// NOP
			0xea:
			self = .implied
			// JSR
		case 0x20:
			self = .absolute
			
		default:
			let group = opcode & 0x3
			let subcode = (opcode >> 2) & 0x7
			
			switch group {
			case 1:
				switch subcode {
				case 0: self = .indirectX
				case 1: self = .zeroPage
				case 2: self = .immediate
				case 3: self = .absolute
				case 4: self = .indirectY
				case 5: self = .zeroPageX
				case 6: self = .absoluteY
				case 7: self = .absoluteX
				default:
					return nil
				}
			case 2:
				switch opcode {
					// STX
				case 0x96: self = .zeroPageY
					// LDX
				case 0xb6: self = .zeroPageY
					// LDX
				case 0xbe: self = .absoluteY
				default:
					switch subcode {
					case 0: self = .immediate
					case 1: self = .zeroPage
					case 2: self = .implied
					case 3: self = .absolute
					case 5: self = .zeroPageX
					case 7: self = .absoluteX
					default:
						return nil
					}
				}
			case 0:
				switch subcode {
				case 0: self = .immediate
				case 1: self = .zeroPage
				case 3: self = .absolute
				case 5: self = .zeroPageX
				case 7: self = .absoluteX
				default:
					return nil
				}
			default:
				return nil
			}
		}
	}
}


// MARK: -
// MARK: Convenience functionality
extension Int {
	static var randomWord: Self {
		return Self.random(in: 0x00...0xff)
	}
	
	static var randomAddress: Self {
		return Self.random(in: 0x0000...0xffff)
	}
}
