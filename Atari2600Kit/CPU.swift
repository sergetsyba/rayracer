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
	
	private(set) public var stackPointer: Word
	private(set) public var programCounter: Address
	private var cycle: UInt64
	
	var bus: MOS6502Bus!
	
	public init() {
		self.accumulator = 0x00
		self.X = 0x00
		self.Y = 0x00
		self.status = []
		
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
		self.status = []
		
		self.stackPointer = 0xfd
		self.programCounter = Address(
			self.bus.read(at: 0xfffc),
			self.bus.read(at: 0xfffd))
		
		self.cycle = 0
	}
	
	mutating func step() {
		let code = self.bus.read(at: self.programCounter)
		self.programCounter += 1
		
		print(String(format: "%02x", code))
		
		let operation = Operation(code: code)
		let addressing = Addressing(code: code)
		print(operation, addressing)
	}
	
	func decode(data: Data) {
		var index = data.startIndex
		
		while index < data.endIndex {
			let opcode = data[index]
			guard let operation = Operation(code: opcode),
				  let addressing = Addressing(code: opcode) else {
				
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
}

public extension MOS6507 {
	typealias Word = UInt8
	typealias Address = UInt16
	
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
		case bpc
		case bps
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
