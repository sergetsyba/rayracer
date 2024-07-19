//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

import CoreGraphics
import Combine
import Cocoa

public class TIA {
	private(set) public var data = Data(count: 228*262)
	private var eventSubject = PassthroughSubject<Event, Never>()
	
	var cycle = 0
	
	// Vertical sync register.
	var vsync: Int = -1
	// Vertical blank register.
	var vblank: Bool = false
	// Wait for horizontal sync register.
	var wsync: Bool = false
	
	private(set) public var backgroundColor: Int
	private(set) public var playfield: Int
	private(set) public var playfieldControl: Int
	private(set) public var playfieldColor: Int
	
	private(set) public var numberSize0: Int
	private(set) public var numberSize1: Int
	
	private(set) public var player0Graphics: (Int, Int)
	private(set) public var player0Reflected: Bool
	private(set) public var player0Color: Int
	private(set) public var player0Position: Int
	private(set) public var player0Motion: Int
	private(set) public var player0Delay: Bool
	
	private(set) public var player1Graphics: (Int, Int)
	private(set) public var player1Reflected: Bool
	private(set) public var player1Color: Int
	private(set) public var player1Position: Int
	private(set) public var player1Motion: Int
	private(set) public var player1Delay: Bool
	
	private(set) public var missile0Enabled: Bool
	private(set) public var missile0Position: Int
	private(set) public var missile0Motion: Int
	
	private(set) public var missile1Enabled: Bool
	private(set) public var missile1Position: Int
	private(set) public var missile1Motion: Int
	
	init() {
		self.backgroundColor = .random(in: 0x00...0x7f)
		
		self.playfield = .random(in: 0x0...0xf0ffff)
		self.playfieldControl = .random(in: 0x00...0xff)
		self.playfieldColor = .random(in: 0x00...0x7f)
		
		self.numberSize0 = .random(in: 0x00...0xff)
		self.numberSize1 = .random(in: 0x00...0xff)
		
		self.player0Graphics = (.random(in: 0x00...0xff), .random(in: 0x00...0xff))
		self.player0Reflected = .random()
		self.player0Color = .random(in: 0x00...0x7f)
		self.player0Position = .random(in: 5...159)
		self.player0Motion = .random(in: -8...7)
		self.player0Delay = .random()
		
		self.player1Graphics = (.random(in: 0x00...0xff), .random(in: 0x00...0xff))
		self.player1Reflected = .random()
		self.player1Color = .random(in: 0x00...0x7f)
		self.player1Position = .random(in: 5...159)
		self.player1Motion = .random(in: -8...7)
		self.player1Delay = .random()
		
		self.missile0Enabled = .random()
		self.missile0Position = .random(in: 4...159)
		self.missile0Motion = .random(in: -8...7)
		
		self.missile1Enabled = .random()
		self.missile1Position = .random(in: 4...159)
		self.missile1Motion = .random(in: -8...7)
	}
	
	func reset() {
		self.data = Data(count: 228*262)
		self.cycle = 0
		self.eventSubject.send(.frame)
	}
	
	func advanceClock(cycles: Int) {
		for _ in 0..<cycles {
			self.drawPoint()
			self.cycle += 1
		}
	}
	
	func advanceClockToHorizontalSync() {
		let colorClock = self.cycle % 228
		if colorClock > 0 {
			self.advanceClock(cycles: 228 - colorClock)
		}
		
		self.wsync = false
	}
	
	func emitFrame() {
		self.eventSubject.send(.frame)
	}
}


// MARK: -
// MARK: Conveniece registers
extension TIA {
	public var playfieldReflected: Bool {
		return self.playfieldControl[0]
	}
	
	public var player0Copies: Int {
		return self.numberSize0 & 0x3
	}
	
	public var player1Copies: Int {
		return self.numberSize1 & 0x3
	}
	
	public var missile0Size: Int {
		return 1 << ((self.numberSize0 >> 4) & 0x3)
	}
	
