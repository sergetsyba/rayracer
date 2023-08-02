//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

import CoreGraphics
import Combine
import Cocoa

protocol CPU {
	var ready: Bool { get set }
}

public class TIA {
	private var eventSubject = PassthroughSubject<Event, Never>()
	
	private var cpu: CPU
	init(cpu: CPU) {
		self.cpu = cpu
	}
	
	public var data = Data(count: 228*262)
	
	private var cycle = 0
	
	// Vertical sync register.
	var vsync: Bool = false {
		didSet {
			if self.vsync == true {
				self.eventSubject.send(.frame)
				self.cycle = 0
			}
		}
	}
	// Vertical blank register.
	var vblank: Bool = false
	// Wait for horizontal sync register.
	var wsync: Bool = false
	
	// Player 0 and missile 0 color and luminosity register.
	var colup0: Int = 0x00
	// Player 1 and missile 1 color and luminosity register.
	var colup1: Int = 0x00
	// Playfield and ball color and luminosity register.
	var colupf: Int = 0x00
	// Background color and luminosity register.
	var colubk: Int = 0x00
	
	
	var pf0: Int = 0x00 {
		didSet {
			self.playfiled &= 0x00ffff
			self.playfiled |= (self.pf0 >> 4) << 16
		}
	}
	var pf1: Int = 0x00 {
		didSet {
			self.playfiled &= 0xff00ff
			self.playfiled |= (self.pf1) << 8
		}
	}
	var pf2: Int = 0x00 {
		didSet {
			self.playfiled &= (self.pf2)
		}
	}
	var ctrlpf: Int = 0x00
	
	var playfiled: Int = 0x00
	
	/// Reset sync strobe register.
	/// Writing any value resets color clock to its value at the beginning of the current scanline.
	var rsync: Bool {
		get { return false }
		set { self.cycle -= self.cycle % 228 }
	}
	
	func advanceClock(cycles: Int) {
		for _ in 0..<cycles {
			self.drawPoint()			
			self.cycle += 1
		}
	}
	
	func advanceLine() {
		let cycles = 228 - (self.cycle % 228)
		self.advanceClock(cycles: cycles)
		self.wsync = false
	}
}


// MARK: -
// MARK: Drawing
extension TIA {
	var backgroundColor: UInt8 {
		return UInt8(self.colubk) / 2
	}
	
	func drawPoint() {
		let x = self.cycle % 228
		let y = self.cycle / 228
		
		guard y >= 3+37
				&& y < 3+37+192
				&& x >= 68 else {
			return
		}
		
		self.data[self.cycle] = self.backgroundColor
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
		case 0x00:
			self.vsync = data[1]
		case 0x01:
			self.vblank = data[1]
		case 0x02:
			self.wsync = true
		case 0x03:
			self.rsync = true
			
		case 0x06:
			self.colup0 = data
		case 0x07:
			self.colup1 = data
		case 0x08:
			self.colupf = data
		case 0x09:
			self.colubk = data
		case 0x0a:
			self.ctrlpf = data
		case 0x0d:
			self.pf0 = data
		case 0x0e:
			self.pf1 = data
		case 0x0f:
			self.pf2 = data
		default:
			break
		}
	}
}

// MARK: -
// MARK: Debugging
public extension TIA {
	enum Event {
		case frame
	}
	
	var events: some Publisher<Event, Never> {
		return self.eventSubject
	}
}

extension Int {
	static let frameSize = 262 * 228
}


private extension CGRect {
	static let ntsc = CGRect(x: 0.0, y: 0.0, width: 160.0, height: 192.0)
}


extension CGColor {
	static var random: CGColor {
		return CGColor(
			red: .random(in: 0.0...1.0),
			green: .random(in: 0.0...1.0),
			blue: .random(in: 0.0...1.0),
			alpha: 1.0)
	}
}

private extension UInt32 {
	subscript(bit: Int) -> Bool {
		get {
			let mask: UInt32 = 0x01 << bit
			return self & mask == mask
		}
		set {
			let mask: UInt32 = 0x01 << bit
			if newValue {
				self |= mask
			} else {
				self &= ~mask
			}
		}
	}
}
