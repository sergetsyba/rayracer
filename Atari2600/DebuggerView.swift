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
			Grid {
				GridRow {
					Text("Accumulator:")
						.gridColumnAlignment(.trailing)
					Text(self.console.cpu.accumulator.formattedData)
					
					Text("Program counter:")
						.gridColumnAlignment(.trailing)
					Text(self.console.cpu.programCounter.formattedMemory)
				}
				GridRow {
					Text("Index X:")
					Text(self.console.cpu.x.formattedData)
					
					Text("Stack pointer:")
					Text(self.console.cpu.stackPointer.formattedMemory)
				}
				GridRow {
					Text("Index Y:")
					Text(self.console.cpu.y.formattedData)
				}
				GridRow {
					let status = self.console.cpu.status
					Text("Status:")
					HStack {
						Text("N")
							.opacity(status.negative ? 1.0 : 0.5)
						Text("V")
							.opacity(status.overflow ? 1.0 : 0.5)
						Text(" ")
						Text("D")
							.opacity(status.decimal ? 1.0 : 0.5)
						Text("I")
							.opacity(status.interrupt ? 1.0 : 0.5)
						Text("Z")
							.opacity(status.zero ? 1.0 : 0.5)
						Text("C")
							.opacity(status.carry ? 1.0 : 0.5)
					}
					.gridColumnAlignment(.leading)
//					.gridCellColumns(2)
				}
			}
			
			ScrollView {
				VStack(spacing: 10.0) {
					let memory = self.console.memory
					Text(memory.tiaRegisters.hexFormatted)
					Text(memory.ram.hexFormatted)
					Text(memory.riotRegisters.hexFormatted)
					Text(memory.rom.hexFormatted)
				}
			}
		}.font(.system(size: 11.0, design: .monospaced))
	}
}


// MARK: -
// MARK: Data formatting
private extension Int {
	var formattedData: String {
		return String(format: "%02x", self)
	}
	
	var formattedMemory: String {
		return String(format: "$%04x", self)
	}
}


private extension Memory {
	var hexFormatted: String {
		return ""
//		return stride(from: self.startIndex, to: self.endIndex - 1, by: 16)
//			.map() { self.formatRow(at: $0) }
//			.joined(separator: "\n")
	}
	
	func formatRow(at startIndex: Self.Index) -> String {
		return (startIndex..<startIndex + 16)
			.map() { String(format: "%02x", self[$0]) }
			.joined(separator: " ")
	}
}
