//
//  TIA.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 29.6.2023.
//

public class TIA {
	private(set) public var players: (Player, Player)
	private(set) public var missiles: (Missile, Missile)
	private(set) public var ball: Ball
	private(set) public var playfield: Playfield
	private(set) public var backgroundColor: Int
	
	private var screenClock = 0
	private var colors = Array(repeating: 0, count: 4)
	private var collisions = 0
	
	public var output: GraphicsOutput?
	public var peripheral: Peripheral = .none
	
	private var vblank = 0
	private var input = 0x0
	
	public init() {
		self.players = (.random(), .random())
		self.missiles = (.random(), .random())
		self.ball = .random()
		self.playfield = .random()
		self.backgroundColor = .random(in: 0x00...0x7f)
		
		self.verticalSync = false
		self.awaitsHorizontalSync = false
	}
	
	/// Indicates whether TIA is currenlty transmitting the vertical sync signal.
	private(set) public var verticalSync: Bool {
		didSet {
			if !self.verticalSync {
				self.screenClock = self.colorClock
				self.output?.sync()
			}
		}
	}
	
	/// Indicates whether TIA is currently transmitting no color signal due to electron beam being
	/// in vertical retrace.
	public var verticalBlank: Bool {
		return self.vblank[1]
	}
	
	/// Indicates whether TIA is currently waiting on horizontal sync.
	private(set) public var awaitsHorizontalSync: Bool
	
	/// Indicates whether TIA is currently transmitting no color signal due to electron beam being
	/// in horizontal retrace.
	public var horizontalBlank: Bool {
		return self.colorClock < 68
	}
	
	/// Scan line number, whose signal TIA assumes it currently is transmitting.
	public var scanLine: Int {
		return self.screenClock / 228
	}
	
	/// Color clock within the current scan line.
	private(set) public var colorClock: Int {
		get { self.screenClock % 228 }
		set { self.screenClock = self.scanLine * 228 + newValue }
	}
	
	/// Resets TIA.
	public func reset() {
		self.verticalSync = false
		self.vblank = 0
		self.screenClock = 0
	}
	
	/// Advances color clock by 1 unit.
	public func advanceClock() {
//		var input = self.peripheral.read()
//		if self.vblank[7] {
//			// when dumped ports disabled, ground
//			input &= 0xf0
//		}
//		if self.vblank[6] {
//			// when latched ports disabled, latch low
//			input &= self.input | 0x0f
//		}
//		self.input = input
		
		
		if self.verticalBlank || self.horizontalBlank {
			self.output?.write(color: 0)
		} else {
			let state = self.graphicsState(at: self.colorClock - 68)
			let objectIndex = Self.graphicsLookUp[state]
			let color = self.colors[objectIndex]
			let collisions = Self.collisionsLookUp[state & 0x1f]
			
			self.collisions |= collisions
			self.output?.write(color: color)
		}
		
		self.screenClock += 1
		
		// switch off WSYNC once color clock resets
		if self.colorClock == 0 {
			self.awaitsHorizontalSync = false
		}
	}
}

