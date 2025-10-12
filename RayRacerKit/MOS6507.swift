//
//  MOS6507.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public struct MOS6507 {
	private(set) public var accumulator: Int {
		didSet {
			self.status[.zero] = self.accumulator == 0x0
			self.status[.negative] = self.accumulator[7]
		}
	}
	private(set) public var x: Int {
		didSet {
			self.status[.zero] = self.x == 0x0
			self.status[.negative] = self.x[7]
		}
	}
	private(set) public var y: Int {
		didSet {
			self.status[.zero] = self.y == 0x0
			self.status[.negative] = self.y[7]
		}
	}
	
	private(set) public var status: Status
	private(set) public var stackPointer: Int
	private(set) public var programCounter: Int
	
	private var bus: Addressable
	
	private var decoded: (opcode: Int, address: Int, duration: Int, length: Int) = (0, 0, 0, 0)
	private var elapsedCycles = 0
	
	public init(bus: Addressable) {
		self.accumulator = .random(in: 0x00...0xff)
		self.x = .random(in: 0x00...0xff)
		self.y = .random(in: 0x00...0xff)
		self.status = .random()
		
		self.stackPointer = .random(in: 0x00...0xff)
		self.programCounter = .random(in: 0x0000...0xffff)
		
		self.bus = bus
	}
	
	/// Returns `true` when this CPU is in the first operation cycle; returns `false` otherwise.
	public var sync: Bool {
		return self.elapsedCycles == 0
	}
	
	/// Returns the dereferenced operand address of the current instruction in the program.
	public var operandAddress: Int? {
		return self.decoded.address
	}
	
	/// Resets this CPU.
	public mutating func reset() {
		self.stackPointer = 0xfd
		self.programCounter = self.readAddress(at: 0xfffc)
		
		self.decoded = self.decodeOperation(at: self.programCounter)
		self.elapsedCycles = 0
	}
	
	/// Advances CPU clock by 1 unit.
	public mutating func advanceClock() {
		self.elapsedCycles += 1
		
		if self.elapsedCycles == self.decoded.duration {
			self.programCounter += self.decoded.length
			self.executeOperation(code: self.decoded.opcode, address: self.decoded.address)
			
			self.decoded = self.decodeOperation(at: self.programCounter)
			self.elapsedCycles = 0
		}
	}
}


