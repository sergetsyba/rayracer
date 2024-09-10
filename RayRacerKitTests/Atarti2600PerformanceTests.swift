//
//  Atari2600PerformanceTests.swift
//  RayRacerKitTests
//
//  Created by Serge Tsyba on 8.9.2024.
//

import XCTest
import RayRacerKit

final class Atari2600PerformanceTests: XCTestCase {
	func testProgramExecutionPerformance() {
		let url = URL(fileURLWithPath: "/Users/Serge/Developer/Проекты/RayRacer/Games/Fantastic Voyage.bin")
		let rom = try! Data(contentsOf: url)
		
		let console = Atari2600()
		console.insertCartridge(rom)
		
		measure {
			for _ in 0..<1_000_000 {
				console.stepProgram()
			}
		}
	}
}
