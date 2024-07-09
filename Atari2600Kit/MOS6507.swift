//
//  MOS6507.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 22.5.2023.
//

public class MOS6507 {
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
	var nextInstructionExecutionDuration: Int {
		let (operation, cycles) = self.decodeNextOperation()
		self.cachedOperation = operation
		
		return cycles
	}
	
	/// Executes the next instruction in the program.
	func executeNextInstruction() {
		if let operation = self.cachedOperation {
			operation()
		} else {
			let (operation, _) = self.decodeNextOperation()
			operation()
		}
	}
	
	/// Returns the next operation in the program and the amount of CPU cycles it will take to execute.
	private func decodeNextOperation() -> (() -> Void, Int) {
		let opcode = self.bus.read(at: self.programCounter)
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
		case 0x29: return self.withImmediateAddressing(
			self.conjunctAccumulator(withValueAt:))
		case 0x25: return self.with0PageAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 3)
		case 0x35: return self.with0PageXIndexedAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 4)
		case 0x2D: return self.withAbsoluteAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 4)
		case 0x3D: return self.withAbsoluteXIndexedAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 4)
		case 0x39: return self.withAbsoluteYIndexedAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 4)
		case 0x21: return self.withXIndexedIndirectAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 6)
		case 0x31: return self.withIndirectYIndexedAddressing(
			self.conjunctAccumulator(withValueAt:), cycles: 5)
			
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
			on: { self.status.carry == false })
			// MARK: BCS
		case 0xb0: return self.withRelativeAddressing(
			on: { self.status.carry })
			// MARK: BEQ
		case 0xf0: return self.withRelativeAddressing(
			on: { self.status.zero })
			
			// MARK: BIT
		case 0x24: return self.with0PageAddressing(
			self.bitTestAccumulator(withValueAt:), cycles: 3)
		case 0x2c: return self.withAbsoluteAddressing(
			self.bitTestAccumulator(withValueAt:), cycles: 4)
			
			// MARK: BMI
		case 0x30: return self.withRelativeAddressing(
			on: { self.status.negative })
			// MARK: BNE
		case 0xd0: return self.withRelativeAddressing(
			on: { self.status.zero == false })
			// MARK: BPL
		case 0x10: return self.withRelativeAddressing(
			on: { self.status.negative == false })
			
			// MARK: BRK
		case 0x00: return self.withImpliedAddressing(
			self.forceBreak, cycles: 7)
			
			// MARK: BVC
		case 0x50: return self.withRelativeAddressing(
			on: { self.status.overflow == false })
			// MARK: BVS
		case 0x70: return self.withRelativeAddressing(
			on: { self.status.overflow })
			
			// MARK: CLC
		case 0x18: return self.withImpliedAddressing(
			{ self.status.carry = false })
			// MARK: CLD
		case 0xd8: return self.withImpliedAddressing(
			{ self.status.decimalMode = false })
			// MARK: CLI
		case 0x58: return self.withImpliedAddressing(
			{ self.status.interruptDisabled = false })
			// MARK: CLV
		case 0xb8: return self.withImpliedAddressing(
			{ self.status.overflow = false })
			
			// MARK: CMP
		case 0xc9: return self.withImmediateAddressing(
			self.compareAccumulator(withValueAt:))
		case 0xc5: return self.with0PageAddressing(
			self.compareAccumulator(withValueAt:), cycles: 3)
		case 0xd5: return self.with0PageXIndexedAddressing(
			self.compareAccumulator(withValueAt:), cycles: 4)
		case 0xcd: return self.withAbsoluteAddressing(
			self.compareAccumulator(withValueAt:), cycles: 4)
		case 0xdd: return self.withAbsoluteXIndexedAddressing(
			self.compareAccumulator(withValueAt:), cycles: 4)
		case 0xd9: return self.withAbsoluteYIndexedAddressing(
			self.compareAccumulator(withValueAt:), cycles: 4)
		case 0xc1: return self.withXIndexedIndirectAddressing(
			self.compareAccumulator(withValueAt:), cycles: 6)
		case 0xd1: return self.withIndirectYIndexedAddressing(
			self.compareAccumulator(withValueAt:), cycles: 5)
			
			// MARK: CPX
		case 0xe0: return self.withImmediateAddressing(
			self.compareX(withValueAt:))
		case 0xe4: return self.with0PageAddressing(
			self.compareX(withValueAt:), cycles: 3)
		case 0xec: return self.withAbsoluteAddressing(
			self.compareX(withValueAt:), cycles: 4)
			
			// MARK: CPY
		case 0xc0: return self.withImmediateAddressing(
			self.compareY(withValueAt:))
		case 0xc4: return self.with0PageAddressing(
			self.compareY(withValueAt:), cycles: 3)
		case 0xcc: return self.withAbsoluteAddressing(
			self.compareY(withValueAt:), cycles: 4)
			
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
		case 0xca: return self.withImpliedAddressing(
			self.decrementX)
			// MARK: DEY
		case 0x88: return self.withImpliedAddressing(
			self.decrementY)
			
			// MARK: EOR
		case 0x49: return self.withImmediateAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:))
		case 0x45: return self.with0PageAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 3)
		case 0x55: return self.with0PageXIndexedAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 4)
		case 0x4d: return self.withAbsoluteAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 4)
		case 0x5d: return self.withAbsoluteXIndexedAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 4)
		case 0x59: return self.withAbsoluteYIndexedAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 4)
		case 0x41: return self.withXIndexedIndirectAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 6)
		case 0x51: return self.withIndirectYIndexedAddressing(
			self.exclusiveDisjunctAccumulator(withValueAt:), cycles: 5)
			
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
		case 0xe8: return self.withImpliedAddressing(
			self.incrementX)
			// MARK: INY
		case 0xc8: return self.withImpliedAddressing(
			self.incrementY)
			
			// MARK: JMP
		case 0x4c: return self.withAbsoluteAddressing(
			{ self.programCounter = $0}, cycles: 3)
		case 0x6c: return self.withIndirectAddressing(
			{ self.programCounter = $0}, cycles: 5)
			
			// MARK: JSR
		case 0x20: return self.withAbsoluteAddressing(
			self.jumpToSubroutine(at:), cycles: 6)
			
			// MARK: LDA
		case 0xa9: return self.withImmediateAddressing(
			self.loadAccumulator(withValueAt:))
		case 0xa5: return self.with0PageAddressing(
			self.loadAccumulator(withValueAt:), cycles: 3)
		case 0xb5: return self.with0PageXIndexedAddressing(
			self.loadAccumulator(withValueAt:), cycles: 4)
		case 0xad: return self.withAbsoluteAddressing(
			self.loadAccumulator(withValueAt:), cycles: 4)
		case 0xbd: return self.withAbsoluteXIndexedAddressing(
			self.loadAccumulator(withValueAt:), cycles: 4)
		case 0xb9: return self.withAbsoluteYIndexedAddressing(
			self.loadAccumulator(withValueAt:), cycles: 4)
		case 0xa1: return self.withXIndexedIndirectAddressing(
			self.loadAccumulator(withValueAt:), cycles: 6)
		case 0xb1: return self.withIndirectYIndexedAddressing(
			self.loadAccumulator(withValueAt:), cycles: 5)
			
			// MARK: LDX
		case 0xa2: return self.withImmediateAddressing(
			self.loadX(withValueAt:))
		case 0xa6: return self.with0PageAddressing(
			self.loadX(withValueAt:), cycles: 3)
		case 0xb6: return self.with0PageYIndexedAddressing(
			self.loadX(withValueAt:), cycles: 4)
		case 0xae: return self.withAbsoluteAddressing(
			self.loadX(withValueAt:), cycles: 4)
		case 0xbe: return self.withAbsoluteYIndexedAddressing(
			self.loadX(withValueAt:), cycles: 4)
			
			// MARK: LDY
		case 0xa0: return self.withImmediateAddressing(
			self.loadY(withValueAt:))
		case 0xa4: return self.with0PageAddressing(
			self.loadY(withValueAt:), cycles: 3)
		case 0xb4: return self.with0PageXIndexedAddressing(
			self.loadY(withValueAt:), cycles: 4)
		case 0xac: return self.withAbsoluteAddressing(
			self.loadY(withValueAt:), cycles: 4)
		case 0xbc: return self.withAbsoluteXIndexedAddressing(
			self.loadY(withValueAt:), cycles: 4)
			
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
		case 0x09: return self.withImmediateAddressing(
			self.disjunctAccumulator(withValueAt:))
		case 0x05: return self.with0PageAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 3)
		case 0x15: return self.with0PageXIndexedAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 4)
		case 0x0d: return self.withAbsoluteAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 4)
		case 0x1d: return self.withAbsoluteXIndexedAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 4)
		case 0x19: return self.withAbsoluteYIndexedAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 4)
		case 0x01: return self.withXIndexedIndirectAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 6)
		case 0x11: return self.withIndirectYIndexedAddressing(
			self.disjunctAccumulator(withValueAt:), cycles: 5)
			
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
			{ self.status = Status(rawValue: self.pullStack())! }, cycles: 4)
			
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
		case 0x60: return self.withImpliedAddressing(
			self.returnFromSubroutine, cycles: 6)
			
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
			{ self.status.carry = true })
			// MARK: SED
		case 0xf8: return self.withImpliedAddressing(
			{ self.status.decimalMode = true })
			// MARK: SEI
		case 0x78: return self.withImpliedAddressing(
			{ self.status.interruptDisabled = true })
			
			// MARK: STA
		case 0x85: return self.with0PageAddressing(
			self.storeAccumulator(at:), cycles: 3)
		case 0x95: return self.with0PageXIndexedAddressing(
			self.storeAccumulator(at:), cycles: 4)
		case 0x8d: return self.withAbsoluteAddressing(
			self.storeAccumulator(at:), cycles: 4)
		case 0x9d: return self.withAbsoluteXIndexedAddressing(
			self.storeAccumulator(at:), cycles: 5)
		case 0x99: return self.withAbsoluteYIndexedAddressing(
			self.storeAccumulator(at:), cycles: 5)
		case 0x81: return self.withXIndexedIndirectAddressing(
			self.storeAccumulator(at:), cycles: 6)
		case 0x91: return self.withIndirectYIndexedAddressing(
			self.storeAccumulator(at:), cycles: 6)
			
			// MARK: STX
		case 0x86: return self.with0PageAddressing(
			self.storeX(at:), cycles: 3)
		case 0x96: return self.with0PageYIndexedAddressing(
			self.storeX(at:), cycles: 4)
		case 0x8e: return self.withAbsoluteAddressing(
			self.storeX(at:), cycles: 4)
			
			// MARK: STY
		case 0x84: return self.with0PageAddressing(
			self.storeY(at:), cycles: 3)
		case 0x94: return self.with0PageXIndexedAddressing(
			self.storeY(at:), cycles: 4)
		case 0x8c: return self.withAbsoluteAddressing(
			self.storeY(at:), cycles: 4)
			
			// MARK: TAX
		case 0xaa: return self.withImpliedAddressing(
			self.transferAccumulatorToX)
			// MARK: TAY
		case 0xa8: return self.withImpliedAddressing(
			self.transferAccumulatorToY)
			// MARK: TSX
		case 0xba: return self.withImpliedAddressing(
			self.transferStackPointerToX)
			// MARK: TXA
		case 0x8a: return self.withImpliedAddressing(
			self.transferXToAccumulator)
			// MARK: TXS
		case 0x9a: return self.withImpliedAddressing(
			self.transferXToStackPointer)
			// MARK: TYA
		case 0x98: return self.withImpliedAddressing(
			self.transferYToAccumulator)
			
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
	func withImpliedAddressing(_ operation: @escaping () -> Void, cycles: Int = 2) -> (() -> Void, Int) {
		return ({ [unowned self] in
			self.programCounter += 1
			operation()
		}, cycles)
	}
	
	func withImmediateAddressing(_ operation: @escaping (Address) -> Void, cycles: Int = 2) -> (() -> Void, Int) {
		let address = self.programCounter + 1
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles)
	}
	
	func with0PageAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: 0x00)
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles)
	}
	
	func with0PageXIndexedAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address.low += self.x
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles)
	}
	
	func with0PageYIndexedAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address.low += self.y
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles)
	}
	
	func withAbsoluteAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles)
	}
	
	func withAbsoluteXIndexedAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		let page = address.high
		address += self.x
		
		// only read-only operations take 5 cycles, unless indexing crosses
		// page boundary
		var cycles = cycles
		if cycles == 4
			&& address.high > page {
			cycles += 1
		}
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles)
	}
	
	func withAbsoluteYIndexedAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		let page = address.high
		address += self.y
		
		// only read-only operations take 4 cycles, unless indexing crosses
		// page boundary
		var cycles = cycles
		if cycles == 4
			&& address.high > page {
			cycles += 1
		}
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles)
	}
	
	func withIndirectAddressing(_ operation: @escaping (Address) -> Void, cycles: Int = 5) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		return ({ [unowned self] in
			self.programCounter += 3
			operation(address)
		}, cycles)
	}
	
	func withXIndexedIndirectAddressing(_ operation: @escaping (Address) -> Void, cycles: Int = 6) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address.low += self.x
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles)
	}
	
	func withIndirectYIndexedAddressing(_ operation: @escaping (Address) -> Void, cycles: Int) -> (() -> Void, Int) {
		var address = self.programCounter + 1
		address = Address(
			low: self.bus.read(at: address),
			high: 0x00)
		
		address = Address(
			low: self.bus.read(at: address),
			high: self.bus.read(at: address + 1))
		
		let page = address.high
		address += self.y
		
		// only read-only operations take 5 cycles, unless indexing crosses
		// page boundary
		var cycles = cycles
		if cycles == 5
			&& address.high > page {
			cycles += 1
		}
		
		return ({ [unowned self] in
			self.programCounter += 2
			operation(address)
		}, cycles)
	}
	
	func withRelativeAddressing(on condition: () -> Bool) -> (() -> Void, Int) {
		var address = self.programCounter + 2
		var cycles = 2
		
		if condition() {
			let offset = self.bus.read(at: address - 1)
			let page = address.high
			
			address += Int(signedWord: offset)
			// in relative addressing page can be crossed both to a higher
			// or a lower one
			cycles += address.high != page ? 2 : 1
		}
		
		return ({
			self.programCounter = address
		}, cycles)
	}
}


