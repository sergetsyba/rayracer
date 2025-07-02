//
//  TIA.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 29.6.2023.
//

public class TIA {
	private(set) public var players = (Player(), Player())
	private(set) public var missiles = (Missile(), Missile())
	private(set) public var ball = Ball()
	private(set) public var playfield = Playfield()
	
	private var colors = Array(repeating: 0, count: 4)
	private var collisions = 0
	
	public var peripheral: Peripheral = .none
	public var output: GraphicsOutput?
	
	private var input = 0x0
	private var buffer = Array(repeating: 0, count: 4*20)
	
	public init() {
		self.verticalSync = false
		self.verticalBlank = false
		self.awaitsHorizontalSync = false
		
		self.colorClock = 0
		self.horizontalBlankResetClock = 68
		self.hmove = false
	}
	
	/// Indicates whether TIA is currenlty transmitting the vertical sync signal.
	private(set) public var verticalSync: Bool {
		didSet {
			if oldValue && !self.verticalSync {
				self.output?
					.sync(.vertical)
			}
		}
	}
	
	private(set) public var verticalBlank: Bool
	
	public var horizontalBlank: Bool {
		return self.colorClock < self.horizontalBlankResetClock
	}
	
	/// Indicates whether TIA is currently waiting on horizontal sync.
	private(set) public var awaitsHorizontalSync: Bool
	
	/// Color clock within the current scan line.
	private(set) public var colorClock: Int {
		didSet {
			if colorClock == 228 {
				self.awaitsHorizontalSync = false
				self.horizontalBlankResetClock = 68
				self.hmove = false
				
				self.colorClock = 0
				self.output?
					.sync(.horizontal)
			}
		}
	}
	
	private var horizontalBlankResetClock: Int
	private var hmove: Bool
	
	/// Resets TIA.
	public func reset() {
		self.verticalSync = false
		self.colorClock = 0
	}
	
	private var color: Int {
		let state = self.graphicsState(at: self.colorClock - 68)
		let objectIndex = Self.graphicsLookUp[state]
		let color = self.colors[objectIndex]
		
		let collisions = Self.collisionsLookUp[state & 0x1f]
		self.collisions |= collisions
		
		return color
	}
	
	/// Advances color clock by 1 unit.
	public func advanceClock() {
		let color: Int
		if self.colorClock < 68 {
			// horizontal blank
			color = 0
		} else {
			color = self.color
		}
		
		self.output?
			.write(color: color)
		
		if self.colorClock == self.horizontalBlankResetClock - 1 && self.hmove {
			self.players.0.move()
			self.players.1.move()
		}
		
		if self.colorClock >= self.horizontalBlankResetClock {
			self.players.0.advanceClock()
			self.missiles.0.advanceClock()
			self.players.1.advanceClock()
			self.missiles.1.advanceClock()
			self.ball.advanceClock()
		}
		
		self.colorClock += 1
	}
}

extension TIA {
	public enum GraphicsSync {
		case horizontal
		case vertical
	}
	
	/// TIA outputs color signals in a raster scan for at most 262 scanlines, with 160 signals in each.
	/// The number of scanlines with actual graphics in them is controlled by a program via
	/// the VBLANK register.
	public protocol GraphicsOutput {
		/// Signals the start of a new scan line or field.
		mutating func sync(_ sync: GraphicsSync)
		/// Signals the next color value.
		mutating func write(color: Int)
	}
	
	/// One of six objects TIA draws on screen.
	public protocol Drawable {
		/// Returns `true` when this object should be drawn at the specified position in the scan
		/// line; returns `false` otherwise.
		func draws(at position: Int) -> Bool
	}
	
	public protocol Peripheral {
		func read() -> Int
	}
}

extension TIA {
	private func graphicsState(at point: Int) -> Int {
		var state = 0
		state[0] = self.players.0.draws
		//		state[1] = self.missiles.0.draws
		state[2] = self.players.1.draws
		//		state[3] = self.missiles.1.draws
		state[4] = self.ball.draws
		state[5] = self.playfield.draws(at: point)
		
		state[6] = self.playfield.control[.scoreMode]
		state[7] = point < 80
		
		return state
	}
	
