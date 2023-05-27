//
//  DebuggerView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 22.5.2023.
//

import SwiftUI
import Atari2600Kit
import Combine

struct DebuggerView: View {
	@ObservedObject var console: Atari2600
	
	init(console: Atari2600) {
		self.console = console
	}
	
	var body: some View {
		VStack {
			VStack {
				HStack {
					Text("Accumulator:")
					Text(self.console.cpu.accumulator.hexFormatted)
						.font(.system(size: 11.0, design: .monospaced))
				}
				HStack {
					Text("Index X:")
					Text(self.console.cpu.X.hexFormatted)
						.font(.system(size: 11.0, design: .monospaced))
				}
				HStack {
					Text("Accumulator:")
					Text(self.console.cpu.Y.hexFormatted)
						.font(.system(size: 11.0, design: .monospaced))
				}
				HStack {
					Text("Accumulator:")
					Text(self.console.cpu.stackPointer.hexFormatted)
						.font(.system(size: 11.0, design: .monospaced))
				}
				HStack {
					Text("Accumulator:")
					Text(self.console.cpu.programCounter.hexFormatted)
						.font(.system(size: 11.0, design: .monospaced))
				}
			}.font(.system(size: 11.0))
			
			
			ScrollView {
				VStack(spacing: 10.0) {
					let memory = self.console.memory
					Text(memory.tiaRegisters.hexFormatted)
					Text(memory.ram.hexFormatted)
					Text(memory.riotRegisters.hexFormatted)
					Text(memory.rom.hexFormatted)
				}
				.font(.system(size: 11.0, design: .monospaced))
			}
		}.toolbar {
			Button(action: self.stepOperation) {
				Label("Step", systemImage: "chevron.right.2")
			}
		}
	}
	
	func stepOperation() {
		
	}
}

private extension MOS6507.Word {
	var hexFormatted: String {
		return String(format: "%02x", self)
	}
}

private extension MOS6507.Address {
	var hexFormatted: String {
		return String(format: "%04x", self)
	}
}


private extension Memory {
	var hexFormatted: String {
		let columnCount = 16
		let rowCount = self.count / columnCount
		
		return (0..<rowCount)
			.map() { index1 in
				return (0..<columnCount)
					.map() { columnCount * index1 + $0 }
					.map() { self.index(self.startIndex, offsetBy: $0) }
					.map() { self[$0].hexFormatted }
					.joined(separator: " ")
			}.joined(separator: "\n")
	}
}
