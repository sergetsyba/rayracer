//
//  CPU.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class MOS6507 {
	private var operations: [Int: Operation] = [:]
	
	private(set) public var accumulator: Int
	private(set) public var x: Int
	private(set) public var y: Int
	private(set) public var status: Status
	private(set) public var stackPointer: Int
	private(set) public var programCounter: Address
	
	private var bus: Bus
	var ready: Bool = true
	var cachedOperation: (() -> Void)? = nil
	
	public init(bus: any Bus) {
		self.accumulator = .randomWord
		self.x = .randomWord
		self.y = .randomWord
		self.status = .random
		
		self.stackPointer = .randomWord
		self.programCounter = .randomAddress
		self.bus = bus
	}
	
	/// Resets this CPU.
	public func reset() {
		self.status.interruptDisabled = true
		
		self.programCounter = Address(
			low: self.bus.read(at: 0xfffe),
			high: self.bus.read(at: 0xfffd))
	}
	
	/// Executes program instructions until it reaches one at any of the sepcified addresses.
	public func resume(until breakpoints: [Address]) {
		while !breakpoints.contains(self.programCounter) {
			self.executeNextInstruction()
		}
	}
}


// MARK: -
public extension MOS6507 {
	/// Returns the number of CPU cycles it will take to execute the next instruction in the program.
	var nextExecutionDuration: Int {
		let opcode = self.bus.read(at: self.programCounter)
		guard let (addressing, programOffset) = self.addressing(for: opcode),
			  let (operation, cycles2) = self.operation(for: opcode) else {
			// TODO: message
			fatalError()
		}
		
		let (operandAddress, cycles1) = addressing(self.programCounter + 1)
		self.cachedOperation = { [unowned self] in
			self.programCounter += programOffset
			operation(operandAddress)
		}
		
		return 1 + cycles1 + cycles2
	}
	
	/// Executes the next instruction in the program.
	func executeNextInstruction() {
		if let operation = self.cachedOperation {
			operation()
		}
	}
}


