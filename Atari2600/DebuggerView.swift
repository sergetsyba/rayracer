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
	}
}

private extension UInt8 {
	var hexFormatted: String {
		return String(format: "%02x", self)
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
