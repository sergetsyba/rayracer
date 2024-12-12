//
//  MOS6507.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class MOS6507 {
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
	private var decoded: (operation: () -> Void, duration: Int, operandAddress: Int?) = ({}, 0, nil)
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
	
	/// Resets this CPU.
	public func reset() {
		self.stackPointer = 0xfd
		self.programCounter = Int(
			low: self.bus.read(at: 0xfffc),
			high: self.bus.read(at: 0xfffd))
		
		self.decoded = self.decodeOperation(at: self.programCounter)
		self.elapsedCycles = 0
	}
	
	/// Advances CPU clock by 1 unit.
	public func advanceClock() {
		self.elapsedCycles += 1
		
		if self.elapsedCycles == self.decoded.duration {
			self.decoded.operation()
			self.decoded = self.decodeOperation(at: self.programCounter)
			self.elapsedCycles = 0
		}
	}
}


// MARK: -
// MARK: Operation decoding
extension MOS6507 {
	/// Returns the dereferenced operand address of the current instruction in the program.
	public var operandAddress: Int? {
		return self.decoded.operandAddress
	}
	
	/// Returns the next operation in the program and the amount of CPU cycles it will take to execute.
	private func decodeOperation(at address: Int) -> (() -> Void, Int, Int?) {
		let opcode = self.bus.read(at: self.programCounter)
		
		// NOTE: performance benchmarks showed that replacing this switch
		// statement with a function array results in no performance
		// improvements
		switch opcode {
			// MARK: ADC
		case 0x69: return self.withImmediateAddressing(
			self.addToAccumulator(valueAt:))
		case 0x65: return self.with0PageAddressing(
			self.addToAccumulator(valueAt:), cycles: 3)
		case 0x75: return self.with0PageXIndexedAddressing(
			self.addToAccumulator(valueAt:), cycles: 4)
		case 0x6d: return self.withAbsoluteAddressing(
			self.addToAccumulator(valueAt:), cycles: 4)
		case 0x7d: return self.withAbsoluteXIndexedAddressing(
			self.addToAccumulator(valueAt:), cycles: 4)
		case 0x79: return self.withAbsoluteYIndexedAddressing(
			self.addToAccumulator(valueAt:), cycles: 4)
		case 0x61: return self.withXIndexedIndirectAddressing(
			self.addToAccumulator(valueAt:), cycles: 6)
		case 0x71: return self.withIndirectYIndexedAddressing(
			self.addToAccumulator(valueAt:), cycles: 5)
			
			// MARK: AND
		case 0x29: return self.withImmediateAddressing({
			self.accumulator &= self.bus.read(at: $0)
		})
		case 0x25: return self.with0PageAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 3)
		case 0x35: return self.with0PageXIndexedAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x2D: return self.withAbsoluteAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x3D: return self.withAbsoluteXIndexedAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x39: return self.withAbsoluteYIndexedAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x21: return self.withXIndexedIndirectAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 6)
		case 0x31: return self.withIndirectYIndexedAddressing({
			self.accumulator &= self.bus.read(at: $0)
		}, cycles: 5)
			
			// MARK: ASL (accumulator)
		case 0x0a: return self.withImpliedAddressing(
			self.bitShiftLeftAccumulator)
			// MARK: ASL
		case 0x06: return self.with0PageAddressing(
			self.bitShiftLeft(valueAt:), cycles: 5)
		case 0x16: return self.with0PageXIndexedAddressing(
			self.bitShiftLeft(valueAt:), cycles: 6)
		case 0x0e: return self.withAbsoluteAddressing(
			self.bitShiftLeft(valueAt:), cycles: 6)
		case 0x1e: return self.withAbsoluteXIndexedAddressing(
			self.bitShiftLeft(valueAt:), cycles: 7)
			
			// MARK: BCC
		case 0x90: return self.withRelativeAddressing(
			on: { self.status[.carry] == false })
			// MARK: BCS
		case 0xb0: return self.withRelativeAddressing(
			on: { self.status[.carry] })
			// MARK: BEQ
		case 0xf0: return self.withRelativeAddressing(
			on: { self.status[.zero] })
			
			// MARK: BIT
		case 0x24: return self.with0PageAddressing(
			self.bitTestAccumulator(withValueAt:), cycles: 3)
		case 0x2c: return self.withAbsoluteAddressing(
			self.bitTestAccumulator(withValueAt:), cycles: 4)
			
