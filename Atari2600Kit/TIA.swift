//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

import CoreGraphics

protocol CPU {
	var ready: Bool { get set }
}

public class TIA {
	private var cpu: CPU
	private var cycles = 0
	
	init(cpu: CPU) {
		self.cpu = cpu
	}
	
	// Vertical sync register.
	var vsync: Bool = false
	// Vertical blank register.
	var vblank: Bool = false
	// Wait for horizontal sync register.
	var wsync: Bool = false
	
	// Background color register
	var columbk: Int = 0x00
	
	/// Reset sync strobe register.
	/// Writing any value resets color clock to its value at the beginning of the current scanline.
	var rsync: Bool {
		get { return false }
		set { self.cycles -= self.cycles % 228 }
	}
	
	public var frame: [CGColor] = []
	
	func advanceClock(cycles: Int) {
		self.cycles += cycles
		if self.cycles > 228 {
			self.frame.append(self.backgroundColor)
			self.cycles %= 228
			
			if self.frame.count > 262 {
				self.frame.removeAll(keepingCapacity: true)
			}
		}
	}
	
	func advanceLine() {
		let cycles = 228 - (self.cycles % 228)
		self.advanceClock(cycles: cycles)
		self.wsync = false
	}
}

private extension TIA {
	var backgroundColor: CGColor {
		let components = ntscPalette[self.columbk / 2]
		return CGColor(red: components[0], green: components[1], blue: components[2], alpha: 1.0)
	}
}

// MARK: -
// MARK: Bus integration
extension TIA: Bus {
	public func read(at address: Address) -> Int {
		return 0x00
	}
	
	public func write(_ data: Int, at address: Address) {
		switch address {
		case 0x02:
			self.wsync = true
		case 0x03:
			self.rsync = true
		case 0x09:
			self.columbk = data & 0xfe
		default:
			break
		}
	}
}

// MARK: -
// MARK: Debugging
extension TIA {
	func step(colorCycles cycles: Int) {
		self.cycles += cycles
		print("color clock: \(self.cycles % 228)")
	}
	
	func stepLine() -> Int {
		print("color clock: \(self.cycles % 228)")
		
		let cycles = 228 - self.cycles % 228
		self.cycles += cycles
		
		
		print("remains: \(cycles)")
		
		self.wsync = false
		return cycles
	}
}

extension Int {
	static let frameSize = 262 * 228
}



