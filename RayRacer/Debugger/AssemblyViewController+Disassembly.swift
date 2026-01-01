//
//  AssemblyViewController+Disassembly.swift
//  RayRacer
//
//  Created by Serge Tsyba on 25.12.2025.
//

import Foundation
import librayracer

extension AssemblyViewController {
	func disassemble(data: Data) -> Program {
		var decoded: Program = []
		var index = data.startIndex
		
		while data.indices.contains(index) {
			let instruction = self.decodeInstruction(data: data, at: index)
			decoded.append((index, instruction))
			index += instruction?.length ?? 1
		}
		
		return decoded
	}
	
	private func decodeInstruction(data: Data, at index: Data.Index) -> Instruction? {
		// decode mnemonic and addressing mode
		let code = data[index]
		guard let mnemonic = Instruction.Mnemonic(code: code),
			  let mode = Instruction.AddressingMode(code: code) else {
			print("Unknown instruction opcode \(code) at \(index).")
			return nil
		}
		
		// ensure enough data is present for operand
		var instruction = Instruction(mnemonic: mnemonic, mode: mode)
		guard index < data.endIndex - instruction.length else {
			print("Invalid length for \(mnemonic) at \(index).")
			return nil
		}
		
		// decode operand
		switch mode {
		case .implied:
			instruction.operand = nil
			
		case .immediate,
				.zeroPage, .zeroPageX, .zeroPageY,
				.indirectX, .indirectY:
			let index = data.index(after: index)
			instruction.operand = Int(data[index])
			
		case .absolute, .absoluteX, .absoluteY,
				.indirect:
			let index1 = data.index(after: index)
			let index2 = data.index(after: index1)
			instruction.operand = Int(data[index2]) * 0x100 + Int(data[index1])
			
		case .relative:
			let index = data.index(after: index)
			let offset = Int(data[index])
			
			// convert offset to signed int
			instruction.operand = offset & 0x80 == 0x80
			? offset - 0x100
			: offset
		}
		
		return instruction
	}
}

// MARK: -
struct Instruction {
	var mnemonic: Mnemonic
	var mode: AddressingMode
	var operand: Int?
	
	init(mnemonic: Mnemonic, mode: AddressingMode, operand: Int? = nil) {
		self.mnemonic = mnemonic
		self.mode = mode
		self.operand = operand
	}
	
	var length: Int {
		switch self.mode {
		case .implied:
			return 1
		case .immediate,
				.relative,
				.zeroPage, .zeroPageX, .zeroPageY,
				.indirectX, .indirectY:
			return 2
		case .absolute, .absoluteX, .absoluteY,
				.indirect:
			return 3
		}
	}
}


// MARK: -
// MARK: Mnemonics
extension Instruction {
	enum Mnemonic: String {
		case adc, cmp, cpx, cpy, dec, dex, dey, inc, inx, iny, sbc
		case and, asl, bit, eor, lsr, ora, rol, ror
		case bcc, bcs, beq, bmi, bne, bpl, bvc, bvs
		case jmp, jsr, rti, rts
		case clc, cld, cli, clv, sec, sed, sei
		case lda, ldx, ldy, sta, stx, sty
		case tax, tay, tsx, txa, txs, tya
		case pha, php, pla, plp
		case brk, nop
		