			// MARK: BMI
		case 0x30: return self.withRelativeAddressing(
			on: { self.status[.negative] })
			// MARK: BNE
		case 0xd0: return self.withRelativeAddressing(
			on: { self.status[.zero] == false })
			// MARK: BPL
		case 0x10: return self.withRelativeAddressing(
			on: { self.status[.negative] == false })
			
			// MARK: BRK
		case 0x00: return self.withImpliedAddressing(
			self.forceBreak, cycles: 7)
			
			// MARK: BVC
		case 0x50: return self.withRelativeAddressing(
			on: { self.status[.overflow] == false })
			// MARK: BVS
		case 0x70: return self.withRelativeAddressing(
			on: { self.status[.overflow] })
			
			// MARK: CLC
		case 0x18: return self.withImpliedAddressing(
			{ self.status[.carry] = false })
			// MARK: CLD
		case 0xd8: return self.withImpliedAddressing(
			{ self.status[.decimalMode] = false })
			// MARK: CLI
		case 0x58: return self.withImpliedAddressing(
			{ self.status[.interruptDisabled] = false })
			// MARK: CLV
		case 0xb8: return self.withImpliedAddressing(
			{ self.status[.overflow] = false })
			
			// MARK: CMP
		case 0xc9: return self.withImmediateAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		})
		case 0xc5: return self.with0PageAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 3)
		case 0xd5: return self.with0PageXIndexedAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 4)
		case 0xcd: return self.withAbsoluteAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 4)
		case 0xdd: return self.withAbsoluteXIndexedAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 4)
		case 0xd9: return self.withAbsoluteYIndexedAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 4)
		case 0xc1: return self.withXIndexedIndirectAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 6)
		case 0xd1: return self.withIndirectYIndexedAddressing({
			self.compare(self.accumulator, withValueAt: $0)
		}, cycles: 5)
			
			// MARK: CPX
		case 0xe0: return self.withImmediateAddressing({
			self.compare(self.x, withValueAt: $0)
		})
		case 0xe4: return self.with0PageAddressing({
			self.compare(self.x, withValueAt: $0)
		}, cycles: 3)
		case 0xec: return self.withAbsoluteAddressing({
			self.compare(self.x, withValueAt: $0)
		}, cycles: 4)
			
			// MARK: CPY
		case 0xc0: return self.withImmediateAddressing({
			self.compare(self.y, withValueAt: $0)
		})
		case 0xc4: return self.with0PageAddressing({
			self.compare(self.y, withValueAt: $0)
		}, cycles: 3)
		case 0xcc: return self.withAbsoluteAddressing({
			self.compare(self.y, withValueAt: $0)
		}, cycles: 4)
			
			// MARK: DEC
		case 0xc6: return self.with0PageAddressing(
			self.decrement(valueAt:), cycles: 5)
		case 0xd6: return self.with0PageXIndexedAddressing(
			self.decrement(valueAt:), cycles: 6)
		case 0xce: return self.withAbsoluteAddressing(
			self.decrement(valueAt:), cycles: 6)
		case 0xde: return self.withAbsoluteXIndexedAddressing(
			self.decrement(valueAt:), cycles: 7)
			
			// MARK: DEX
		case 0xca: return self.withImpliedAddressing({
			self.x = (self.x - 0x1) & 0xff
		})
			// MARK: DEY
		case 0x88: return self.withImpliedAddressing({
			self.y = (self.y - 0x1) & 0xff
		})
			
			// MARK: EOR
		case 0x49: return self.withImmediateAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		})
		case 0x45: return self.with0PageAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 3)
		case 0x55: return self.with0PageXIndexedAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x4d: return self.withAbsoluteAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x5d: return self.withAbsoluteXIndexedAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x59: return self.withAbsoluteYIndexedAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x41: return self.withXIndexedIndirectAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 6)
		case 0x51: return self.withIndirectYIndexedAddressing({
			self.accumulator ^= self.bus.read(at: $0)
		}, cycles: 5)
			
			// MARK: INC
		case 0xe6: return self.with0PageAddressing(
			self.increment(valueAt:), cycles: 5)
		case 0xf6: return self.with0PageXIndexedAddressing(
			self.increment(valueAt:), cycles: 6)
		case 0xee: return self.withAbsoluteAddressing(
			self.increment(valueAt:), cycles: 6)
		case 0xfe: return self.withAbsoluteXIndexedAddressing(
			self.increment(valueAt:), cycles: 7)
			
			// MARK: INX
		case 0xe8: return self.withImpliedAddressing({
			self.x = (self.x + 0x1) & 0xff
		})
			// MARK: INY
		case 0xc8: return self.withImpliedAddressing({
			self.y = (self.y + 0x1) & 0xff
		})
			
			// MARK: JMP
		case 0x4c: return self.withAbsoluteAddressing(
			{ self.programCounter = $0}, cycles: 3)
		case 0x6c: return self.withIndirectAddressing(
			{ self.programCounter = $0}, cycles: 5)
			
			// MARK: JSR
		case 0x20: return self.withAbsoluteAddressing(
			self.jumpToSubroutine(at:), cycles: 6)
			
			// MARK: LDA
		case 0xa9: return self.withImmediateAddressing({
			self.accumulator = self.bus.read(at: $0)
		})
		case 0xa5: return self.with0PageAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 3)
		case 0xb5: return self.with0PageXIndexedAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xad: return self.withAbsoluteAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xbd: return self.withAbsoluteXIndexedAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xb9: return self.withAbsoluteYIndexedAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xa1: return self.withXIndexedIndirectAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 6)
		case 0xb1: return self.withIndirectYIndexedAddressing({
			self.accumulator = self.bus.read(at: $0)
		}, cycles: 5)
			
			// MARK: LDX
		case 0xa2: return self.withImmediateAddressing({
			self.x = self.bus.read(at: $0)
		})
		case 0xa6: return self.with0PageAddressing({
			self.x = self.bus.read(at: $0)
		}, cycles: 3)
		case 0xb6: return self.with0PageYIndexedAddressing({
			self.x = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xae: return self.withAbsoluteAddressing({
			self.x = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xbe: return self.withAbsoluteYIndexedAddressing({
			self.x = self.bus.read(at: $0)
		}, cycles: 4)
			
			// MARK: LDY
		case 0xa0: return self.withImmediateAddressing({
			self.y = self.bus.read(at: $0)
		})
		case 0xa4: return self.with0PageAddressing({
			self.y = self.bus.read(at: $0)
		}, cycles: 3)
		case 0xb4: return self.with0PageXIndexedAddressing({
			self.y = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xac: return self.withAbsoluteAddressing({
			self.y = self.bus.read(at: $0)
		}, cycles: 4)
		case 0xbc: return self.withAbsoluteXIndexedAddressing({
			self.y = self.bus.read(at: $0)
		}, cycles: 4)
			
			// MARK: LSR (accumulator)
		case 0x4a: return self.withImpliedAddressing(
			self.bitShiftRightAccumulator)
			// MARK: LSR
		case 0x46: return self.with0PageAddressing(
			self.bitShiftRight(valueAt:), cycles: 5)
		case 0x56: return self.with0PageXIndexedAddressing(
			self.bitShiftRight(valueAt:), cycles: 6)
		case 0x4e: return self.withAbsoluteAddressing(
			self.bitShiftRight(valueAt:), cycles: 6)
		case 0x5e: return self.withAbsoluteXIndexedAddressing(
			self.bitShiftRight(valueAt:), cycles: 7)
			
			// MARK: NOP
		case 0xea: return self.withImpliedAddressing(
			{})
			
			// MARK: ORA
		case 0x09: return self.withImmediateAddressing({
			self.accumulator |= self.bus.read(at: $0)
		})
		case 0x05: return self.with0PageAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 3)
		case 0x15: return self.with0PageXIndexedAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x0d: return self.withAbsoluteAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x1d: return self.withAbsoluteXIndexedAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x19: return self.withAbsoluteYIndexedAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 4)
		case 0x01: return self.withXIndexedIndirectAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 6)
		case 0x11: return self.withIndirectYIndexedAddressing({
			self.accumulator |= self.bus.read(at: $0)
		}, cycles: 5)
			
			// MARK: PHA
		case 0x48: return self.withImpliedAddressing(
			{ self.pushStack(self.accumulator) }, cycles: 3)
			// MARK: PHP
		case 0x08: return self.withImpliedAddressing(
			{ self.pushStack(self.status.rawValue) }, cycles: 3)
			// MARK: PLA
		case 0x68: return self.withImpliedAddressing(
			{ self.accumulator = self.pullStack() }, cycles: 4)
			// MARK: PLP
		case 0x28: return self.withImpliedAddressing(
			{ self.status = Status(rawValue: self.pullStack()) }, cycles: 4)
			
			// MARK: ROL (accumulator)
		case 0x2a: return self.withImpliedAddressing(
			self.bitRotateLeftAccumulator)
			// MARK: ROL
		case 0x26: return self.with0PageAddressing(
			self.bitRotateLeft(valueAt:), cycles: 5)
		case 0x36: return self.with0PageXIndexedAddressing(
			self.bitRotateLeft(valueAt:), cycles: 6)
		case 0x2e: return self.withAbsoluteAddressing(
			self.bitRotateLeft(valueAt:), cycles: 6)
		case 0x3e: return self.withAbsoluteXIndexedAddressing(
			self.bitRotateLeft(valueAt:), cycles: 7)
			
			// MARK: ROR (accumulator)
		case 0x6a: return self.withImpliedAddressing(
			self.bitRotateRightAccumulator)
			// MARK: ROR
		case 0x66: return self.with0PageAddressing(
			self.bitRotateRight(valueAt:), cycles: 5)
		case 0x76: return self.with0PageXIndexedAddressing(
			self.bitRotateRight(valueAt:), cycles: 6)
		case 0x6e: return self.withAbsoluteAddressing(
			self.bitRotateRight(valueAt:), cycles: 6)
		case 0x7e: return self.withAbsoluteXIndexedAddressing(
			self.bitRotateRight(valueAt:), cycles: 7)
			
			// MARK: RTI
		case 0x40: return self.withImpliedAddressing(
			self.returnFromInterrupt, cycles: 6)
			// MARK: RTS
		case 0x60: return self.withImpliedAddressing({
			self.returnFromSubroutine()
			self.programCounter += 1
		}, cycles: 6)
			
			// MARK: SBC
		case 0xe9: return self.withImmediateAddressing(
			self.subtractFromAccumulator(valueAt:))
		case 0xe5: return self.with0PageAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 3)
		case 0xf5: return self.with0PageXIndexedAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 4)
		case 0xed: return self.withAbsoluteAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 4)
		case 0xfd: return self.withAbsoluteXIndexedAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 4)
		case 0xf9: return self.withAbsoluteYIndexedAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 4)
		case 0xe1: return self.withXIndexedIndirectAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 6)
		case 0xf1: return self.withIndirectYIndexedAddressing(
			self.subtractFromAccumulator(valueAt:), cycles: 5)
			
			// MARK: SEC
		case 0x38: return self.withImpliedAddressing(
			{ self.status[.carry] = true })
			// MARK: SED
		case 0xf8: return self.withImpliedAddressing(
			{ self.status[.decimalMode] = true })
			// MARK: SEI
		case 0x78: return self.withImpliedAddressing(
			{ self.status[.interruptDisabled] = true })
			
			// MARK: STA
		case 0x85: return self.with0PageAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 3)
		case 0x95: return self.with0PageXIndexedAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 4)
		case 0x8d: return self.withAbsoluteAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 4)
		case 0x9d: return self.withAbsoluteXIndexedAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 5)
		case 0x99: return self.withAbsoluteYIndexedAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 5)
		case 0x81: return self.withXIndexedIndirectAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 6)
		case 0x91: return self.withIndirectYIndexedAddressing({
			self.bus.write(self.accumulator, at: $0)
		}, cycles: 6)
			
			// MARK: STX
		case 0x86: return self.with0PageAddressing({
			self.bus.write(self.x, at: $0)
		}, cycles: 3)
		case 0x96: return self.with0PageYIndexedAddressing({
			self.bus.write(self.x, at: $0)
		}, cycles: 4)
		case 0x8e: return self.withAbsoluteAddressing({
			self.bus.write(self.x, at: $0)
		}, cycles: 4)
			
			// MARK: STY
		case 0x84: return self.with0PageAddressing({
			self.bus.write(self.y, at: $0)
		}, cycles: 3)
		case 0x94: return self.with0PageXIndexedAddressing({
			self.bus.write(self.y, at: $0)
		}, cycles: 4)
		case 0x8c: return self.withAbsoluteAddressing({
			self.bus.write(self.y, at: $0)
		}, cycles: 4)
			
			// MARK: TAX
		case 0xaa: return self.withImpliedAddressing({
			self.x = self.accumulator
		})
			// MARK: TAY
		case 0xa8: return self.withImpliedAddressing({
			self.y = self.accumulator
		})
			// MARK: TSX
		case 0xba: return self.withImpliedAddressing({
			self.x = self.stackPointer
		})
			// MARK: TXA
		case 0x8a: return self.withImpliedAddressing({
			self.accumulator = self.x
		})
			// MARK: TXS
		case 0x9a: return self.withImpliedAddressing({
			self.stackPointer = self.x
		})
			// MARK: TYA
		case 0x98: return self.withImpliedAddressing({
			self.accumulator = self.y
		})
			
		default:
			fatalError("Unknown operation code: \(opcode)")
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
// MARK: Memory addressing
private extension MOS6507 {
	func withImpliedAddressing(_ operation: @escaping () -> Void, cycles: Int = 2) -> (() -> Void, Int, Int?) {
		return ({ [unowned self] in
			self.programCounter += 1
			operation()
		}, cycles, nil)
	}
	