// MARK: -
// MARK: Operations
extension MOS6507 {
	/// Decodes operation at the specified address.
	///
	/// Returns a tupple with operation opcode, effective operand address, number of CPU cycles it
	/// takes to execute and length of its instruction in the program bytecode.
	private func decodeOperation(at address: Int) -> (opcode: Int, address: Int, duration: Int, length: Int) {
		let opcode = self.bus.read(at: address)
		let address = address + 0x1
		
		switch opcode {
			// MARK: implied addressing
		case 0x18, 0x38, 0x58, 0xb8, 0xd8, 0x78, 0x88, 0xa8, 0x98, 0xc8, 0xe8, 0xf8,
			0x0a, 0x2a, 0x4a, 0x6a, 0x8a, 0x9a, 0xaa, 0xba, 0xca, 0xea:
			return (opcode, -1, 2, 1)
		case 0x08, 0x48:
			return (opcode, -1, 3, 1)
		case 0x28, 0x68:
			return (opcode, -1, 4, 1)
		case 0x40, 0x60:
			return (opcode, -1, 6, 1)
		case 0x00:
			return (opcode, -1, 7, 1)
			
			// MARK: immediate addressing
		case 0xa2,
			0x09, 0x29, 0x49, 0x69, 0xa9, 0xc9, 0xe9,
			0xa0, 0xe0, 0xc0:
			return (opcode, address, 2, 2)
			
			// MARK: relative addressing
		case 0x10:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.negative] == false)
			return (opcode, address, 2 + cycles, 2)
		case 0x30:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.negative])
			return (opcode, address, 2 + cycles, 2)
		case 0x50:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.overflow] == false)
			return (opcode, address, 2 + cycles, 2)
		case 0x70:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.overflow])
			return (opcode, address, 2 + cycles, 2)
		case 0x90:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.carry] == false)
			return (opcode, address, 2 + cycles, 2)
		case 0xb0:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.carry])
			return (opcode, address, 2 + cycles, 2)
		case 0xd0:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.zero] == false)
			return (opcode, address, 2 + cycles, 2)
		case 0xf0:
			let (address, cycles) = self.readRelativeAddress(at: address, on: self.status[.zero])
			return (opcode, address, 2 + cycles, 2)
			
			// MARK: 0-page absolute addressing
		case 0x24, 0x84, 0xa4, 0xc4, 0xe4,
			0x05, 0x25, 0x45, 0x65, 0x85, 0xa5, 0xc5, 0xe5,
			0xa6, 0x86:
			let address = self.read0PageAddress(at: address)
			return (opcode, address, 3, 2)
			
		case 0x06, 0x26, 0x46, 0x66, 0xc6, 0xe6:
			let address = self.read0PageAddress(at: address)
			return (opcode, address, 5, 2)
			
			// MARK: 0-page x-indexed addressing
		case 0x94, 0xb4,
			0x15, 0x35, 0x55, 0x75, 0x95, 0xb5, 0xd5, 0xf5:
			let address = self.read0PageXIndexedAddress(at: address)
			return (opcode, address, 4, 2)
			
		case 0x16, 0x36, 0x56, 0x76, 0xd6, 0xf6:
			let address = self.read0PageXIndexedAddress(at: address)
			return (opcode, address, 6, 2)
			
			// MARK: 0-page y-indexed addressing
		case 0x96, 0xb6:
			let address = self.read0PageYIndexedAddress(at: address)
			return (opcode, address, 4, 2)
			
			// MARK: absolute addressing
		case 0x4c:
			let address = self.readAddress(at: address)
			return (opcode, address, 3, 3)
			
		case 0x2c, 0x8c, 0xac, 0xcc, 0xec,
			0x0d, 0x2d, 0x4d, 0x6d, 0x8d, 0xad, 0xcd, 0xed,
			0x8e, 0xae:
			let address = self.readAddress(at: address)
			return (opcode, address, 4, 3)
			
		case 0x20,
			0x0e, 0x2e, 0x4e, 0x6e, 0xce, 0xee:
			let address = self.readAddress(at: address)
			return (opcode, address, 6, 3)
			
			// MARK: absolute x-indexed addressing
		case 0xbc,
			0x1d, 0x3d, 0x5d, 0x7d, 0xbd, 0xdd, 0xfd:
			let (address, cycle) = self.readXIndexedAddress(at: address)
			return (opcode, address, 4 + cycle, 3)
			
		case 0x9d:
			let (address, _) = self.readXIndexedAddress(at: address)
			return (opcode, address, 5, 3)
			
		case 0x1e, 0x3e, 0x5e, 0x7e, 0xde, 0xfe:
			let (address, _) = self.readXIndexedAddress(at: address)
			return (opcode, address, 7, 3)
			
			// MARK: absolute y-indexed addressing
		case 0x19, 0x39, 0x59, 0x79, 0xb9, 0xd9, 0xf9,
			0xbe:
			let (address, cycle) = self.readYIndexedAddress(at: address)
			return (opcode, address, 4 + cycle, 3)
			
		case 0x99:
			let (address, _) = self.readYIndexedAddress(at: address)
			return (opcode, address, 5, 3)
			
			// MARK: indirect addressing
		case 0x6c:
			let address = self.readIndirectAddress(at: address)
			return (opcode, address, 5, 3)
			
			// MARK: indirect x-indexed addressing
		case 0x61, 0x21, 0xc1, 0x41, 0xa1, 0x01, 0xe1, 0x81:
			let address = self.readIndirectXIndexedAddress(at: address)
			return (opcode, address, 6, 2)
			
			// MARK: indirect y-indexed addressing
		case 0x11, 0x31, 0x51, 0x71, 0x91, 0xb1, 0xd1, 0xf1:
			let (address, cycle) = self.readIndirectYIndexedAddress(at: address)
			return (opcode, address, 5 + cycle, 2)
			
		default:
			let formatted = String(format: "%04x", address)
			fatalError("Unknown operation code: \(opcode) at $\(formatted)")
		}
	}
	
	/// Executes operation with the specified code and operand address.
	private mutating func executeOperation(code: Int, address: Int) {
		switch code {
			// MARK: adc
		case 0x61, 0x65, 0x69, 0x6d, 0x71, 0x75, 0x7d, 0x79:
			let operand = self.bus.read(at: address)
			let carry = self.status[.carry] ? 0x1 : 0x0
			var result = 0x0
			
			if self.status[.decimalMode] {
				var high = (self.accumulator / 0x10) + (operand / 0x10)
				var low = (self.accumulator % 0x10) + (operand % 0x10) + carry
				
				if low > 0x9 {
					high += 0x1
					low -= 0xa
				}
				
				result = high * 0x10 + low
				if result > 0x99 {
					result -= 0xa0
					self.status[.carry] = true
				} else {
					self.status[.carry] = false
				}
			} else {
				result = self.accumulator + operand + carry
				if result > 0xff {
					result -= 0x100
					self.status[.carry] = true
				} else {
					self.status[.carry] = false
				}
			}
			
			let overflow = (self.accumulator ^ result) & (operand ^ result)
			
			self.accumulator = result
			self.status[.overflow] = overflow[7]
			
			// MARK: and
		case 0x21, 0x25, 0x29, 0x2d, 0x31, 0x35, 0x39, 0x3d:
			let operand = self.bus.read(at: address)
			self.accumulator &= operand
			
			// MARK: asl (accumulator)
		case 0x0a:
			let carry = self.accumulator[7]
			self.accumulator = (self.accumulator << 1) & 0xff
			self.status[.carry] = carry
			
			// MARK: asl
		case 0x06, 0x0e, 0x16, 0x1e:
			let operand = self.bus.read(at: address)
			let carry = operand[7]
			let result = (operand << 1) & 0xff
			
			self.bus.write(result, at: address)
			self.status[.carry] = carry
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: bcc, bcs, beq, bmi, bne, bpl
		case 0x90, 0xb0, 0xf0, 0x30, 0xd0, 0x10:
			self.programCounter = address
			
			// MARK: bit:
		case 0x24, 0x2c:
			let operand = self.bus.read(at: address)
			let result = self.accumulator & operand
			
			self.status[.overflow] = operand[6]
			self.status[.zero] = result == 0x0
			self.status[.negative] = operand[7]
			
			//brk
		case 0x00:
			self.pushStack(self.programCounter >> 8)
			self.pushStack(self.programCounter & 0xff)
			self.pushStack(self.status.rawValue)
			
			let low = self.bus.read(at: 0xfffe)
			let high = self.bus.read(at: 0xffff)
			self.programCounter = (high << 8) | low
			
			// MARK: bvc
		case 0x50:
			if self.status[.overflow] == false {
				self.programCounter = address
			}
			// MARK: bvs
		case 0x70:
			if self.status[.overflow] {
				self.programCounter = address
			}
			
			// MARK: clc
		case 0x18:
			self.status[.carry] = false
			// MARK: cld
		case 0xd8:
			self.status[.decimalMode] = false
			// MARK: cli
		case 0x58:
			self.status[.interruptDisabled] = false
			// MARK: clv
		case 0xb8:
			self.status[.overflow] = false
			
			// MARK: cmp
		case 0xc1, 0xc5, 0xc9, 0xcd, 0xd1, 0xd5, 0xd9, 0xdd:
			let operand = self.bus.read(at: address)
			let result = self.accumulator - operand
			
			self.status[.carry] = result >= 0x0
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: cpx
		case 0xe0, 0xe4, 0xec:
			let operand = self.bus.read(at: address)
			let result = self.x - operand
			
			self.status[.carry] = result >= 0x0
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: cpy
		case 0xc0, 0xc4, 0xcc:
			let operand = self.bus.read(at: address)
			let result = self.y - operand
			
			self.status[.carry] = result >= 0x0
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: dec
		case 0xc6, 0xce, 0xd6, 0xde:
			let operand = self.bus.read(at: address)
			let result = (operand - 0x1) & 0xff
			
			self.bus.write(result, at: address)
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: dex
		case 0xca:
			self.x = (self.x - 0x1) & 0xff
			// MARK: dey
		case 0x88:
			self.y = (self.y - 0x1) & 0xff
			
			// MARK: eor
		case 0x41, 0x45, 0x49, 0x4d, 0x51, 0x55, 0x59, 0x5d:
			let operand = self.bus.read(at: address)
			self.accumulator ^= operand
			
			// MARK: inc
		case 0xe6, 0xee, 0xf6, 0xfe:
			let operand = self.bus.read(at: address)
			let result = (operand + 0x1) & 0xff
			
			self.bus.write(result, at: address)
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: inx
		case 0xe8:
			self.x = (self.x + 0x1) & 0xff
			// MARK: iny
		case 0xc8:
			self.y = (self.y + 0x1) & 0xff
			
			// MARK: jmp
		case 0x4c, 0x6c:
			self.programCounter = address
			
			// MARK: jsr
		case 0x20:
			// NOTE: JSR pushes PC+1 onto stack, but not PC+2 as it should be,
			// and there's an extra PC+1 at the end of RTS, which then
			// correctly aligns return to the beginning of next instruction;
			let returnAddress = self.programCounter - 1
			
			self.pushStack(returnAddress >> 8)
			self.pushStack(returnAddress & 0xff)
			self.programCounter = address
			
			// MARK: lda
		case 0xa1, 0xa5, 0xa9, 0xad, 0xb1, 0xb5, 0xb9, 0xbd:
			self.accumulator = self.bus.read(at: address)
			// MARK: ldx
		case 0xa2, 0xa6, 0xae, 0xb6, 0xbe:
			self.x = self.bus.read(at: address)
			// MARK: ldy
		case 0xa0, 0xa4, 0xac, 0xb4, 0xbc:
			self.y = self.bus.read(at: address)
			
			// MARK: lsr (accumulator)
		case 0x4a:
			let carry = self.accumulator[0]
			self.accumulator >>= 1
			self.status[.carry] = carry
			
			// MARK: lsr
		case 0x46, 0x4e, 0x56, 0x5e:
			let operand = self.bus.read(at: address)
			let result = operand << 1
			
			self.bus.write(result & 0xff, at: address)
			self.status[.carry] = result[8]
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: nop
		case 0xea:
			break
			
			// MARK: ora
		case 0x01, 0x05, 0x09, 0x0d, 0x11, 0x15, 0x19, 0x1d:
			let operand = self.bus.read(at: address)
			self.accumulator |= operand
			
			// MARK: pha
		case 0x48:
			self.pushStack(self.accumulator)
			// MARK: php
		case 0x08:
			self.pushStack(self.status.rawValue)
			// MARK: pla
		case 0x68:
			self.accumulator = self.pullStack()
			// MARK: plp
		case 0x28:
			let status = self.pullStack()
			self.status = Status(rawValue: status)
			
			// MARK: rol (accumulator)
		case 0x2a:
			let carry = self.accumulator[7]
			var result = self.accumulator << 1
			result[0] = self.status[.carry]
			
			self.accumulator = result & 0xff
			self.status[.carry] = carry
			
			// MARK: rol
		case 0x26, 0x2e, 0x36, 0x3e:
			let operand = self.bus.read(at: address)
			var result = operand << 1
			result[0] = self.status[.carry]
			
			self.bus.write(result & 0xff, at: address)
			self.status[.carry] = operand[7]
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: ror (accumulator)
		case 0x6a:
			let carry = self.accumulator[0]
			var result = self.accumulator >> 1
			result[7] = self.status[.carry]
			
			self.accumulator = result
			self.status[.carry] = carry
			
			// MARK: ror
		case 0x66, 0x6e, 0x76, 0x7e:
			let operand = self.bus.read(at: address)
			var result = operand >> 1
			result[7] = self.status[.carry]
			
			self.bus.write(result, at: address)
			self.status[.carry] = operand[0]
			self.status[.zero] = result == 0x0
			self.status[.negative] = result[7]
			
			// MARK: rti
		case 0x40:
			let status = self.pullStack()
			let low = self.pullStack()
			let high = self.pullStack()
			
			self.status = Status(rawValue: status)
			self.programCounter = (high << 8) | low
			
			// MARK: rts
		case 0x60:
			let low = self.pullStack()
			let high = self.pullStack()
			
			self.programCounter = (high << 8) | low
			self.programCounter += 1
			
			// MARK: sbc
		case 0xe1, 0xe5, 0xe9, 0xed, 0xf1, 0xf5, 0xf9, 0xfd:
			let operand = self.bus.read(at: address)
			let borrow = self.status[.carry] ? 0x0: 0x1
			var result = 0x0
			
			if self.status[.decimalMode] {
				var high = (self.accumulator / 0x10) - (operand / 0x10)
				var low = (self.accumulator % 0x10) - (operand % 0x10) - borrow
				
				if low < 0x0 {
					high -= 0x1
					low += 0xa
				}
				
				result = high * 0x10 + low
				if result < 0x0 {
					result += 0xa0
					self.status[.carry] = false
				} else {
					self.status[.carry] = true
				}
			} else {
				result = self.accumulator - operand - borrow
				if result < 0x0 {
					result += 0x100
					self.status[.carry] = false
				} else {
					self.status[.carry] = true
				}
			}
			
			let overflow = (self.accumulator ^ result) & (operand ^ result)
			
			self.accumulator = result
			self.status[.overflow] = overflow[7]
			
			// MARK: sec
		case 0x38:
			self.status.insert(.carry)
			// MARK: sed
		case 0xf8:
			self.status.insert(.decimalMode)
			// MARK: sei
		case 0x78:
			self.status.insert(.overflow)
			
			// MARK: sta
		case 0x81, 0x85, 0x8d, 0x91, 0x95, 0x99, 0x9d:
			self.bus.write(self.accumulator, at: address)
			// MARK: stx
		case 0x86, 0x8e, 0x96:
			self.bus.write(self.x, at: address)
			// MARK: sty
		case 0x84, 0x8c, 0x94:
			self.bus.write(self.y, at: address)
			
			// MARK: tax
		case 0xaa:
			self.x = self.accumulator
			// MARK: tay
		case 0xa8:
			self.y = self.accumulator
			// MARK: tsx
		case 0xba:
			self.x = self.stackPointer
			// MARK: txa
		case 0x8a:
			self.accumulator = self.x
			// MARK: txs
		case 0x9a:
			self.stackPointer = self.x
			// MARK: tya
		case 0x98:
			self.accumulator = self.y
			
		default:
			fatalError("Unknown opcode: \(code).")
		}
	}
	
	/// Pushes the specified value onto stack and updates the stack pointer.
	private mutating func pushStack(_ data: Int) {
		let address = self.stackPointer + 0x0100
		self.bus.write(data, at: address)
		
		self.stackPointer -= 1
	}
	
	/// Pulls the last pushed value from the stack and updates the stack pointer.
	private mutating func pullStack() -> Int {
		self.stackPointer += 1
		
		let address = self.stackPointer + 0x0100
		let data = self.bus.read(at: address)
		
		return data
	}
}