extension TIA {
	/// TIA outputs color signals in a raster scan for at most 262 scanlines, with 160 signals in each.
	/// The number of scanlines with actual graphics in them is controlled by a program via
	/// the VBLANK register.
	public protocol GraphicsOutput {
		/// Signals the start of a new field.
		mutating func sync()
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
		state[0] = self.players.0.draws(at: point)
		state[1] = self.players.1.draws(at: point)
		state[2] = self.missiles.0.draws(at: point)
		state[3] = self.missiles.1.draws(at: point)
		state[4] = self.ball.draws(at: point)
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
			collisions[0] = $0[2] && $0[0]
			collisions[1] = $0[2] && $0[1]
			// cxm1p
			collisions[2] = $0[3] && $0[1]
			collisions[3] = $0[3] && $0[0]
			// cxp0fb
			collisions[4] = $0[0] && $0[4]
			collisions[5] = $0[0] && $0[5]
			// cxp1fb
			collisions[6] = $0[1] && $0[4]
			collisions[7] = $0[1] && $0[5]
			// cxm0fb
			collisions[8] = $0[2] && $0[4]
			collisions[9] = $0[2] && $0[5]
			// cxm1fb
			collisions[10] = $0[3] && $0[4]
			collisions[11] = $0[3] && $0[5]
			// cxblpf
			collisions[12] = $0[4] && $0[5]
			// cxppmm
			collisions[13] = $0[2] && $0[3]
			collisions[14] = $0[0] && $0[1]
			
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
		case 0x00:
			// MARK: VSYNC
			self.verticalSync = data[1]
			self.screenClock = 0
		case 0x01:
			// MARK: VBLANK
			self.vblank = data
		case 0x02:
			// MARK: WSYNC
			// NOTE: when last CPU clock cycle of a write instruction coincides
			// with last three TIA color clocks in a scan line, WSYNC will
			// incorrectly stay on for an extra scanline, since it is reset at
			// the end of each TIA color clock cycle emulation, but the writing
			// CPU clock cycle is executed after that in console clock
			// emulation;
			// ensuring color clock is not reset guards against this edge case
			self.awaitsHorizontalSync = self.colorClock > 0
		case 0x03:
			// MARK: RSYNC
			self.colorClock = 0
		case 0x04:
			// MARK: NUSIZ0
			self.players.0.copies = data & 0x3
			self.missiles.0.size = 1 << ((data >> 4) & 0x3)
		case 0x05:
			// MARK: NUSIZ1
			self.players.1.copies = data & 0x3
			self.missiles.1.size = 1 << ((data >> 4) & 0x3)
		case 0x06:
			// MARK: COLUP0
			self.players.0.color = data
			self.missiles.0.color = data
			self.colors[0] = data
		case 0x07:
			// MARK: COLUP1
			self.players.1.color = data
			self.missiles.1.color = data
			self.colors[1] = data
		case 0x08:
			// MARK: COLUPF
			self.playfield.color = data
			self.colors[2] = data
		case 0x09:
			// MARK: COLUBK
			self.backgroundColor = data
			self.colors[3] = data
		case 0x0a:
			// MARK: CTRLPF
			self.playfield.control[.reflected] = data[0]
			self.playfield.control[.scoreMode] = data[1]
			self.ball.size = 1 << ((data >> 4) & 0x3)
		case 0x0d:
			// MARK: PF0
			self.playfield.graphics &= 0xffff0
			self.playfield.graphics |= data >> 4
		case 0x0e:
			// MARK: PF1
			self.playfield.graphics &= 0xff00f
			self.playfield.graphics |= Int(reversingBits: data) << 4
		case 0x0f:
			// MARK: PF2
			self.playfield.graphics &= 0x00fff
			self.playfield.graphics |= data << 12
		case 0x0b:
			// MARK: REFP0
			self.players.0.reflected = data[3]
		case 0x0c:
			// MARK: REFP1
			self.players.1.reflected = data[3]
		case 0x10:
			// MARK: RESP0
			// resetting player position takes additional 4 color clock to
			// decode and 1 to latch
			self.players.0.position = max(0, self.colorClock - 68) + 5
		case 0x11:
			// MARK: RESP1
			// resetting player position takes additional 4 color clock to
			// decode and 1 to latch
			self.players.1.position = max(0, self.colorClock - 68) + 5
		case 0x12:
			// MARK: RESM0
			// resetting missile position takes additional 4 color clocks to
			// decode
			self.missiles.0.position = max(0, self.colorClock - 68) + 4
		case 0x13:
			// MARK: RESM1
			// resetting missile position takes additional 4 color clocks to
			// decode
			self.missiles.1.position = max(0, self.colorClock - 68) + 4
		case 0x14:
			// MARK: RESBL
			self.ball.position = max(0, self.colorClock - 68) + 4
		case 0x1b:
			// MARK: GRP0
			self.players.0.graphics.0 = data
			self.players.1.graphics.1 = self.players.1.graphics.0
		case 0x1c:
			// MARK: GRP1
			self.players.1.graphics.0 = data
			self.players.0.graphics.1 = self.players.0.graphics.0
			self.ball.enabled.1 = self.ball.enabled.0
		case 0x1d:
			// MARK: ENAM0
			self.missiles.0.enabled = data[1]
		case 0x1e:
			// MARK: ENAM1
			self.missiles.1.enabled = data[1]
		case 0x1f:
			// MARK: ENABL
			self.ball.enabled.0 = data[1]
		case 0x20:
			// MARK: HMP0
			self.players.0.motion = Int(signed: data >> 4, bits: 4)
		case 0x21:
			// MARK: HMP1
			self.players.1.motion = Int(signed: data >> 4, bits: 4)
		case 0x22:
			// MARK: HMM0
			self.missiles.0.motion = Int(signed: data >> 4, bits: 4)
		case 0x23:
			// MARK: HMM1
			self.missiles.1.motion = Int(signed: data >> 4, bits: 4)
		case 0x24:
			// MARK: HMBL
			self.ball.motion = Int(signed: data >> 4, bits: 4)
		case 0x25:
			// MARK: VDELP0
			self.players.0.delayed = data[0]
		case 0x26:
			// MARK: VDELP1
			self.players.1.delayed = data[0]
		case 0x27:
			// MARK: VDELBL
			self.ball.delayed = data[0]
		case 0x2a:
			// MARK: HMOVE
			self.players.0.position -= self.players.0.motion
			self.players.1.position -= self.players.1.motion
			self.missiles.0.position -= self.missiles.0.motion
			self.missiles.1.position -= self.missiles.1.motion
			self.ball.position -= self.ball.motion
		case 0x2b:
			// MARK: HMCLR
			self.players.0.motion = 0
			self.players.1.motion = 0
			self.missiles.0.motion = 0
			self.missiles.1.motion = 0
			self.ball.motion = 0
		case 0x2c:
			// MARK: CXCLR
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

extension TIA.Player {
	static func random() -> Self {
		return TIA.Player(
			graphics: (.random(in: 0x00...0xff), .random(in: 0x00...0xff)),
			reflected: .random(),
			copies: .random(in: 1...3),
			color: .random(in: 0x00...0xff),
			position: .random(in: 5...160),
			motion: .random(in: -8...7),
			delayed: .random())
	}
}

public extension TIA.Missile {
	static func random() -> Self {
		return TIA.Missile(
			enabled: .random(),
			size: .random(in: 1...8),
			color: .random(in: 0x00...0xff),
			position: .random(in: 4...160),
			motion: .random(in: -8...7))
	}
}

public extension TIA.Ball {
	static func random() -> Self {
		return TIA.Ball(
			enabled: (.random(), .random()),
			size: .random(in: 1...8),
			position: .random(in: 0...160),
			motion: .random(in: -8...7),
			delayed: .random())
	}
}

public extension TIA.Playfield {
	static func random() -> Self {
		return TIA.Playfield(
			graphics: .random(in: 0x000000...0xffffff),
			control: .random(),
			color: .random(in: 0x00...0xff))
	}
}

public extension TIA.PlayfieldControl {
	static func random() -> Self {
		return TIA.PlayfieldControl(rawValue: .random(in: 0x00...0xff))
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