// MARK: -
// MARK: Operations
private extension MOS6507 {
	func addToAccumulator(valueAt address: Address) {
		let operand = self.bus.read(at: address)
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
	}
	
	func subtractFromAccumulator(valueAt address: Address) {
		let operand = self.bus.read(at: address)
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
	}
	
	func conjunctAccumulator(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.accumulator & operand
		
		self.accumulator = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func disjunctAccumulator(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.accumulator | operand
		
		self.accumulator = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func exclusiveDisjunctAccumulator(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.accumulator ^ operand
		
		self.accumulator = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func bitTestAccumulator(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.accumulator & operand
		
		self.status.overflow = operand[6]
		self.status.zero = result == 0x00
		self.status.negative = operand[7]
	}
	
	func bitShiftLeftAccumulator() {
		let result = self.accumulator << 1
		
		self.accumulator = result & 0xff
		self.status.carry = result[8]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func bitShiftLeft(valueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = operand << 1
		
		self.bus.write(result & 0xff, at: address)
		self.status.carry = result[8]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func bitShiftRightAccumulator() {
		let carry = self.accumulator[0]
		let result = self.accumulator >> 1
		
		self.accumulator = result
		self.status.carry = carry
		self.status.zero = result == 0x00
		self.status.negative = false
	}
	
	func bitShiftRight(valueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = operand >> 1
		
		self.bus.write(result, at: address)
		self.status.carry = operand[0]
		self.status.zero = result == 0x00
		self.status.negative = false
	}
	
	func bitRotateLeftAccumulator() {
		let operand = self.accumulator
		var result = operand << 1
		result[0] = self.status.carry
		
		self.accumulator = result & 0xff
		self.status.carry = operand[7]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func bitRotateLeft(valueAt address: Address) {
		let operand = self.bus.read(at: address)
		var result = operand << 1
		result[0] = self.status.carry
		
		self.bus.write(result & 0xff, at: address)
		self.status.carry = operand[7]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func bitRotateRightAccumulator() {
		let operand = self.accumulator
		var result = operand >> 1
		result[7] = self.status.carry
		
		self.accumulator = result
		self.status.carry = operand[0]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func bitRotateRight(valueAt address: Address) {
		let operand = self.bus.read(at: address)
		var result = operand >> 1
		result[7] = self.status.carry
		
		self.bus.write(result, at: address)
		self.status.carry = operand[0]
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func compareAccumulator(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.accumulator - operand
		
		self.status.carry = result >= 0x00
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func compareX(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.x - operand
		
		self.status.carry = result >= 0x00
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func compareY(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		let result = self.y - operand
		
		self.status.carry = result >= 0x00
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func increment(valueAt address: Address) {
		let operand = self.bus.read(at: address)
		var result = operand + 0x01
		if result > 0xff {
			result = 0x00
		}
		
		self.bus.write(result, at: address)
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func decrement(valueAt address: Address) {
		let operand = self.bus.read(at: address)
		var result = operand - 0x01
		if result < 0x00 {
			result = 0xff
		}
		
		self.bus.write(result, at: address)
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func incrementX() {
		var result = self.x + 0x01
		if result > 0xff {
			result = 0x00
		}
		
		self.x = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func decrementX() {
		var result = self.x - 0x01
		if result < 0x00 {
			result = 0xff
		}
		
		self.x = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func incrementY() {
		var result = self.y + 0x01
		if result > 0xff {
			result = 0x00
		}
		
		self.y = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func decrementY() {
		var result = self.y - 0x01
		if result < 0x00 {
			result = 0xff
		}
		
		self.y = result
		self.status.zero = result == 0x00
		self.status.negative = result[7]
	}
	
	func loadAccumulator(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		
		self.accumulator = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func storeAccumulator(at address: Address) {
		self.bus.write(self.accumulator, at: address)
	}
	
	func loadX(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		
		self.x = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func storeX(at address: Address) {
		self.bus.write(self.x, at: address)
	}
	
	func loadY(withValueAt address: Address) {
		let operand = self.bus.read(at: address)
		
		self.y = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func storeY(at address: Address) {
		self.bus.write(self.y, at: address)
	}
	
	func transferAccumulatorToX() {
		let operand = self.accumulator
		
		self.x = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func transferAccumulatorToY() {
		let operand = self.accumulator
		
		self.y = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func transferXToAccumulator() {
		let operand = self.x
		
		self.accumulator = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func transferYToAccumulator() {
		let operand = self.y
		
		self.accumulator = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func transferStackPointerToX() {
		let operand = self.stackPointer
		
		self.x = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func transferXToStackPointer() {
		let operand = self.x
		
		self.stackPointer = operand
		self.status.zero = operand == 0x00
		self.status.negative = operand[7]
	}
	
	func forceBreak() {
		self.pushStack(self.programCounter.high)
		self.pushStack(self.programCounter.low)
		self.pushStack(self.status.rawValue)
		
		self.programCounter = Address(
			low: self.bus.read(at: 0xfffe),
			high: self.bus.read(at: 0xffff))
	}
	
	func returnFromInterrupt() {
		self.status = Status(rawValue: self.pullStack())!
		self.programCounter = Address(
			low: self.pullStack(),
			high: self.pullStack())
	}
	
	func jumpToSubroutine(at address: Address) {
		self.pushStack(self.programCounter.high)
		self.pushStack(self.programCounter.low)
		self.programCounter = address
	}
	
	func returnFromSubroutine() {
		self.programCounter = Address(
			low: self.pullStack(),
			high: self.pullStack())
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