// MARK: -
// MARK: Instruction processing
private extension MOS6507 {
	/// Returns part of operation for the specified opcode, which resolves its operand address,
	/// as well as the number of bytes its instruction takes in a compiled program.
	func addressing(for opcode: Int) -> ((Address) -> (Address, Int), Int)? {
		switch opcode {
		case 0x00, 0x08, 0x0a, 0x18, 0x28, 0x2a, 0x38, 0x40,
			0x48, 0x4a, 0x58, 0x60, 0x68, 0x6a, 0x78, 0x88,
			0x8a, 0x98, 0x9a, 0xa8, 0xaa, 0xb8, 0xba, 0xc8,
			0xca, 0xd8, 0xe8, 0xea, 0xf8:
			// MARK: Implied
			return ({
				return ($0, 1)
			}, 1)
		case 0x02, 0x09, 0x22, 0x29, 0x42, 0x49, 0x62, 0x69,
			0x80, 0x82, 0x89, 0xa0, 0xa2, 0xa9, 0xc0, 0xc2,
			0xc9, 0xe0, 0xe2, 0xe9:
			// MARK: Immediate
			return ({
				return ($0, 0)
			}, 2)
			
		case 0x0c, 0x0d, 0x0e, 0x20, 0x2c, 0x2d, 0x2e, 0x4c,
			0x4d, 0x4e, 0x6c, 0x6d, 0x6e, 0x8c, 0x8d, 0x8e,
			0xac, 0xad, 0xae, 0xcc, 0xcd, 0xce, 0xec, 0xed,
			0xee:
			// MARK: Absolute
			return ({ [unowned self] in
				let address = Address(
					low: self.bus.read(at: $0),
					high: self.bus.read(at: $0 + 1))
				
				return (address, 2)
			}, 3)
			
		case 0x1c, 0x1d, 0x1e, 0x3c, 0x3d, 0x3e, 0x5c, 0x5d,
			0x5e, 0x7c, 0x7d, 0x7e, 0x9c, 0x9d, 0x9e, 0xbc,
			0xbd, 0xdc, 0xdd, 0xde, 0xfc, 0xfd, 0xfe:
			// MARK: Absolute, X-indexed
			return ({ [unowned self] in
				var address = Address(
					low: self.bus.read(at: $0),
					high: self.bus.read(at: $0 + 1))
				
				let page = address.high
				address += self.x
				
				let cycles = address.high == page ? 2 : 3
				return (address, cycles)
			}, 3)
			
		case 0x19, 0x39, 0x59, 0x79, 0x99, 0xb9, 0xbe, 0xd9,
			0xf9:
			// MARK: Absolute, Y-indexed
			return ({ [unowned self] in
				var address = Address(
					low: self.bus.read(at: $0),
					high: self.bus.read(at: $0 + 1))
				
				let page = address.high
				address += self.y
				
				let cycles = address.high == page ? 2 : 3
				return (address, cycles)
			}, 3)
			
		case 0x04, 0x05, 0x06, 0x24, 0x25, 0x26, 0x44, 0x45,
			0x46, 0x64, 0x65, 0x66, 0x84, 0x85, 0x86, 0xa4,
			0xa5, 0xa6, 0xc4, 0xc5, 0xc6, 0xe4, 0xe5, 0xe6:
			// MARK: Zero-page
			return ({ [unowned self] in
				let address = Address(
					low: self.bus.read(at: $0),
					high: 0x00)
				
				return (address, 1)
			}, 2)
			
		case 0x14, 0x15, 0x16, 0x34, 0x35, 0x36, 0x54, 0x55,
			0x56, 0x74, 0x75, 0x76, 0x94, 0x95, 0xb4, 0xb5,
			0xd4, 0xd5, 0xd6, 0xf4, 0xf5, 0xf6:
			// MARK: Zero-page, X-indexed
			return ({ [unowned self] in
				var address = Address(
					low: self.bus.read(at: $0),
					high: 0x00)
				
				address.low += self.x
				return (address, 2)
			}, 2)
			
		case 0x96, 0xb6:
			// MARK: Zero-page, Y-indexed
			return ({ [unowned self] in
				var address = Address(
					low: self.bus.read(at: $0),
					high: 0x00)
				
				address.low += self.y
				return (address, 2)
			}, 2)
			
		case 0x01, 0x21, 0x41, 0x61, 0x81, 0xa1, 0xc1, 0xe1:
			// MARK: X-indexed, Indirect
			return ({ [unowned self] in
				var address = Address(
					low: self.bus.read(at: $0),
					high: 0x00)
				
				address.low += self.x
				address = Address(
					low: self.bus.read(at: address),
					high: self.bus.read(at: address + 1))
				
				return (address, 4)
			}, 2)
			
		case 0x11, 0x31, 0x51, 0x71, 0x91, 0xb1, 0xd1, 0xf1:
			// MARK: Indirect, Y-indexed
			return ({ [unowned self] in
				var address = Address(
					low: self.bus.read(at: $0 + 1),
					high: 0x00)
				
				address = Address(
					low: self.bus.read(at: address),
					high: self.bus.read(at: address + 1))
				
				let page = address.high
				address += self.y
				
				let cycles = address.high == page ? 4 : 5
				return (address, cycles)
			}, 2)
			
		case 0x10, 0x30, 0x50, 0x70, 0x90, 0xb0, 0xd0, 0xf0:
			// MARK: Relative
			return ({
				let offset = self.bus.read(at: $0)
				var address = self.programCounter + 2
				
				let page = address.high
				address += Int(signedWord: offset)
				
				let cycles = address.high == page ? 2 : 3
				return (address, cycles)
			}, 2)
			
		default:
			return nil
		}
	}
	