	private static let graphicsLookUp = (0x00...0xff)
		.map() {
			// player/missile 0
			if $0[0] || $0[1] {
				return 0
			}
			// player/missile 1
			if $0[2] || $0[3] {
				return 1
			}
			// ball
			if $0[4] {
				return 2
			}
			// playfield
			if $0[5] {
				// score mode
				if $0[6] {
					return $0[6] ? 0 : 1
				} else {
					return 2
				}
			}
			// background
			return 3
		}
	
	private static let collisionsLookUp: [Int] = (0x00...0x1f)
		.map() {
			var collisions = 0
			// cxm0p
			collisions[0] = $0[1] && $0[0]
			collisions[1] = $0[1] && $0[2]
			// cxm1p
			collisions[2] = $0[3] && $0[2]
			collisions[3] = $0[3] && $0[0]
			// cxp0fb
			collisions[4] = $0[0] && $0[4]
			collisions[5] = $0[0] && $0[5]
			// cxp1fb
			collisions[6] = $0[2] && $0[4]
			collisions[7] = $0[2] && $0[5]
			// cxm0fb
			collisions[8] = $0[1] && $0[4]
			collisions[9] = $0[1] && $0[5]
			// cxm1fb
			collisions[10] = $0[3] && $0[4]
			collisions[11] = $0[3] && $0[5]
			// cxblpf
			collisions[12] = $0[4] && $0[5]
			// cxppmm
			collisions[13] = $0[1] && $0[3]
			collisions[14] = $0[0] && $0[2]
			
			return collisions
		}
}


