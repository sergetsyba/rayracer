//
//  MOS6507+Assembly.swift
//  BeamRacerKit
//
//  Created by Serge Tsyba on 20.6.2023.
//

import Foundation

public class MOS6507Assembly {
	public enum Mnemonic {
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
	
	public enum AddressingMode {
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
	
	public struct Instruction: CustomStringConvertible {
		public var mnemonic: Mnemonic
		public var addressing: AddressingMode
		public var operand: Int
		
		var encodedLenght: Int {
			switch self.addressing {
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
		
		public var description: String {
			let operand = String(format: self.operandFormat, self.operand)
			return "\(self.mnemonic)  " + operand
		}
		
		private var operandFormat: String {
			switch self.addressing {
			case .implied:
				return ""
			case .immediate:
				return "#$%02x"
			case .zeroPage:
				return "$%02x"
			case .zeroPageX:
				return "$%02x,x"
			case .zeroPageY:
				return "$%02x,y"
			case .absolute:
				return "$%04x"
			case .absoluteX:
				return "$%04x,x"
			case .absoluteY:
				return "$%04x,y"
			case .indirectX:
				return "($%02x,x)"
			case .indirectY:
				return "($%02x),y"
			case .relative:
				return "$%04x"
			}
		}
	}
}


public enum MOS6507AssemblyError: Error {
	case unknownOpcode(Int)
}


// MARK: -
// MARK: Disassembling
extension MOS6507Assembly {
	public static func disassemble(_ data: Data) -> [(Address, Instruction)] {
		var program: [(Address, Instruction)] = []
		var index = data.startIndex
		
		while index < data.endIndex - 1 {
			// TODO: return unknown opcodes as data
			if let instruction = try? Self.decodeInstruction(in: data, at: index) {
				program.append((0xf000 + index, instruction))
				index += instruction.encodedLenght
			} else {
				index += 1
			}
		}
		return program
	}
	
	static func decodeInstruction(in data: Data, at index: Int) throws -> Instruction {
		let opcode = Int(data[index])
		
		if let mnemonic = Mnemonic(opcode: opcode),
		   let mode = AddressingMode(opcode: opcode) {
			let operand = Self.decodeOperand(in: data, at: index + 1, addressing: mode)
			return Instruction(mnemonic: mnemonic, addressing: mode, operand: operand)
		} else {
			throw MOS6507AssemblyError.unknownOpcode(index)
		}
	}
	
	static func decodeOperand(in data: Data, at index: Int, addressing: AddressingMode) -> Int {
		switch addressing {
		case .implied:
			return 0x00
			
		case .immediate,
				.zeroPage, .zeroPageX, .zeroPageY,
				.indirectX, .indirectY:
			return Int(data[index])
			
		case .absolute, .absoluteX, .absoluteY:
			let low = Int(data[index])
			let high = Int(data[index + 1])
			return high * 0x0100 + low
			
		case .relative:
			let offset = Int(signed: Int(data[index]))
			return 0xf001 + index + offset
		}
	}
}


// MARK: -
extension MOS6507Assembly.Mnemonic {
	init?(opcode: Int) {
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

extension MOS6507Assembly.AddressingMode {
	init?(opcode: Int) {
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

public extension MOS6507Assembly {
	static let tiaLabels = [
		0x00: "vsync",
		0x01: "vblank",
		0x02: "wsync",
		0x03: "rsync",
		0x04: "nusiz0",
		0x05: "nusiz1",
		0x06: "colup0",
		0x07: "colup1",
		0x08: "colupf",
		0x09: "colubk",
		0x0a: "ctrlpf",
		0x0b: "refp0",
		0x0c: "refp1",
		0x0d: "pf0",
		0x0e: "pf1",
		0x0f: "pf2",
		0x10: "resp0",
		0x11: "resp1",
		0x12: "resm0",
		0x13: "resm1",
		0x14: "resbl",
		0x15: "audc0",
		0x16: "audc1",
		0x17: "audf0",
		0x18: "audf1",
		0x19: "audv0",
		0x1a: "audv1",
		0x1b: "grp0",
		0x1c: "grp1",
		0x1d: "enam0",
		0x1e: "enam1",
		0x1f: "enabl",
		0x20: "hmp0",
		0x21: "hmp1",
		0x22: "hmm0",
		0x23: "hmm1",
		0x24: "hmbl",
		0x25: "vdelp0",
		0x26: "vdelp1",
		0x27: "vdelbl",
		0x28: "resmp0",
		0x29: "resmp1",
		0x2a: "hmove",
		0x2b: "hmclr",
		0x2c: "cxclr",
		0x30: "cxm0p",
		0x31: "cxm1p",
		0x32: "cxp0fb",
		0x33: "cxp1fb",
		0x34: "cxm0fb",
		0x35: "cxm1fb",
		0x36: "cxblpf",
		0x37: "cxppmm",
		0x38: "inpt0",
		0x39: "inpt1",
		0x3a: "inpt2",
		0x3b: "inpt3",
		0x3c: "inpt4",
		0x3d: "inpt5"
	]
	
	static let riotLabels = [
		0x00: "swcha",
		0x01: "swacnt",
		0x02: "swchb",
		0x03: "swbcnt",
		0x04: "intim",
		0x06: "intim"
	]
}