	/// Returns part of operation for the specififed opcode, without its operand address resolution,
	/// as well as the amount of CPU cycles it will take to perform this part.
	func operation(for opcode: Int) -> ((Address) -> Void, Int)? {
		switch opcode {
		case 0x69, 0x65, 0x75, 0x6d, 0x7d, 0x79, 0x61, 0x71:
			// MARK: ADC
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let carry = self.status.carry ? 0x01 : 0x00
				var result = 0x00
				
				if self.status.decimalMode {
					var high = (self.accumulator / 0x10) + (operand / 0x10)
					var low = (self.accumulator % 0x10) + (operand % 0x10) + carry
					
					if low > 0x09 {
						high += 0x01
						low -= 0x0a
					}
					
					var result = high * 0x10 + low
					if result > 0x99 {
						self.status.carry = true
						result -= 0xa0
					}
				} else {
					result = self.accumulator + operand + carry
					if result > 0xff {
						self.status.carry = true
						result -= 0x100
					}
				}
				
				let overflow = (self.accumulator ^ result) & (operand ^ result)
				
				self.accumulator = result
				self.status.overflow = overflow[7]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x29, 0x25, 0x35, 0x2D, 0x3D, 0x39, 0x21, 0x31:
			// MARK: AND
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.accumulator & operand
				
				self.accumulator = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 1)
			
		case 0x0a:
			// MARK: ASL (accumulator)
			return ({ [unowned self] _ in
				let result = self.accumulator << 1
				
				self.accumulator = result & 0xff
				self.status.carry = result[8]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x06, 0x16, 0x0e, 0x1e:
			// MARK: ASL
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = operand << 1
				
				self.bus.write(result & 0xff, at: $0)
				self.status.carry = result[8]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 2)
			
		case 0x90:
			// MARK: BCC
			return ({ [unowned self] in
				if self.status.carry == false {
					self.programCounter = $0
				}
			}, 0)
			
		case 0xb0:
			// MARK: BCS
			return ({ [unowned self] in
				if self.status.carry {
					self.programCounter = $0
				}
			}, 0)
			
		case 0xf0:
			// MARK: BEQ
			return ({ [unowned self] in
				if self.status.zero {
					self.programCounter = $0
				}
			}, 0)
			
		case 0x24, 0x2c:
			// MARK: BIT
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.accumulator & operand
				
				self.status.overflow = operand[6]
				self.status.zero = result == 0x00
				self.status.negative = operand[7]
			}, 1)
			
		case 0x30:
			// MARK: BMI
			return ({ [unowned self] in
				if self.status.negative {
					self.programCounter = $0
				}
			}, 0)
			
		case 0xd0:
			// MARK: BNE
			return ({ [unowned self] in
				if self.status.zero == false {
					self.programCounter = $0
				}
			}, 0)
			
		case 0x10:
			// MARK: BPL
			return ({ [unowned self] in
				if self.status.negative == false {
					self.programCounter = $0
				}
			}, 0)
			
		case 0x00:
			// MARK: BRK
			return ({ [unowned self] _ in
				self.pushStack(self.programCounter.high)
				self.pushStack(self.programCounter.low)
				self.pushStack(self.status.rawValue)
				
				self.programCounter = Address(
					low: self.bus.read(at: 0xfffe),
					high: self.bus.read(at: 0xffff))
			}, 6)
			
		case 0x50:
			// MARK: BVC
			return ({ [unowned self] in
				if self.status.overflow == false {
					self.programCounter = $0
				}
			}, 0)
			
		case 0x70:
			// MARK: BVS
			return ({ [unowned self] in
				if self.status.overflow {
					self.programCounter = $0
				}
			}, 0)
			
		case 0x18:
			// MARK: CLC
			return ({ [unowned self] _ in
				self.status.carry = false
			}, 0)
			
		case 0xd8:
			// MARK: CLD
			return ({ [unowned self] _ in
				self.status.decimalMode = false
			}, 0)
			
