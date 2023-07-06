//
//  MOS6532Tests.swift
//  Atari2600KitTests
//
//  Created by Serge Tsyba on 4.7.2023.
//

import XCTest
@testable import Atari2600Kit

class MOS6532TimerInterval1Tests: XCTestCase {
	let interval = 17
	let tests = [(
		"decreases by 1 on next cycle",
		cycles: 1, expected: 16
	), (
		"decreases to 13 after 4 cycles",
		cycles: 4, expected: 13
	), (
		"reaches 0 after all fire cycles",
		cycles: 17, expected: 0
	), (
		"decreases by 1 on each cycle after reaching 0",
		cycles: 24, expected: -7
	), (
		"stops when reaching -255",
		cycles: 294, expected: -255
	)]
	
	func testAll() {
		for test in tests {
			let riot = MOS6532()
			riot.advanceClock(cycles: 392)
			
			riot.write(self.interval, at: 0x14)
			riot.advanceClock(cycles: test.cycles)
			
			let actual = riot.read(at: 0x0c)
			XCTAssertEqual(actual, test.expected)
		}
	}
}

class MOS6532TimerInterval8Tests: XCTestCase {
	let interval = 12
	let tests = [(
		"decreases on next cycle",
		cycles: 1, expected: 11
	), (
		"does not decreases before next fire cycle",
		cycles: 7, expected: 11
	), (
		"decreases on fire cycle",
		cycles: 9, expected: 10
	), (
		"decreases to 7 after 5 fire cycles",
		cycles: 37, expected: 7
	), (
		"decreases to 0 after all fire cycles",
		cycles: 89, expected: 0
	), (
		"decreases on each cycle after all fire cycles",
		cycles: 113, expected: (11*8+1)-113
	), (
		"stops when reaching -255",
		cycles: 517, expected: -255
	)]
	
	func testAll() {
		for test in tests {
			let riot = MOS6532()
			riot.advanceClock(cycles: 392)
			
			riot.write(self.interval, at: 0x15)
			riot.advanceClock(cycles: test.cycles)
			
			let actual = riot.read(at: 0x0c)
			XCTAssertEqual(actual, test.expected)
		}
	}
}

class MOS6532TimerInterval64Tests: XCTestCase {
	let interval = 9
	let tests = [(
		"decreases on next cycle",
		cycles: 1, expected: 8
	), (
		"does not decreases before next fire cycle",
		cycles: 58, expected: 8
	), (
		"decreases on fire cycle",
		cycles: 193, expected: 5
	), (
		"decreases to 3 after 6 fire cycles",
		cycles: 336, expected: 3
	), (
		"decreases to 0 after all fire cycles",
		cycles: 513, expected: 0
	), (
		"decreases on each cycle after all fire cycles",
		cycles: 586, expected: (8*64+1)-586
	), (
		"stops when reaching -255",
		cycles: 804, expected: -255
	)]
	
	func testAll() {
		for test in tests {
			let riot = MOS6532()
			riot.advanceClock(cycles: 392)
			
			riot.write(self.interval, at: 0x16)
			riot.advanceClock(cycles: test.cycles)
			
			let actual = riot.read(at: 0x0c)
			XCTAssertEqual(actual, test.expected)
		}
	}
}

class MOS6532TimerInterval1024Tests: XCTestCase {
	let interval = 5
	let tests = [(
		"decreases on next cycle",
		cycles: 1, expected: 4
	), (
		"does not decreases before next fire cycle",
		cycles: 1007, expected: 4
	), (
		"decreases on fire cycle",
		cycles: 2049, expected: 2
	), (
		"decreases to 3 after 2 fire cycles",
		cycles: 1025, expected: 3
	), (
		"decreases to 0 after all fire cycles",
		cycles: 4097, expected: 0
	), (
		"decreases on each cycle after all fire cycles",
		cycles: 4172, expected: (4*1024+1)-4172
	), (
		"stops when reaching -255",
		cycles: 5017, expected: -255
	)]
	
	func testAll() {
		for test in tests {
			let riot = MOS6532()
			riot.advanceClock(cycles: 392)
			
			riot.write(self.interval, at: 0x17)
			riot.advanceClock(cycles: test.cycles)
			
			let actual = riot.read(at: 0x0c)
			XCTAssertEqual(actual, test.expected)
		}
	}
}
