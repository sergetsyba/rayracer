//
//  DebuggerView.swift
//  Atari2600
//
//  Created by Serge Tsyba on 22.5.2023.
//

import SwiftUI
import Atari2600Kit

struct DebuggerView: View {
	var console = Atari2600()
	
	var body: some View {
		ScrollView {
			VStack(spacing: 10.0) {
				let memory = self.console.memory
				MemorySegmentView(memory: memory.tiaRegisters)
				MemorySegmentView(memory: memory.ram)
				MemorySegmentView(memory: memory.riotRegisters)
				//				MemorySegmentView(memory: memory.rom)
			}
			.font(.system(size: 11.0, design: .monospaced))
		}
	}
}

struct MemorySegmentView<Memory: RandomAccessCollection>: View
where Memory.Element == UInt8, Memory.Index == Int {
	
	var memory: Memory
	
	var body: some View {
		let columnCount = 16
		let rowCount = self.memory.count / columnCount
		
		VStack {
			ForEach(0..<rowCount, id: \.self) { index1 in
				HStack {
					ForEach(0..<columnCount, id: \.self) { index2 in
						let offset = columnCount * index1 + index2
						let index = self.memory.index(self.memory.startIndex, offsetBy: offset)
						let value = self.memory[index]
						Text(value.hexFormatted)
					}
				}
			}
		}
	}
}

private extension RandomAccessCollection where Element == UInt8, Index == Int {
	var tiaRegisters: Self.SubSequence {
		return self[0x0000..<0x007f]
	}
	
	var ram: Self.SubSequence {
		return self[0x0080..<0x00ff]
	}
	
	var riotRegisters: Self.SubSequence {
		return self[0x0200..<0x02ff]
	}
	
	var rom: Self.SubSequence {
		return self[0x1000..<0x1fff]
	}
}

private extension UInt8 {
	var hexFormatted: String {
		return String(format: "%02x", self)
	}
}