// MARK: -
// MARK: Memory addressing
extension MOS6507 {
	/// Resolves address, using reative addressing mode, from offset at the specified address, based on
	/// the specified branching condition.
	///
	/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
	/// address.
	private func readRelativeAddress(at address: Int, on condition: Bool) -> (address: Int, cycles: Int) {
		// when branch is not taken, program counter increments to +1
		// relative to offset operand address
		guard condition else {
			return (address + 0x1, 0)
		}
		
		let page1 = address >> 8
		let offset = self.bus.read(at: address)
		let address = address + 0x1 + Int(signed: offset)
		
		let page2 = address >> 8
		let cycle = page1 == page2 ? 1 : 2
		return (address, cycle)
	}
	
	/// Reads 0-page address at the specified address in memory.
	private func read0PageAddress(at address: Int) -> Int {
		return self.bus.read(at: address)
	}
	
	/// Resolves address, using 0-page x-indexed addressing mode, reading from the specified address
	/// in memory.
	private func read0PageXIndexedAddress(at address: Int) -> Int {
		var address = self.read0PageAddress(at: address)
		address += self.x
		address &= 0xff
		
		return address
	}
	
	/// Resolves address, using 0-page y-indexed addressing mode, reading from the specified address
	/// in memory.
	private func read0PageYIndexedAddress(at address: Int) -> Int {
		var address = self.read0PageAddress(at: address)
		address += self.y
		address &= 0xff
		
		return address
	}
	