	func withImmediateAddressing(_ operation: @escaping (Int) -> Void, cycles: Int = 2) -> (() -> Void, Int, Int?) {
		let address = self.programCounter + 1
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles, address)
	}
	
	func with0PageAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: 0x00)
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles, address)
	}
	
	func with0PageXIndexedAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address.low += self.x
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles, address)
	}
	
	func with0PageYIndexedAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address.low += self.y
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles, address)
	}
	
	func withAbsoluteAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles, address)
	}
	
	func withAbsoluteXIndexedAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		let page = address.high
		address += self.x
		
		// read-only operations take 5 cycles, unless indexing crosses
		// page boundary
		var cycles = cycles
		if cycles == 4
			&& address.high > page {
			cycles += 1
		}
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles, address)
	}
	
	func withAbsoluteYIndexedAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		let page = address.high
		address += self.y
		
		// read-only operations take 4 cycles, unless indexing crosses
		// page boundary
		var cycles = cycles
		if cycles == 4
			&& address.high > page {
			cycles += 1
		}
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles, address)
	}
	
	func withIndirectAddressing(_ operation: @escaping (Int) -> Void, cycles: Int = 5) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles, address)
	}
	
	func withXIndexedIndirectAddressing(_ operation: @escaping (Int) -> Void, cycles: Int = 6) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address.low += self.x
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles, address)
	}
	
	func withIndirectYIndexedAddressing(_ operation: @escaping (Int) -> Void, cycles: Int) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 1
		address = Int(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address = Int(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		let page = address.high
		address += self.y
		
		// read-only operations take 5 cycles, unless indexing crosses
		// page boundary
		var cycles = cycles
		if cycles == 5
			&& address.high > page {
			cycles += 1
		}
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles, address)
	}
	
	func withRelativeAddressing(on condition: () -> Bool) -> (() -> Void, Int, Int?) {
		var address = self.programCounter + 2
		var cycles = 2
		
		if condition() {
			let offset = self.bus.read(at: address - 1)
			let page = address.high
			
			address += Int(signed: offset)
			// in relative addressing page can be crossed both to a higher
			// or a lower one
			cycles += address.high != page ? 2 : 1
		}
		
		return ({
			self.programCounter = address
		}, cycles, address)
	}
}