	public var missile1Size: Int {
		return 1 << ((self.numberSize1 >> 4) & 0x3)
	}
}


// MARK: -
// MARK: Drawing
extension TIA {
	func drawPoint() {
		let y = self.cycle / 228 - 30//(3+37)
		let x = self.cycle % 228 - 68
		
		guard y >= 0 && y < 192
				&& x >= 0 else {
			return
		}
		
		// draw background
		self.data[self.cycle] = UInt8(self.backgroundColor) >> 1
		self.drawPlayfield(x: x, y: y)
		self.drawMissile1(at: x)
		self.drawPlayer1(at: x)
		self.drawMissile0(at: x)
		self.drawPlayer0(at: x)
	}
	
	func drawPlayfield(x: Int, y: Int) {
		if x < 160/2 {
			// left playfield side
			if self.playfield[x/4] {
				self.data[self.cycle] = self.playfieldControl[1]
				? UInt8(self.player0Color) >> 1
				: UInt8(self.playfieldColor) >> 1
			}
		} else {
			// right playfield side
			var bit = x/4-20
			if self.playfieldControl[0] {
				// mirrorred right playfield side
				bit = 20-bit
			}
			
			if self.playfield[bit] {
				self.data[self.cycle] = self.playfieldControl[1]
				? UInt8(self.player1Color) >> 1
				: UInt8(self.playfieldColor) >> 1
			}
		}
	}
	
	func drawPlayer0(at point: Int) {
		let counter = point - self.player0Position
		guard counter >= 0 else {
			return
		}
		
		let copies = self.numberSize0 & 0x3
		switch (counter / 8, copies) {
		case (0, _),
			(2, 1), (2, 3),
			(4, 2), (4, 3), (4, 6),
			(8, 4), (8, 6):
			
			let graphics = self.player0Delay
			? self.player0Graphics.1
			: self.player0Graphics.0
			
			let bit = self.player0Reflected
			? counter % 8
			: 7 - (counter % 8)
			
			if graphics[bit] {
				self.data[self.cycle] = UInt8(self.player0Color) >> 1
			}
			
		default:
			return
		}
	}
	
	func drawPlayer1(at point: Int) {
		let counter = point - self.player1Position
		guard counter >= 0 else {
			return
		}
		
		let copies = self.numberSize1 & 0x3
		switch (counter / 8, copies) {
		case (0, _),
			(2, 1), (2, 3),
			(4, 2), (4, 3), (4, 6),
			(8, 4), (8, 6):
			
			let graphics = self.player1Delay
			? self.player1Graphics.1
			: self.player1Graphics.0
			
			let bit = self.player1Reflected
			? counter % 8
			: 7 - (counter % 8)
			
			if graphics[bit] {
				self.data[self.cycle] = UInt8(self.player1Color) >> 1
			}
			
		default:
			return
		}
	}
	
	func drawMissile0(at point: Int) {
		guard self.missile0Enabled else {
			return
		}
		
		let point = point - self.missile0Position
		if (0..<self.missile0Size).contains(point) {
			self.data[self.cycle] = UInt8(self.player0Color) >> 1
		}
	}
	
