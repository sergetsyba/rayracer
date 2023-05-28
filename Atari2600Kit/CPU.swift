//
//  CPU.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public struct MOS6507 {
	private(set) public var accumulator: Word
	private(set) public var X: Word
	private(set) public var Y: Word
	private(set) public var status: Status
	
	private(set) public var stackPointer: Address
	private(set) public var programCounter: Address
	private var cycle: UInt64
	
	var bus: MOS6502Bus!
	
	public init() {
		self.accumulator = 0x00
		self.X = 0x00
		self.Y = 0x00
		self.status = 0x00
		
		self.stackPointer = 0x00
		self.programCounter = 0x0000
		self.cycle = 0
	}
}

public extension MOS6507 {
	mutating func reset() {
		self.accumulator = 0x00
		self.X = 0x00
		self.Y = 0x00
		self.status = 0x00
		
		self.stackPointer = 0xfd
		self.programCounter = Address(
			self.bus.read(at: 0xfffc),
			self.bus.read(at: 0xfffd))
		
		self.cycle = 0
	}
	
	mutating func step() {
		let code = self.bus.read(at: self.programCounter)
		guard let operation = Operation(code: code),
			  let addressing = Addressing(code: code) else {
			print("Illegal opcode at \(self.programCounter): \(code).")
			return
		}
		
		self.programCounter += 1
		self.perform(operation, addressing)
	}
	
	private func pushToStack(_ value: Word) {
		
	}
	
	private func pushToStack(_ address: Address) {
		
	}
	
	private func pullFromStack() -> Word {
		return 0x00
	}
	
	private func read(at adress: Address, using adressing: Addressing) -> Word {
		return 0x00
	}
	
	private func operand(adressed adressing: Addressing) -> (Word, Address) {
		return (0x00, 0x0000)
	}
	