		case 0x58:
			// MARK: CLI
			return ({ [unowned self] _ in
				self.status.interruptDisabled = false
			}, 0)
			
		case 0xb8:
			// MARK: CLV
			return ({ [unowned self] _ in
				self.status.overflow = false
			}, 0)
			
		case 0xc9, 0xc5, 0xd5, 0xcd, 0xdd, 0xd9, 0xc1, 0xd1:
			// MARK: CMP
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.accumulator - operand
				
				self.status.carry = result >= 0x00
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 1)
			
		case 0xe0, 0xe4, 0xec:
			// MARK: CPX
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.x - operand
				
				self.status.carry = result >= 0x00
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 1)
			
		case 0xc0, 0xc4, 0xcc:
			// MARK: CPY
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.y - operand
				
				self.status.carry = result >= 0x00
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 1)
			
		case 0xc6, 0xd6, 0xce, 0xde:
			// MARK: DEC
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				var result = operand - 0x01
				if result < 0x00 {
					result = 0xff
				}
				
				self.bus.write(result, at: $0)
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 2)
			
		case 0xca:
			// MARK: DEX
			return ({ [unowned self] _ in
				var result = self.x - 0x01
				if result < 0x00 {
					result = 0xff
				}
				
				self.x = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x88:
			// MARK: DEY
			return ({ [unowned self] _ in
				var result = self.y - 0x01
				if result < 0x00 {
					result = 0xff
				}
				
				self.y = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x49, 0x45, 0x55, 0x4d, 0x5d, 0x59, 0x41, 0x51:
			// MARK: EOR
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.accumulator ^ operand
				
				self.accumulator = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 1)
			
		case 0xe6, 0xf6, 0xee, 0xfe:
			// MARK: INC
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				var result = operand + 0x01
				if result > 0xff {
					result = 0x00
				}
				
				self.bus.write(result, at: $0)
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 2)
			
		case 0xe8:
			// MARK: INX
			return ({ [unowned self] _ in
				var result = self.x + 0x01
				if result > 0xff {
					result = 0x00
				}
				
				self.x = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0xc8:
			// MARK: INY
			return ({ [unowned self] _ in
				var result = self.y + 0x01
				if result > 0xff {
					result = 0x00
				}
				
				self.y = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x4c, 0x6c:
			// MARK: JMP
			return ({ [unowned self] in
				self.programCounter = $0
			}, 0)
			
		case 0x20:
			// MARK: JSR
			return ({ [unowned self] in
				self.pushStack(self.programCounter.high)
				self.pushStack(self.programCounter.low)
				self.programCounter = $0
			}, 3)
			
		case 0xa9, 0xa5, 0xb5, 0xad, 0xbd, 0xb9, 0xa1, 0xb1:
			// MARK: LDA
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				
				self.accumulator = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 1)
			
		case 0xa2, 0xa6, 0xb6, 0xae, 0xbe:
			// MARK: LDX
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				
				self.x = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 1)
			
		case 0xa0, 0xa4, 0xb4, 0xac, 0xbc:
			// MARK: LDY
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				
				self.y = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 1)
			
		case 0x4a:
			// MARK: LSR (accumulator)
			return ({ [unowned self] _ in
				let carry = self.accumulator[0]
				let result = self.accumulator >> 1
				
				self.accumulator = result
				self.status.carry = carry
				self.status.zero = result == 0x00
				self.status.negative = false
			}, 0)
			
		case 0x46, 0x56, 0x4e, 0x5e:
			// MARK: LSR
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = operand >> 1
				
				self.bus.write(result, at: $0)
				self.status.carry = operand[0]
				self.status.zero = result == 0x00
				self.status.negative = false
			}, 3)
			
		case 0xea:
			// MARK: NOP
			return ({ _ in
			}, 0)
			
		case 0x09, 0x05, 0x15, 0x0d, 0x1d, 0x19, 0x01, 0x11:
			// MARK: ORA
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let result = self.accumulator & operand
				
				self.accumulator = result
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 1)
			
		case 0x48:
			// MARK: PHA
			return ({ [unowned self] _ in
				self.pushStack(self.accumulator)
			}, 2)
			
		case 0x08:
			// MARK: PHP
			return ({ [unowned self] _ in
				self.pushStack(self.status.rawValue)
			}, 2)
			
		case 0x68:
			// MARK: PLA
			return ({ [unowned self] _ in
				self.accumulator = self.pullStack()
			}, 3)
			
		case 0x28:
			// MARK: PLP
			return ({ [unowned self] _ in
				self.status = Status(
					rawValue: self.pullStack())!
			}, 3)
			
		case 0x2a:
			// MARK: ROL (accumulator)
			return ({ [unowned self] _ in
				let operand = self.accumulator
				var result = operand << 1
				result[0] = self.status.carry
				
				self.accumulator = result & 0xff
				self.status.carry = operand[7]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x26, 0x36, 0x2e, 0x3e:
			// MARK: ROL
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				var result = operand << 1
				result[0] = self.status.carry
				
				self.bus.write(result & 0xff, at: $0)
				self.status.carry = operand[7]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 3)
			
		case 0x6a:
			// MARK: ROR (accumulator)
			return ({ [unowned self] _ in
				let operand = self.accumulator
				var result = operand >> 1
				result[7] = self.status.carry
				
				self.accumulator = result
				self.status.carry = operand[0]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x66, 0x76, 0x6e, 0x7e:
			// MARK: ROR
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				var result = operand >> 1
				result[7] = self.status.carry
				
				self.bus.write(result, at: $0)
				self.status.carry = operand[0]
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 3)
			
		case 0x40:
			// MARK: RTI
			return ({ [unowned self] _ in
				self.status = Status(
					rawValue: self.pullStack())!
				
				self.programCounter = Address(
					low: self.pullStack(),
					high: self.pullStack())
			}, 5)
			
		case 0x60:
			// MARK: RTS
			return ({ [unowned self] _ in
				self.programCounter = Address(
					low: self.pullStack(),
					high: self.pullStack())
			}, 5)
			
		case 0xe9, 0xe5, 0xf5, 0xed, 0xfd, 0xe1, 0xf1:
			// MARK: SBC
			return ({ [unowned self] in
				let operand = self.bus.read(at: $0)
				let carry = self.status.carry ? 0x01: 0x00
				var result = 0x00
				
				if self.status.decimalMode {
					var high = (self.accumulator / 0x10) - (operand / 0x10)
					var low = (self.accumulator % 0x10) - (operand % 0x10) - carry
					
					if low < 0x00 {
						high -= 0x01
						low += 0x0a
					}
					
					result = high * 0x10 + low
					if result < 0x00 {
						self.status.carry = true
						result += 0xa0
					}
				} else {
					result = self.accumulator - operand - carry
					if result < 0x00 {
						self.status.carry = true
						result += 0x100
					}
				}
				
				let overflow = (self.accumulator ^ result) & (operand ^ result)
				
				self.accumulator = result
				self.status.overflow = overflow[7]
				self.status.carry = result >= 0x00
				self.status.zero = result == 0x00
				self.status.negative = result[7]
			}, 0)
			
		case 0x38:
			// MARK: SEC
			return ({ [unowned self] _ in
				self.status.carry = true
			}, 0)
			
		case 0xf8:
			// MARK: SED
			return ({ [unowned self] _ in
				self.status.decimalMode = true
			}, 0)
			
		case 0x78:
			// MARK: SEI
			return ({ [unowned self] _ in
				self.status.interruptDisabled = true
			}, 0)
			
		case 0x85, 0x95, 0x8d, 0x9d, 0x99, 0x81, 0x91:
			// MARK: STA
			return ({ [unowned self] in
				self.bus.write(self.accumulator, at: $0)
			}, 1)
			
		case 0x86, 0x96, 0x8e:
			// MARK: STX
			return ({ [unowned self] in
				self.bus.write(self.x, at: $0)
			}, 1)
			
		case 0x84, 0x94, 0x8c:
			// MARK: STY
			return ({ [unowned self] in
				self.bus.write(self.y, at: $0)
			}, 1)
			
		case 0xaa:
			// MARK: TAX
			return ({ [unowned self] _ in
				let operand = self.accumulator
				
				self.x = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 0)
			
		case 0xa8:
			// MARK: TAY
			return ({ [unowned self] _ in
				let operand = self.accumulator
				
				self.y = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 0)
			
		case 0xba:
			// MARK: TSX
			return ({ [unowned self] _ in
				let operand = self.stackPointer
				
				self.x = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 0)
			
		case 0x8a:
			// MARK: TXA
			return ({ [unowned self] _ in
				let operand = self.x
				
				self.accumulator = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 0)
			
		case 0x9a:
			// MARK: TXS
			return ({ [unowned self] _ in
				let operand = self.x
				
				self.stackPointer = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 0)
			
		case 0x98:
			// MARK: TYA
			return ({ [unowned self] _ in
				let operand = self.y
				
				self.accumulator = operand
				self.status.zero = operand == 0x00
				self.status.negative = operand[7]
			}, 0)
			
		default:
			return nil
		}
	}
	
	/// Pushes the specified value onto stack and updates the stack pointer.
	private func pushStack(_ data: Int) {
		let address = self.stackPointer + 0x0100
		self.bus.write(data, at: address)
		
		self.stackPointer -= 1
	}
	
	/// Pulls the last pushed value from the stack and updates the stack pointer.
	private func pullStack() -> Int {
		self.stackPointer += 1
		
		let address = self.stackPointer + 0x0100
		let data = self.bus.read(at: address)
		
		return data
	}
}


// MARK: -
// MARK: Type definitions
public extension MOS6507 {
	class Status: RawRepresentable {
		public var carry: Bool
		public var zero: Bool
		public var interruptDisabled: Bool
		public var decimalMode: Bool
		public var `break`: Bool
		public var overflow: Bool
		public var negative: Bool
		
		required init() {
			self.carry = false
			self.zero = false
			self.interruptDisabled = false
			self.decimalMode = false
			self.break = false
			self.overflow = false
			self.negative = false
		}
		
		public required init?(rawValue: Int) {
			self.carry = rawValue[0]
			self.zero = rawValue[1]
			self.interruptDisabled = rawValue[2]
			self.decimalMode = rawValue[3]
			self.break = rawValue[4]
			self.overflow = rawValue[6]
			self.negative = rawValue[7]
		}
		
		public var rawValue: Int {
			var value = 0x00
			value[0] = self.carry
			value[1] = self.zero
			value[2] = self.interruptDisabled
			value[3] = self.decimalMode
			value[4] = self.break
			value[6] = self.overflow
			value[7] = self.negative
			
			return value
		}
		
		static var random: Self {
			return .init(rawValue: .randomWord)!
		}
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Address {
	init(low: Int, high: Int) {
		self = Self(high) * 0x100 + Self(low)
	}
	
	var low: Int {
		get {
			return self % 0x100
		}
		set {
			self = self.high * 0x100 + newValue
		}
	}
	
	var high: Int {
		get {
			return self / 0x100
		}
		set {
			self = newValue * 0x100 + self.low
		}
	}
}

extension Int {
	static var randomWord: Self {
		return Self.random(in: 0x00...0xff)
	}
	
	static var randomAddress: Self {
		return Self.random(in: 0x0000...0xffff)
	}
	
	init(signedWord value: Int) {
		self = value > 0x7f
		? value - 0x100
		: value
	}
	
	init(signedWord value: UInt8) {
		self = value > 0x7f
		? Int(value) - 0x100
		: Int(value)
	}
	
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
