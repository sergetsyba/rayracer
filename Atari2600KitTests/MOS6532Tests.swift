//
//  MOS6532Tests.swift
//  Atari2600KitTests
//
//  Created by Serge Tsyba on 4.7.2023.
//

import XCTest
@testable import Atari2600Kit

class MOS6532TimerInterval1Tests: XCTestCase {
	func testSetsTimer() {
		self.test(cycles: 0, expected: 17)
	}
	
	func testDecreasesByOneOnNextCycle() {
		self.test(cycles: 1, expected: 16)
	}
	
	func testDecreasesByOneOnEachInterval() {
		self.test(cycles: 4, expected: 13)
	}
	
	func testDecreasesToZeroOnLastInterval() {
		self.test(cycles: 17, expected: 0)
	}
	
	func testDecreasesByOneOnEachCycleAfterAllIntervals() {
		self.test(cycles: 24, expected: 17-24)
	}
	
	func testStopsWhenReachingLimit() {
		self.test(cycles: 294, expected: -255)
	}
	
	private func test(cycles: Int, expected: Int) {
		let riot = MOS6532()
		riot.advanceClock(cycles: .random)
		
		riot.write(17, at: 0x14)
		riot.advanceClock(cycles: cycles)
		
		let actual = riot.read(at: 0x0c)
		XCTAssertEqual(actual, expected)
	}
}

class MOS6532TimerInterval8Tests: XCTestCase {
	func testSetsTimer() {
		self.test(cycles: 0, expected: 12)
	}
	
	func testDecreasesByOneOnNextCycle() {
		self.test(cycles: 1, expected: 11)
	}
	
	func testDoesNotDecreasesBeforeNextInterval() {
		self.test(cycles: 7, expected: 11)
	}
	
	func testDecreasesAtIntervalCycle() {
		self.test(cycles: 9, expected: 10)
	}
	
	func testDecreasesByOneOnEachInterval() {
		self.test(cycles: 37, expected: 7)
	}
	
	func testDecreasesToZeroOnLastInterval() {
		self.test(cycles: 94, expected: 0)
	}
	
	func testDecreasesByOneOnEachCycleAfterAllIntervals() {
		self.test(cycles: 133, expected: (12*8)-133)
	}
	
	func testStopsWhenReachingLimit() {
		self.test(cycles: 517, expected: -255)
	}
	
	private func test(cycles: Int, expected: Int) {
		let riot = MOS6532()
		riot.advanceClock(cycles: .random)
		
		riot.write(12, at: 0x15)
		riot.advanceClock(cycles: cycles)
		
		let actual = riot.read(at: 0x0c)
		XCTAssertEqual(actual, expected)
	}
}

class MOS6532TimerInterval64Tests: XCTestCase {
	func testSetsTimer() {
		self.test(cycles: 0, expected: 9)
	}
	
	func testDecreasesByOneOnNextCycle() {
		self.test(cycles: 1, expected: 8)
	}
	
	func testDoesNotDecreasesBeforeNextInterval() {
		self.test(cycles: 58, expected: 8)
	}
	
	func testDecreasesAtIntervalCycle() {
		self.test(cycles: 193, expected: 5)
	}
	
	func testDecreasesByOneOnEachInterval() {
		self.test(cycles: 336, expected: 3)
	}
	
	func testDecreasesToZeroOnLastInterval() {
		self.test(cycles: 513, expected: 0)
	}
	
	func testDecreasesByOneOnEachCycleAfterAllIntervals() {
		self.test(cycles: 586, expected: (9*64)-586)
	}
	
	func testStopsWhenReachingLimit() {
		self.test(cycles: 864, expected: -255)
	}
	
	private func test(cycles: Int, expected: Int) {
		let riot = MOS6532()
		riot.advanceClock(cycles: .random)
		
		riot.write(9, at: 0x16)
		riot.advanceClock(cycles: cycles)
		
		let actual = riot.read(at: 0x0c)
		XCTAssertEqual(actual, expected)
	}
}

class MOS6532TimerInterval1024Tests: XCTestCase {
	func testSetsTimer() {
		self.test(cycles: 0, expected: 5)
	}
	
	func testDecreasesByOneOnNextCycle() {
		self.test(cycles: 1, expected: 4)
	}
	
	func testDoesNotDecreasesBeforeNextInterval() {
		self.test(cycles: 1007, expected: 4)
	}
	
	func testDecreasesAtIntervalCycle() {
		self.test(cycles: 2049, expected: 2)
	}
	
	func testDecreasesByOneOnEachInterval() {
		self.test(cycles: 1025, expected: 3)
	}
	
	func testDecreasesToZeroOnLastInterval() {
		self.test(cycles: 4417, expected: 0)
	}
	
	func testDecreasesByOneOnEachCycleAfterAllIntervals() {
		self.test(cycles: 5232, expected: (5*1024)-5232)
	}
	
	func testStopsWhenReachingLimit() {
		self.test(cycles: 5742, expected: -255)
	}
	
	private func test(cycles: Int, expected: Int) {
		let riot = MOS6532()
		riot.advanceClock(cycles: .random)
		
		riot.write(5, at: 0x17)
		riot.advanceClock(cycles: cycles)
		
		let actual = riot.read(at: 0x0c)
		XCTAssertEqual(actual, expected)
	}
}


// MARK: -
// MARK: Convenience functionality
private extension Int {
	static var random: Int {
		return Self.random(in: 0..<1000)
	}
}