	private mutating func perform(_ operation: Operation, _ addressing: Addressing) {
		switch operation {
		case .adc:
			// TODO:
			break

		case .and:
			let (operand, _) = self.operand(adressed: addressing)
			let result = self.accumulator & operand

			self.accumulator = result
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .asl:
			let (operand, address) = self.operand(adressed: addressing)
			let result = operand << 1

			if addressing == .accumulator {
				self.accumulator = result
			} else {
				self.bus.write(result, at: address)
			}

			self.status.carry = result[8]
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .bcc:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.carry == false {
				self.programCounter += Address(offset, 0x00)
			}

		case .bcs:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.carry {
				self.programCounter += Address(offset, 0x00)
			}

		case .beq:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.zero {
				self.programCounter += Address(offset, 0x00)
			}

		case .bit:
			let (operand, _) = self.operand(adressed: addressing)
			let result = operand & self.accumulator

			self.status.overflow = operand[6]
			self.status.zero = result == 0x00
			self.status.negative = operand[7]

		case .bmi:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.negative {
				self.programCounter += Address(offset, 0x00)
			}

		case .bne:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.zero == false {
				self.programCounter += Address(offset, 0x00)
			}

		case .bpl:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.negative == false {
				self.programCounter += Address(offset, 0x00)
			}

		case .brk:
			self.pushToStack(self.programCounter)
			self.pushToStack(self.status)
			self.status.interrupt = true

		case .bvc:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.overflow == false {
				self.programCounter += Address(offset, 0x00)
			}

		case .bvs:
			let (offset, _) = self.operand(adressed: addressing)
			if self.status.overflow {
				self.programCounter += Address(offset, 0x00)
			}

		case .clc:
			self.status.carry = false
		case .cld:
			self.status.decimal = false
		case .cli:
			self.status.interrupt = false
		case .clv:
			self.status.overflow = false

		case .cmp:
			let (operand, _) = self.operand(adressed: addressing)
			let result = self.accumulator + (~operand + 1)

			self.status.carry = self.accumulator > operand
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .cpx:
			let (operand, _) = self.operand(adressed: addressing)
			let result = self.X + (~operand + 1)

			self.status.carry = self.X >= operand
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .cpy:
			let (operand, _) = self.operand(adressed: addressing)
			let result = self.Y + (~operand + 1)

			self.status.carry = self.Y >= operand
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .dec:
			let (operand, address) = self.operand(adressed: addressing)
			let result = operand + (~0x01 + 1)

			self.bus.write(result, at: address)

			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .dex:
			let result = self.X + (~0x01 + 1)

			self.X = result
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .dey:
			let result = self.Y + (~0x01 + 1)

			self.Y = result
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .eor:
			let (operand, _) = self.operand(adressed: addressing)
			let result = self.accumulator ^ operand

			self.accumulator = result
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .inc:
			let (operand, address) = self.operand(adressed: addressing)
			let result = operand + 1

			self.bus.write(result, at: address)

			self.status.zero = result == 0
			self.status.negative = result[7]

		case .inx:
			let result = self.X + 1

			self.X = result
			self.status.zero = result == 0
			self.status.negative = result[7]

		case .iny:
			let result = self.Y + 1

			self.Y = result
			self.status.zero = result == 0
			self.status.negative = result[7]

		case .jmp:
			// TODO: JMP
			break

		case .jsr:
			// TODO: JSR
			break

		case .lda:
			let (operand, _) = self.operand(adressed: addressing)

			self.accumulator = operand
			self.status.zero = operand == 0x00
			self.status.negative = operand[7]

		case .ldx:
			let (operand, _) = self.operand(adressed: addressing)

			self.X = operand
			self.status.zero = operand == 0x00
			self.status.negative = operand[7]

		case .ldy:
			let (operand, _) = self.operand(adressed: addressing)

			self.Y = operand
			self.status.zero = operand == 0x00
			self.status.negative = operand[7]

		case .lsr:
			let (operand, address) = self.operand(adressed: addressing)
			let result = operand >> 1

			if addressing == .accumulator {
				self.accumulator = result
			} else {
				self.bus.write(result, at: address)
			}

			self.status.carry = operand[0]
			self.status.zero = result == 0x00
			self.status.negative = false

		case .nop:
			// does nothing
			break

		case .ora:
			let (operand, _) = self.operand(adressed: addressing)
			let result = self.accumulator & operand

			self.accumulator = result
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .pha:
			self.pushToStack(self.accumulator)
		case .php:
			self.pushToStack(self.status)
		case .pla:
			self.accumulator = self.pullFromStack()
		case .plp:
			self.status = self.pullFromStack()

		case .rol:
			let (operand, address) = self.operand(adressed: addressing)
			let carry: UInt8 = self.status.carry ? 0x01 : 0x00
			let result = (operand << 1) & carry

			if addressing == .accumulator {
				self.accumulator = result
			} else {
				self.bus.write(result, at: address)
			}

			self.status.carry = operand[7]
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .ror:
			let (operand, address) = self.operand(adressed: addressing)
			let carry: UInt8 = self.status.carry ? 0x80 : 0x00
			let result = (operand >> 1) & carry

			if addressing == .accumulator {
				self.accumulator = result
			} else {
				self.bus.write(result, at: address)
			}

			self.status.carry = operand[0]
			self.status.zero = result == 0x00
			self.status.negative = result[7]

		case .rti:
			// TODO: RTI
			break

		case .rts:
			// TODO: RTS
			break

		case .sbc:
			// TODO: SBC
			break

		case .sec:
			self.status.carry = true
		case .sed:
			self.status.decimal = true
		case .sei:
			self.status.interrupt = true

		case .sta:
			let (_, address) = self.operand(adressed: addressing)
			self.bus.write(self.accumulator, at: address)

		case .stx:
			let (_, address) = self.operand(adressed: addressing)
			self.bus.write(self.X, at: address)

		case .sty:
			let (_, address) = self.operand(adressed: addressing)
			self.bus.write(self.Y, at: address)

		case .tax:
			let value = self.accumulator
			self.X = value

			self.status.zero = value == 0x00
			self.status.negative = value[7]

		case .tay:
			let value = self.accumulator
			self.Y = value

			self.status.zero = value == 0x00
			self.status.negative = value[7]

		case .tya:
			let value = self.Y
			self.accumulator = value

			self.status.zero = value == 0x00
			self.status.negative = value[7]

		case .tsx:
			let value = self.stackPointer.low
			self.X = value

			self.status.zero = value == 0x00
			self.status.negative = value[7]

		case .txa:
			let value = self.X
			self.accumulator = value

			self.status.zero = value == 0x00
			self.status.negative = value[7]

		case .txs:
			let value = self.X
			self.stackPointer = Address(value, 0x00)

			self.status.zero = value == 0x00
			self.status.negative = value[7]
		}
	}
	
