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
		console.cartridge = rom
		console.reset()
		
		self.measure() {
			console.resume(instructions: 1_000_000)
		}
	}
}

class NoOutput: TIA.GraphicsOutput {
	func sync(_ sync: RayRacerKit.TIA.GraphicsSync) {
		// does nothing
	}
	
	func blank() {
		// does nothing
	}
	
	func write(color: Int) {
		// does nothing
	}
}

extension Atari2600 {
	func resume(instructions: Int) {
		var remaining = instructions
		self.resume(priority: .high, until: ({ [unowned self] in
			if self.cpu.sync
				&& !self.tia.awaitsHorizontalSync {
				remaining -= 1
			}
			return remaining == 0
		}, {}))
	}
}
