//
//  CPUTests.swift
//  Atari2600KitTests
//
//  Created by Serge Tsyba on 24.6.2023.
//

import XCTest
@testable import Atari2600Kit

class MOS6507Tests: XCTestCase {
	// MARK: ADC
	class ADCWithoutCarryTests: XCTestCase {
		func testAddsToAccumulator() {
			let cpu = MOS6507()
				.adc(accumulator: 0x16, value: 0x3f)
			
			XCTAssertEqual(cpu.accumulator, 0x55)
			XCTAssertEqual(cpu.status.carry, false)
			XCTAssertEqual(cpu.status.zero, false)
			XCTAssertEqual(cpu.status.overflow, false)
			XCTAssertEqual(cpu.status.negative, false)
		}
		
		func testSetsCarryStatusWhenResultOverflows() {
			let cpu = MOS6507()
				.adc(accumulator: 0xb9, value: 0x7e)
			
			XCTAssertEqual(cpu.accumulator, 0x37)
			XCTAssertEqual(cpu.status.carry, true)
		}
		
		func testSetsZeroStatusWhenResultZero() {
			let cpu = MOS6507()
				.adc(accumulator: 0xb9, value: 0x47)
			
			XCTAssertEqual(cpu.accumulator, 0x00)
			XCTAssertEqual(cpu.status.zero, true)
		}
		
		func testSetsOverflowStatusWhenSignedResultOverflows() {
			let cpu = MOS6507()
				.adc(accumulator: 0x50, value: 0x50)
			
			XCTAssertEqual(cpu.accumulator, 0xa0)
			XCTAssertEqual(cpu.status.overflow, true)
		}
		
		func testSetsNegativeStatusWhenSignedResultNegative() {
			let cpu = MOS6507()
				.adc(accumulator: 0x4a, value: 0x3f)
			
			XCTAssertEqual(cpu.accumulator, 0x89)
			XCTAssertEqual(cpu.status.negative, true)
		}
	}
	
	
}


// MARK: -
// MARK: Convenience functionality
private extension MOS6507 {
	func run(program: [Int]) {
//		self.bus = program
//		self.reset()
//
//		for _ in program {
//			self.step()
//		}
	}
	
	func adc(accumulator: Int, value: Int) -> MOS6507 {
		self.run(program: [
			0xd8,				// cld
			0xa9, accumulator,	// lda $#4a
			0x69, value			// adc $#3f
		])
		return self
	}
}

//extension Array: MOS6502Bus where Element == Int {
//	public func read(at address: Address) -> Atari2600Kit.MOS6507.Word {
//		return self.indices.contains(address)
//		? self[address]
//		: 0x00
//	}
//	
//	public func write(_ value: Atari2600Kit.MOS6507.Word, at address: Address) {
//		// does nothing
//	}
//}