	func decode(data: Data) {
		var index = data.startIndex
		
		while index < data.endIndex {
			let opcode = data[index]
			guard let operation = Operation(code: MOS6507.Word(opcode)),
				  let addressing = Addressing(code: MOS6507.Word(opcode)) else {
				
				print(String(format: "%04x\t%02x\t\t?", index, opcode))
				index += 1
				continue
			}
			
			switch addressing {
			case .accumulator:
				print(String(format: "%04x\t%02x\t\t\(operation) A",index,  opcode))
				index += 1
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

protocol MOS6502Bus {
	func read(at address: MOS6507.Address) -> MOS6507.Word
	func write(_ value: MOS6507.Word, at address: MOS6507.Address)
}

public extension MOS6507 {
	typealias Word = UInt8
	typealias Address = UInt16
	typealias Status = UInt8
}

private extension MOS6507.Word {
	subscript(bit: Int) -> Bool {
		return (self >> bit) & 0x1 == 0x1
	}
}

public extension MOS6507.Status {
	var carry: Bool {
		get {
			return self[0]
		}
		set {
			self &= newValue ? 0x01 : ~0x01
		}
	}
	
	var zero: Bool {
		get {
			return self[1]
		}
		set {
			self &= newValue ? 0x02 : ~0x02
		}
	}
	
	var interrupt: Bool {
		get {
			return self[2]
		}
		set {
			self &= newValue ? 0x04 : ~0x04
		}
	}
	
	var decimal: Bool {
		get {
			return self[3]
		}
		set {
			self &= newValue ? 0x08 : ~0x08
		}
	}
	
	var overflow: Bool {
		get {
			return self[6]
		}
		set {
			self &= newValue ? 0x40 : ~0x40
		}
	}
	
	var negative: Bool {
		get {
			return self[7]
		}
		set {
			self &= newValue ? 0x80 : ~0x80
		}
	}
}

extension MOS6507.Word {
	var isNegative: Bool {
		return self & 0x80 == 0x80
	}
}

private extension MOS6507 {
	enum Operation {
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
	
	enum Addressing {
		case accumulator
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
	
	var high: MOS6507.Word {
		return MOS6507.Word(self >> 8)
	}
	
	var low: MOS6507.Word {
		return MOS6507.Word(self & 0xff)
	}
}

private extension UInt8 {
	var twosComplement: Int8 {
		let complement = ~self + 1
		
		let sign: Int8 = complement > 0x7f ? -1 : 1
		return sign * Int8(complement & 0x7f)
	}
}


// MARK: -
// MARK: Operation decoding
private extension MOS6507.Operation {
	init?(code: MOS6507.Word) {
		switch code {
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
			let group = code & 0x3
			let subcode = code >> 5
			
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

private extension MOS6507.Addressing {
	init?(code: MOS6507.Word) {
		switch code {
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
			let group = code & 0x3
			let subcode = (code >> 2) & 0x7
			
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
				switch code {
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
					case 2: self = .accumulator
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