	func drawMissile1(at point: Int) {
		guard self.missile1Enabled else {
			return
		}
		
		let point = point - self.missile1Position
		if (0..<self.missile1Size).contains(point) {
			self.data[self.cycle] = UInt8(self.player1Color) >> 1
		}
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
			if data[1] {
				self.vsync = self.cycle
			} else {
				if self.vsync > -1 {
					let scanLines = (self.cycle - self.vsync) / 228
					if scanLines >= 3 {
						// TODO: Stella sets color clock to the beginning of store operation instead of it end
						self.cycle = 9
						self.eventSubject.send(.frame)
					}
				}
				
				self.vsync = -1
			}
			
		case 0x01:
			self.vblank = data[1]
		case 0x02:
			self.wsync = true
		case 0x03:
			self.advanceClockToHorizontalSync()
			self.cycle -= 3
			
		case 0x04:
			// MARK: NUSIZ0
			self.numberSize0 = data
		case 0x05:
			// MARK: NUSIZ1
			self.numberSize1 = data
		case 0x06:
			// MARK: COLUP0
			self.player0Color = data
		case 0x07:
			// MARK: COLUP1
			self.player1Color = data
		case 0x08:
			// MARK: COLUPF
			self.playfieldColor = data
		case 0x09:
			// MARK: COLUBK
			self.backgroundColor = data
		case 0x0a:
			// MARK: CTRLPF
			self.playfieldControl = data
		case 0x0d:
			// MARK: PF0
			self.playfield &= 0xffff0
			self.playfield |= data >> 4
		case 0x0e:
			// MARK: PF1
			self.playfield &= 0xff00f
			self.playfield |= Int(reversingBits: data) << 4
		case 0x0f:
			// MARK: PF2
			self.playfield &= 0x00fff
			self.playfield |= data << 12
		case 0x0b:
			// MARK: REFP0
			self.player0Reflected = data[3]
		case 0x0c:
			// MARK: REFP1
			self.player1Reflected = data[3]
		case 0x1d:
			// MARK: ENAM0
			self.missile0Enabled = data[1]
		case 0x1e:
			// MARK: ENAM1
			self.missile1Enabled = data[1]
		case 0x10:
			// MARK: RESP0
			// resetting player position takes additional 4 color clock to
			// decode and 1 to latch
			self.player0Position = max(0, self.cycle % 228 - 68) + 5
		case 0x11:
			// MARK: RESP1
			// resetting player position takes additional 4 color clock to
			// decode and 1 to latch
			self.player1Position = max(0, self.cycle % 228 - 68) + 5
		case 0x12:
			// MARK: RESM0
			// resetting missile position takes additional 4 color clocks to
			// decode
			self.missile0Position = max(0, self.cycle % 228 - 68) + 4
		case 0x13:
			// MARK: RESM1
			// resetting missile position takes additional 4 color clocks to
			// decode
			self.missile1Position = max(0, self.cycle % 228 - 68) + 4
		case 0x1b:
			// MARK: GRP0
			self.player0Graphics.0 = data
			self.player1Graphics.1 = self.player1Graphics.0
		case 0x1c:
			// MARK: GRP1
			self.player1Graphics.0 = data
			self.player0Graphics.1 = self.player0Graphics.0
		case 0x20:
			// MARK: HMP0
			self.player0Motion = Int(signed: data >> 4, bits: 4)
		case 0x21:
			// MARK: HMP1
			self.player1Motion = Int(signed: data >> 4, bits: 4)
		case 0x22:
			// MARK: HMM0
			self.missile0Motion = Int(signed: data >> 4, bits: 4)
		case 0x23:
			// MARK: HMM1
			self.missile1Motion = Int(signed: data >> 4, bits: 4)
		case 0x25:
			// MARK: VDELP0
			self.player0Delay = data[0]
		case 0x26:
			// MARK: VDELP1
			self.player1Delay = data[0]
		case 0x2a:
			// MARK: HMOVE
			self.player0Position -= self.player0Motion
			self.player1Position -= self.player1Motion
			self.missile0Position -= self.missile0Motion
			self.missile1Position -= self.missile1Motion
		case 0x2b:
			// MARK: HMCLR
			self.missile0Motion = 0
			self.missile1Motion = 0
			
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

public extension Int {
	static let frameSize = 262 * 228
	
	init(reversingBits value: Int) {
		self = 0
		for bit in 0..<8 {
			self[bit] = value[7-bit]
		}
	}
	
	init(bits: [Bool]) {
		// TODO: re-implement with a look-up table
		self = 0
		for bit in bits {
			self <<= 1
			self &= bit ? 0x1 : 0x0
		}
	}
	
	subscript (range: any Collection<Int>) -> [Bool] {
		return range.map({ self[$0] })
	}
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