// MARK: -
// MARK: Operations
private extension MOS6507 {
	func addToAccumulator(valueAt address: Int) {
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
				self.status[.carry] = true
				result -= 0xa0
			}
		} else {
			result = self.accumulator + operand + carry
			if result > 0xff {
				self.status[.carry] = true
				result -= 0x100
			}
		}
		
		let overflow = (self.accumulator ^ result) & (operand ^ result)
		
		self.accumulator = result
		self.status[.overflow] = overflow[7]
	}
	
	func subtractFromAccumulator(valueAt address: Int) {
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
				self.status[.carry] = true
				result += 0xa0
			}
		} else {
			result = self.accumulator - operand - borrow
			if result < 0x0 {
				self.status[.carry] = true
				result += 0x100
			}
		}
		
		let overflow = (self.accumulator ^ result) & (operand ^ result)
		
		self.accumulator = result
		self.status[.overflow] = overflow[7]
		self.status[.carry] = result >= 0x0
	}
	
	func bitTestAccumulator(withValueAt address: Int) {
		let operand = self.bus.read(at: address)
		let result = self.accumulator & operand
		
		self.status[.overflow] = operand[6]
		self.status[.zero] = result == 0x0
		self.status[.negative] = operand[7]
	}
	
	func bitShiftLeftAccumulator() {
		let carry = self.accumulator[7]
		
		self.accumulator = (self.accumulator << 1) & 0xff
		self.status[.carry] = carry
	}
	
	func bitShiftRightAccumulator() {
		let carry = self.accumulator[0]
		
		self.accumulator >>= 1
		self.status[.carry] = carry
	}
	
	func bitRotateLeftAccumulator() {
		let carry = self.accumulator[7]
		var result = self.accumulator << 1
		result[0] = self.status[.carry]
		
		self.accumulator = result & 0xff
		self.status[.carry] = carry
	}
	
	func bitRotateRightAccumulator() {
		let carry = self.accumulator[0]
		var result = self.accumulator >> 1
		result[7] = self.status[.carry]
		
		self.accumulator = result
		self.status[.carry] = carry
	}
	
	func bitShiftLeft(valueAt address: Int) {
		let operand = self.bus.read(at: address)
		let result = operand << 1
		
		self.bus.write(result & 0xff, at: address)
		self.status[.carry] = result[8]
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func bitShiftRight(valueAt address: Int) {
		let operand = self.bus.read(at: address)
		let result = operand >> 1
		
		self.bus.write(result, at: address)
		self.status[.carry] = operand[0]
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func bitRotateLeft(valueAt address: Int) {
		let operand = self.bus.read(at: address)
		var result = operand << 1
		result[0] = self.status[.carry]
		
		self.bus.write(result & 0xff, at: address)
		self.status[.carry] = operand[7]
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func bitRotateRight(valueAt address: Int) {
		let operand = self.bus.read(at: address)
		var result = operand >> 1
		result[7] = self.status[.carry]
		
		self.bus.write(result, at: address)
		self.status[.carry] = operand[0]
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func compare(_ value: Int, withValueAt address: Int) {
		let operand = self.bus.read(at: address)
		let result = value - operand
		
		self.status[.carry] = result >= 0x0
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func increment(valueAt address: Int) {
		let operand = self.bus.read(at: address)
		let result = (operand + 0x1) & 0xff
		
		self.bus.write(result, at: address)
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func decrement(valueAt address: Int) {
		let operand = self.bus.read(at: address)
		let result = (operand - 0x1) & 0xff
		
		self.bus.write(result, at: address)
		self.status[.zero] = result == 0x0
		self.status[.negative] = result[7]
	}
	
	func forceBreak() {
		self.pushStack(self.programCounter.high)
		self.pushStack(self.programCounter.low)
		self.pushStack(self.status.rawValue)
		
		self.programCounter = Int(
			low: self.bus.read(at: 0xfffe),
			high: self.bus.read(at: 0xffff))
	}
	
	func returnFromInterrupt() {
		self.status = Status(rawValue: self.pullStack())
		self.programCounter = Int(
			low: self.pullStack(),
			high: self.pullStack())
	}
	
	func jumpToSubroutine(at address: Int) {
		// this instruction is wrapped within the absolute addressing closure,
		// which increments program counter by 2 before calling this function;
		// however, in hardware program counter is first incremented by 1,
		// then it is pushed onto the stack and incremented by 1 once more;
		// pushing (program counter - 1) onto the stack corrects for it and
		// avoids a separate addressing for this instruction
		let programCounter = self.programCounter - 1
		
		self.pushStack(programCounter.high)
		self.pushStack(programCounter.low)
		self.programCounter = address
	}
	
	func returnFromSubroutine() {
		self.programCounter = Int(
			low: self.pullStack(),
			high: self.pullStack())
	}
}


// MARK: -
// MARK: Convenience functionality
private extension MOS6507.Status {
	static func random() -> Self {
		return MOS6507.Status(rawValue: .random(in: 0x00...0xff))
	}
}

private extension Int {
	init(low: Int, high: Int) {
		self = Self(high) * 0x100 + Self(low)
	}
	
	var low: Int {
		get { self % 0x100 }
		set { self = self.high * 0x100 + newValue }
	}
	
	var high: Int {
		get { self / 0x100 }
		set { self = newValue * 0x100 + self.low }
	}
}

extension Int {
	subscript(bit: Int) -> Bool {
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
	
	init(signed value: Int, bits: Int = 8) {
		self = value
		
		let mask = 1 << (bits - 1)
		if value & mask == mask {
			self -= (mask << 1)
		}
	}
}
