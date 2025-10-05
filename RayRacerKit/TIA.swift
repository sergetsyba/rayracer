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
	
	/// Indicates whether vertical sync is enabled.
	/// TIA outputs vertical sync signal when enabled, which is done by writing VSYNC register.
	private(set) public var isVerticalSyncEnabled: Bool = false {
		didSet {
			if self.isVerticalSyncEnabled {
				self.output?
					.sync(.vertical)
			}
		}
	}
	
	/// Indicates whether wait on color sync is currently inabled.
	/// TIA is currently waiting on horizontal sync.
	private(set) public var awaitsHorizontalSync: Bool = false
	
	/// Indicates whether vertical blanking is enabled.
	/// TIA outputs blank video signal when enabled, which is done by writing to VBLANK register.
	private(set) public var isVerticalBlankEnabled: Bool = false
	
	/// Indicates whether horizontal blanking is enabled.
	/// TIA outputs blank video signal when enabled, which occurrs automatically for the first 76 or 68
	/// color clocks of each scan line, depending on whether HMOVE register was strobed or not.
	public var isHorizontalBlankEnabled: Bool {
		return self.colorClock < self.horizontalBlankResetColorClock
	}
	
	/// Color clock at which horizontal blank is turned off.
	///
	/// Horizontal blank is reset at
	/// - color clock 68 normally
	/// - color clock 76 when HMOVE register strobed
	private var horizontalBlankResetColorClock = 68
	
	/// Color clock within the current scan line.
	private(set) public var colorClock: Int = 0 {
		didSet { self.colorClock %= 228 }
	}
	
	/// Resets TIA.
	public func reset() {
		self.isVerticalSyncEnabled = false
		self.isVerticalBlankEnabled = false
		self.awaitsHorizontalSync = false
		
		self.horizontalBlankResetColorClock = 68
		self.colorClock = 0
	}
	
	/// Advances color clock by 1 unit.
	public func advanceClock() {
		if self.colorClock == 0 {
			self.awaitsHorizontalSync = false
			self.horizontalBlankResetColorClock = 68
			
			self.output?
				.sync(.horizontal)
		}
		
		if self.isHorizontalBlankEnabled {
			// position counters of movable objects do not receive clock
			// signals during horizontal blank
			self.output?.blank()
		} else {
			let options = self.drawOptions(at: self.colorClock - 68)
			
			if self.isVerticalBlankEnabled {
				self.output?
					.blank()
			} else {
				let object = Self.objectIndexes[options.rawValue]
				let color = self.colors[object]
				self.output?
					.write(color: color)
			}
			
			// advance movable object position counters
			self.players.0.position += 1
			self.players.1.position += 1
			self.missiles.0.position += 1
			self.missiles.1.position += 1
			self.ball.position += 1
		}
		
		self.colorClock += 1
	}
}

extension TIA {
	public enum GraphicsSync {
		case vertical
		case horizontal
	}
	
	public protocol GraphicsOutput {
		/// Signals the start of a new field or scan line.
		mutating func sync(_ sync: GraphicsSync)
		/// Signals the absence of color for the next value.
		mutating func blank()
		/// Signals the next color value.
		mutating func write(color: Int)
	}
	
	public protocol Peripheral {
		func read() -> Int
	}
	
	/// One of six objects TIA draws on screen.
	protocol MovableObject {
		/// Position counter of this object.
		/// This object will need to be drawn at specific values of its position counter.
		var position: Int { get set }
		/// Amount of horizontal motion, which adjusts this object's position.
		/// Value ranges in [0, 15] and will move this object left or right on the current scan line once
		/// HMOVE register is strobed.
		var motion: Int { get set }
		/// Returns `true` when this object should be drawn; returns `false` otherwise.
		var needsDrawing: Bool { get }
	}
}

extension TIA {
	private static let objectIndexes: [Int] = (0x00...0xff)
		.map() {
			var options = DrawOptions(rawValue: $0)
			
			if options.contains(.player0) ||
				options.contains(.missile0) {
				// player 0/missile 0
				return 0
			} else if options.contains(.player1) ||
						options.contains(.missile1) {
				// player 1/missile 1
				return 1
			} else if options.contains(.ball) {
				// ball
				return 2
			} else if options.contains(.playfield) {
				// playefield
				if options.contains(.scoreMode) {
					// score mode: player 0 or player 1
					return options.contains(.player0) ? 0 : 1
				} else {
					// playfield
					return 2
				}
			} else {
				// background
				return 3
			}
		}
	