// MARK: -
// MARK: Color palettes
let ntscPalette: [[CGFloat]] = [
	[0x00, 0x00, 0x00],
	[0x1a, 0x1a, 0x1a],
	[0x39, 0x39, 0x39],
	[0x5b, 0x5b, 0x5b],
	[0x7e, 0x7e, 0x7e],
	[0xa2, 0xa2, 0xa2],
	[0xc7, 0xc7, 0xc7],
	[0xed, 0xed, 0xed],
	
	[0x19, 0x02, 0x00],
	[0x39, 0x1f, 0x00],
	[0x5d, 0x41, 0x00],
	[0x82, 0x64, 0x00],
	[0xa6, 0x88, 0x00],
	[0xcb, 0xad, 0x01],
	[0xf2, 0xd2, 0x18],
	[0xfe, 0xfa, 0x40],
	
	[0x37, 0x00, 0x00],
	[0x5e, 0x08, 0x00],
	[0x83, 0x26, 0x00],
	[0xa9, 0x49, 0x00],
	[0xcf, 0x6c, 0x00],
	[0xf5, 0x8f, 0x18],
	[0xfe, 0xb4, 0x38],
	[0xfd, 0xdf, 0x6f],
	
	[0x47, 0x00, 0x00],
	[0x73, 0x00, 0x00],
	[0x98, 0x14, 0x01],
	[0xbe, 0x31, 0x16],
	[0xe4, 0x52, 0x34],
	[0xfe, 0x76, 0x57],
	[0xfe, 0x9c, 0x81],
	[0xfe, 0xc6, 0xbb],
	
	[0x44, 0x00, 0x09],
	[0x70, 0x00, 0x1f],
	[0x96, 0x05, 0x3f],
	[0xbb, 0x23, 0x63],
	[0xe1, 0x45, 0x85],
	[0xfe, 0x67, 0xaa],
	[0xfe, 0x8c, 0xd7],
	[0xfe, 0xb7, 0xf6],
	
	[0x2d, 0x00, 0x4a],
	[0x57, 0x00, 0x67],
	[0x7d, 0x06, 0x8c],
	[0xa1, 0x21, 0xb1],
	[0xa1, 0x43, 0xd7],
	[0xed, 0x64, 0xfe],
	[0xfe, 0x8a, 0xf6],
	[0xfe, 0xb5, 0xf7],
	
	[0x0d, 0x01, 0x81],
	[0x33, 0x00, 0xa2],
	[0x55, 0x0e, 0xc9],
	[0x78, 0x2c, 0xf0],
	[0x9c, 0x4e, 0xfe],
	[0xc3, 0x73, 0xfe],
	[0xeb, 0x98, 0xfe],
	[0xfe, 0xc0, 0xfa],
	
	[0x07, 0x00, 0x91],
	[0x0b, 0x05, 0xbd],
	[0x28, 0x21, 0xe4],
	[0x48, 0x42, 0xfe],
	[0x6b, 0x64, 0xfe],
	[0x90, 0x8a, 0xfe],
	[0xb7, 0xb0, 0xfe],
	[0xdf, 0xd8, 0xfe],
	
	[0x04, 0x00, 0x72],
	[0x01, 0x1d, 0xab],
	[0x03, 0x3c, 0xd6],
	[0x20, 0x5e, 0xfd],
	[0x40, 0x81, 0xfe],
	[0x64, 0xa6, 0xfe],
	[0x89, 0xce, 0xfe],
	[0xaf, 0xf6, 0xfe],
	
	[0x00, 0x10, 0x3b],
	[0x00, 0x31, 0x6e],
	[0x00, 0x55, 0xa2],
	[0x05, 0x79, 0xc8],
	[0x23, 0x9d, 0xef],
	[0x44, 0xc2, 0xfe],
	[0x68, 0xe9, 0xfe],
	[0xf8, 0xfe, 0xfe],
	
	[0x00, 0x1f, 0x02],
	[0x00, 0x43, 0x26],
	[0x00, 0x69, 0x57],
	[0x00, 0x8d, 0x7a],
	[0x19, 0xb1, 0x9e],
	[0x3a, 0xd7, 0xc3],
	[0x5d, 0xfe, 0xe9],
	[0x86, 0xfe, 0xff],
	
	[0x00, 0x24, 0x03],
	[0x01, 0x4a, 0x06],
	[0x00, 0x70, 0x0d],
	[0x0a, 0x95, 0x2b],
	[0x28, 0xba, 0x4c],
	[0x49, 0xe0, 0x6e],
	[0x6c, 0xfe, 0x92],
	[0x96, 0xfe, 0xb5],
	
	[0x00, 0x21, 0x02],
	[0x01, 0x46, 0x04],
	[0x08, 0x6b, 0x01],
	[0x27, 0x90, 0x00],
	[0x4a, 0xb5, 0x09],
	[0x6a, 0xdb, 0x27],
	[0x8e, 0xfe, 0x4a],
	[0xba, 0xfe, 0x69],
	
	[0x00, 0x15, 0x01],
	[0x10, 0x36, 0x00],
	[0x30, 0x59, 0x00],
	[0x53, 0x7e, 0x01],
	[0x76, 0xa3, 0x00],
	[0x9a, 0xc8, 0x00],
	[0xbf, 0xee, 0x1d],
	[0xe8, 0xfe, 0x3e],
	
	[0x1a, 0x02, 0x00],
	[0x3b, 0x1f, 0x00],
	[0x5e, 0x41, 0x00],
	[0x84, 0x63, 0x00],
	[0xa8, 0x88, 0x00],
	[0xce, 0xad, 0x00],
	[0xf4, 0xd2, 0x18],
	[0xfe, 0xfa, 0x40],
	
	[0x38, 0x00, 0x00],
	[0x5f, 0x08, 0x00],
	[0x84, 0x28, 0x01],
	[0xaa, 0x49, 0x00],
	[0xcf, 0x6c, 0x00],
	[0xf6, 0x8f, 0x17],
	[0xfe, 0xb4, 0x38],
	[0xfd, 0xdf, 0x71]
]
