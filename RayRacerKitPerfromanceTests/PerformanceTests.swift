//
//  PerformanceTests.swift
//  RayRacerKitPerformanceTests
//
//  Created by Serge Tsyba on 8.9.2024.
//

import XCTest
import RayRacerKit

final class PerformanceTests: XCTestCase {
	func testProgramExecutionPerformance() {
		let url = URL(fileURLWithPath: "/Users/Serge/Developer/Проекты/RayRacer/Games/Fantastic Voyage.bin")
		let rom = try! Data(contentsOf: url)
		
		let console = Atari2600()
		console.tia.output = NoOutput()
		console.insertCartridge(rom)
		
		self.measure() {
			for _ in 0..<1_000_000 {
				console.stepInstruction()
			}
		}
	}
}

class NoOutput: TIA.GraphicsOutput {
	func sync() {
		// does nothing
	}
	
	func write(color: Int) {
		// does nothing
	}
}