	/// Reads address at the specified address in memory.
	private func readAddress(at address: Int) -> Int {
		let low = self.bus.read(at: address)
		let high = self.bus.read(at: address + 0x1)
		let address = (high << 8) | low
		
		return address
	}
	
	/// Reads address, using absolute, x-indexed addressing mode, at the specified address in memory.
	///
	/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
	/// address.
	private func readXIndexedAddress(at address: Int) -> (address: Int, cycle: Int) {
		var address = self.readAddress(at: address)
		let page1 = address >> 8
		address += self.x
		
		let page2 = address >> 8
		let cycle = page1 == page2 ? 0 : 1
		return (address, cycle)
	}
	
	/// Reads address, using absolute, y-indexed addressing mode, at the specified address in memory.
	///
	/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
	/// address.
	private func readYIndexedAddress(at address: Int) -> (address: Int, cycle: Int) {
		var address = self.readAddress(at: address)
		let page1 = address >> 8
		address += self.y
		
		let page2 = address >> 8
		let cycle = page1 == page2 ? 0 : 1
		return (address, cycle)
	}
	
	/// Reads address, using indirect addressing mode, at the specified address in memory.
	private func readIndirectAddress(at address: Int) -> Int {
		var address = self.readAddress(at: address)
		address = self.readAddress(at: address)
		
		return address
	}
	