		init?(code: UInt8) {
			switch code {
			case 0x61, 0x65, 0x69, 0x6d, 0x71, 0x75, 0x79, 0x7d:
				self = .adc
			case 0x21, 0x25, 0x29, 0x2d, 0x31, 0x35, 0x39, 0x3d:
				self = .and
			case 0x06, 0x0a, 0x0e, 0x16, 0x1e:
				self = .asl
			case 0x90:
				self = .bcc
			case 0xb0:
				self = .bcs
			case 0xf0:
				self = .beq
			case 0x24, 0x2c:
				self = .bit
			case 0x30:
				self = .bmi
			case 0xd0:
				self = .bne
			case 0x10:
				self = .bpl
			case 0x00:
				self = .brk
			case 0x50:
				self = .bvc
			case 0x70:
				self = .bvs
			case 0x18:
				self = .clc
			case 0xd8:
				self = .cld
			case 0x58:
				self = .cli
			case 0xb8:
				self = .clv
			case 0xc1, 0xc5, 0xc9, 0xcd, 0xd1, 0xd5, 0xd9, 0xdd:
				self = .cmp
			case 0xe0, 0xe4, 0xec:
				self = .cpx
			case 0xc0, 0xc4, 0xcc:
				self = .cpy
			case 0xc6, 0xce, 0xd6, 0xde:
				self = .dec
			case 0xca:
				self = .dex
			case 0x88:
				self = .dey
			case 0x41, 0x45, 0x49, 0x4d, 0x51, 0x55, 0x59, 0x5d:
				self = .eor
			case 0xe6, 0xee, 0xf6, 0xfe:
				self = .inc
			case 0xe8:
				self = .inx
			case 0xc8:
				self = .iny
			case 0x4c, 0x6c:
				self = .jmp
			case 0x20:
				self = .jsr
			case 0xa1, 0xa5, 0xa9, 0xad, 0xb1, 0xb5, 0xb9, 0xbd:
				self = .lda
			case 0xa2, 0xa6, 0xae, 0xb6, 0xbe:
				self = .ldx
			case 0xa0, 0xa4, 0xac, 0xb4, 0xbc:
				self = .ldy
			case 0x46, 0x4a, 0x4e, 0x56, 0x5e:
				self = .lsr
			case 0xea:
				self = .nop
			case 0x01, 0x05, 0x09, 0x0d, 0x11, 0x15, 0x19, 0x1d:
				self = .ora
			case 0x48:
				self = .pha
			case 0x08:
				self = .php
			case 0x68:
				self = .pla
			case 0x28:
				self = .plp
			case 0x26, 0x2a, 0x2e, 0x36, 0x3e:
				self = .rol
			case 0x66, 0x6a, 0x6e, 0x76, 0x7e:
				self = .ror
			case 0x40:
				self = .rti
			case 0x60:
				self = .rts
			case 0xe1, 0xe5, 0xe9, 0xed, 0xf1, 0xf5, 0xf9, 0xfd:
				self = .sbc
			case 0x38:
				self = .sec
			case 0xf8:
				self = .sed
			case 0x78:
				self = .sei
			case 0x81, 0x85, 0x8d, 0x91, 0x95, 0x99, 0x9d:
				self = .sta
			case 0x86, 0x8e, 0x96:
				self = .stx
			case 0x84, 0x8c, 0x94:
				self = .sty
			case 0xaa:
				self = .tax
			case 0xa8:
				self = .tay
			case 0xba:
				self = .tsx
			case 0x8a:
				self = .txa
			case 0x9a:
				self = .txs
			case 0x98:
				self = .tya
			default:
				return nil
			}
		}
	}
}


// MARK: -
// MARK: Addressing modes
extension Instruction {
	enum AddressingMode {
		case implied, immediate
		case absolute, absoluteX, absoluteY
		case zeroPage, zeroPageX, zeroPageY
		case relative
		case indirect, indirectX, indirectY
		
		init?(code: UInt8) {
			switch code {
			case 0x00, 0x08, 0x18, 0x28, 0x38, 0x40, 0x48, 0x58, 0x60, 0x68,
				0x78, 0x88, 0x8a, 0x98, 0x9a, 0xa8, 0xaa, 0xb8, 0xba, 0xc8,
				0xca, 0xd8, 0xe8, 0xea, 0xf8, 0x0a, 0x2a, 0x4a, 0x6a:
				self = .implied
				
			case 0x09, 0x29, 0x49, 0x69, 0xa0, 0xa2, 0xa9, 0xc0, 0xc9, 0xe0,
				0xe9:
				self = .immediate
				
			case 0x05, 0x06, 0x24, 0x25, 0x26, 0x45, 0x46, 0x65, 0x66, 0x84,
				0x85, 0x86, 0xa4, 0xa5, 0xa6, 0xc4, 0xc5, 0xc6, 0xe4, 0xe5,
				0xe6:
				self = .zeroPage
				
			case 0x15, 0x16, 0x35, 0x36, 0x55, 0x56, 0x75, 0x76, 0x94, 0x95,
				0xb4, 0xb5, 0xd5, 0xd6, 0xf5, 0xf6:
				self = .zeroPageX
				
			case 0x96, 0xb6:
				self = .zeroPageY
				
			case 0x0d, 0x0e, 0x20, 0x2c, 0x2d, 0x2e, 0x4c, 0x4d, 0x4e, 0x6d,
				0x6e, 0x8c, 0x8d, 0x8e, 0xac, 0xad, 0xae, 0xcc, 0xcd, 0xce,
				0xec, 0xed, 0xee:
				self = .absolute
				
			case 0x1d, 0x1e, 0x3d, 0x3e, 0x5d, 0x5e, 0x7d, 0x7e, 0xbd, 0xbc,
				0xdd, 0xde, 0xfd, 0xfe:
				self = .absoluteX
				
			case 0x19, 0x39, 0x59, 0x79, 0x99, 0x9d, 0xb9, 0xbe, 0xd9, 0xf9:
				self = .absoluteY
				
			case 0x10, 0x30, 0x50, 0x70, 0x90, 0xb0, 0xd0, 0xf0:
				self = .relative
				
			case 0x6c:
				self = .indirect
				
			case 0x01, 0x21, 0x41, 0x61, 0x81, 0xa1, 0xc1, 0xe1:
				self = .indirectX
				
			case 0x11, 0x31, 0x51, 0x71, 0x91, 0xb1, 0xd1, 0xf1:
				self = .indirectY
				
			default:
				return nil
			}
		}
	}
}