	private func drawOptions(at point: Int) -> DrawOptions {
		var options: DrawOptions = []
		if self.players.0.needsDrawing {
			options.insert(.player0)
		}
		if self.players.1.needsDrawing {
			options.insert(.player1)
		}
		if self.missiles.0.needsDrawing {
			//			options.insert(.missile0)
		}
		if self.missiles.1.needsDrawing {
			//			options.insert(.missile1)
		}
		if self.ball.needsDrawing {
			options.insert(.ball)
		}
		if self.playfield.draws(at: point) {
			options.insert(.playfield)
		}
		if self.playfield.control.contains(.scoreMode) {
			options.insert(.scoreMode)
		}
		if point < 80 {
			options.insert(.leftHalf)
		}
		return options
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

extension TIA {
	func applyHorizontalMotion() {
		// NOTE: in hardware, horizontal motion advances position counters
		// of movable objects gradually every 4 color clocks, beginning
		// approximately 7 color clocks after HMOVE register is strobed;
		// so, at most it takes 15*4+7=67 color clocks to apply maximum
		// horizontal motion value of 15;
		// when HMOVE is strobed late during horizontal blank interval or
		// during visible portion of a scan line, horizontal motion
		// results are unpredictable and depend on clock timings and
		// hardware model;
		// the following is a simplified emulation of horizontal motion:
		// - when HMOVE register is strobed early during horizontal blanking
		//   interval, as intended, it applies motion at once to reduce
		//   unnecessary calculations, since there is no graphics output
		//   anyway;
		// - when HMOVE register is strobed late during horizontal blanking
		//   interval, it applies as much motion as would fit into
		//   horizontal blanking interval, as if it was applied gradually,
		//   and ignores the remaining amount of horizontal motion;
		// - when HMOVE register is strobed during visible portion of a
		//   scan line, it completely ignores horizontal motion, since the
		//   vast majority of games never do that anyway;
		
		let remainingClock = (68+8)-7 - self.colorClock
		guard remainingClock > 0 else {
			// ignore horizontal motion when HMOVE strobed late during
			// horizontal blanking interval or during visible portion of
			// a scan line
			return
		}
		
		// calculate maximum amount of horizontal motion, which could be
		// applied during horizontal blanking interval
		let ripples = remainingClock / 4
		self.players.0.move(limit: ripples)
		self.players.1.move(limit: ripples)
		self.missiles.0.move(limit: ripples)
		self.missiles.1.move(limit: ripples)
		self.ball.move(limit: ripples)
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
			self.isVerticalSyncEnabled = data[1]
		case 0x01:	// MARK: VBLANK
			self.isVerticalBlankEnabled = data[1]
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
			self.horizontalBlankResetColorClock = 68+8
			self.applyHorizontalMotion()
			
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

private extension TIA.MovableObject {
	/// Resets position counter of this object.
	mutating func reset() {
		self.position = 160-4
	}
	
	/// Applies horizontal motion.
	/// This advances position counter of this object by the value of horizontal motion, but limited by
	/// the specified motion limit.
	mutating func move(limit: Int) {
		self.position += min(self.motion, limit)
	}
}


private struct DrawOptions: OptionSet {
	static let player0   = DrawOptions(rawValue: 1 << 0)
	static let player1   = DrawOptions(rawValue: 1 << 1)
	static let missile0  = DrawOptions(rawValue: 1 << 2)
	static let missile1  = DrawOptions(rawValue: 1 << 3)
	static let ball	     = DrawOptions(rawValue: 1 << 4)
	static let playfield = DrawOptions(rawValue: 1 << 5)
	static let scoreMode = DrawOptions(rawValue: 1 << 6)
	static let leftHalf  = DrawOptions(rawValue: 1 << 7)
	
	var rawValue: Int
	
	init(rawValue: Int) {
		self.rawValue = rawValue
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