	/// Reads address, using x-indexed indirect addressing mode, at the specified address in memory.
	private func readIndirectXIndexedAddress(at address: Int) -> Int {
		var address = self.read0PageXIndexedAddress(at: address)
		address = self.readAddress(at: address)
		
		return address
	}
	
	/// Reads address, using indirect y-indexed addressing mode, at the specified address in memory.
	///
	/// Additionally returns the number of extra CPU cycles it takes to read and resolve the effective
	/// address.
	private func readIndirectYIndexedAddress(at address: Int) -> (address: Int, cycle: Int) {
		var address = self.read0PageAddress(at: address)
		address = self.readAddress(at: address)
		
		let page1 = address >> 8
		address += self.y
		
		let page2 = address >> 8
		let cycle = page1 == page2 ? 0 : 1
		return (address, cycle)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension MOS6507.Status {
	static func random() -> Self {
		return MOS6507.Status(rawValue: .random(in: 0x00...0xff))
	}
}

extension Int {
	public subscript(bit: Int) -> Bool {
		get {
			let mask = 1 << bit
			return self & mask == mask
		}
		set {
			let mask = 1 << bit
			if newValue {
				self |= mask
			} else {
				self &= ~mask
			}
		}
	}
	
	init(signed value: Int) {
		self = value[7]
		? value - 0x100
		: value
	}
}