// MARK: -
// MARK: Bus integration
extension TIA: Addressable {
	public func read(at address: Int) -> Int {
		switch address % 0x10 {
		case 0x00:
			// MARK: CXM0P
			return ((self.collisions & 0x3) << 6) | address
		case 0x01:
			// MARK: CXM1P
			return ((self.collisions & 0xc) << 4) | address
		case 0x02:
			// MARK: CXP0FB
			return ((self.collisions & 0x30) << 2) | address
		case 0x03:
			// MARK: CXP1FB
			return (self.collisions & 0xc0) | address
		case 0x04:
			// MARK: CXM0FB
			return ((self.collisions & 0x300) >> 2) | address
		case 0x05:
			// MARK: CXM1FB
			return ((self.collisions & 0xc00) >> 4) | address
		case 0x06:
			// MARK: CXBLPF
			return ((self.collisions & 0x1000) >> 5) | address
		case 0x07:
			// MARK: CXPPMM
			return ((self.collisions & 0x6000) >> 7) | address
			
		case 0x08:
			// MARK: INPT0
			return (self.input << 7) & 0x80
		case 0x09:
			// MARK: INPT1
			return (self.input << 6) & 0x80
		case 0x0a:
			// MARK: INPT2
			return (self.input << 5) & 0x80
		case 0x0b:
			// MARK: INPT3
			return (self.input << 4) & 0x80
		case 0x0c:
			// MARK: INPT4
			let data = self.peripheral.read()
			return (data << 3) & 0x80
		case 0x0d:
			// MARK: INPT5
			let data = self.peripheral.read()
			return (data << 2) & 0x80
		default:
			return .random(in: 0x00..<0x100)
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		switch address {
		case 0x00:	// MARK: VSYNC
			self.verticalSync = data[1]
		case 0x01:	// MARK: VBLANK
			self.verticalBlank = data[1]
		case 0x02:	// MARK: WSYNC
			// NOTE: when last CPU clock cycle of a write instruction coincides
			// with last three TIA color clocks in a scan line, WSYNC will
			// incorrectly stay on for an extra scanline, since it is reset at
			// the end of each TIA color clock cycle emulation, but the writing
			// CPU clock cycle is executed after that in console clock
			// emulation;
			// ensuring color clock is not reset guards against this edge case
			self.awaitsHorizontalSync = self.colorClock > 0
		case 0x03:	// MARK: RSYNC
			self.colorClock = 0
			
		case 0x04:	// MARK: NUSIZ0
			self.players.0.copies = data & 0x7
			self.missiles.0.copies = data & 0x7
			self.missiles.0.size = 1 << ((data >> 4) & 0x3)
			
		case 0x05:	// MARK: NUSIZ1
			self.players.1.copies = data & 0x7
			self.missiles.1.copies = data & 0x7
			self.missiles.1.size = 1 << ((data >> 4) & 0x3)
			
		case 0x06:	// MARK: COLUP0
			self.colors[0] = data
		case 0x07:	// MARK: COLUP1
			self.colors[1] = data
		case 0x08:	// MARK: COLUPF
			self.colors[2] = data
		case 0x09:	// MARK: COLUBK
			self.colors[3] = data
			
		case 0x0a:	// MARK: CTRLPF
			self.playfield.control = Playfield.Control(rawValue: data & 0x3)
			self.ball.size = 1 << ((data >> 4) & 0x3)
		case 0x0d:	// MARK: PF0
			self.playfield.graphics[0] = UInt8(data)
		case 0x0e:	// MARK: PF1
			self.playfield.graphics[1] = UInt8(Int(reversingBits: data))
		case 0x0f:	// MARK: PF2
			self.playfield.graphics[2] = UInt8(data)
		case 0x0b:	// MARK: REFP0
			self.players.0.reflected = data[3]
		case 0x0c:	// MARK: REFP1
			self.players.1.reflected = data[3]
			
		case 0x10:	// MARK: RESP0
			self.players.0.reset()
		case 0x11:	// MARK: RESP1
			self.players.1.reset()
		case 0x12:	// MARK: RESM0
			self.missiles.0.reset()
		case 0x13:	// MARK: RESM1
			self.missiles.1.reset()
		case 0x14:	// MARK: RESBL
			self.ball.reset()
			
		case 0x1b:	// MARK: GRP0
			self.players.0.graphics.0 = UInt8(data)
			self.players.1.graphics.1 = self.players.1.graphics.0
		case 0x1c:	// MARK: GRP1
			self.players.1.graphics.0 = UInt8(data)
			self.players.0.graphics.1 = self.players.0.graphics.0
			self.ball.enabled.1 = self.ball.enabled.0
			
		case 0x1d:	// MARK: ENAM0
			self.missiles.0.enabled = data[1]
		case 0x1e:	// MARK: ENAM1
			self.missiles.1.enabled = data[1]
		case 0x1f:	// MARK: ENABL
			self.ball.enabled.0 = data[1]
			
		case 0x20:	// MARK: HMP0
			self.players.0.motion = (data >> 4) ^ 0x8
		case 0x21:	// MARK: HMP1
			self.players.1.motion = (data >> 4) ^ 0x8
		case 0x22:	// MARK: HMM0
			self.missiles.0.motion = (data >> 4) ^ 0x8
		case 0x23:	// MARK: HMM1
			self.missiles.1.motion = (data >> 4) ^ 0x8
		case 0x24:	// MARK: HMBL
			self.ball.motion = (data >> 4) ^ 0x8
			
		case 0x25:	// MARK: VDELP0
			self.players.0.delayed = data[0]
		case 0x26:	// MARK: VDELP1
			self.players.1.delayed = data[0]
		case 0x27:	// MARK: VDELBL
			self.ball.delayed = data[0]
			
		case 0x2a:	// MARK: HMOVE
			self.horizontalBlankResetClock += 8
			self.hmove = true
			
		case 0x2b:	// MARK: HMCLR
			self.players.0.motion = 0
			self.players.1.motion = 0
			self.missiles.0.motion = 0
			self.missiles.1.motion = 0
			self.ball.motion = 0
			
		case 0x2c:	// MARK: CXCLR
			self.collisions = 0
		default:
			break
		}
	}
}


// MARK: -
// MARK: Convenience functionality
public extension Int {
	init(reversingBits value: Int) {
		self = 0
		for bit in 0..<8 {
			self[bit] = value[7-bit]
		}
	}
}


// MARK: -
private extension TIA.Peripheral where Self == NoPeripheral {
	static var none: Self {
		return NoPeripheral()
	}
}

private struct NoPeripheral: TIA.Peripheral {
	func read() -> Int {
		return .random(in: 0x00...0xff)
	}
}
