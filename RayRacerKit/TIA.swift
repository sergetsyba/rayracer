//
//  TIA.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 29.6.2023.
//

public class TIA {
	public var output: GraphicsOutput?
	private(set) public var screenClock: Int
	private var verticalSyncClock: Int
	
	private(set) public var verticalBlank: Bool
	internal(set) public var waitingHorizontalSync: Bool
	
	private(set) public var players: (Player, Player)
	private(set) public var missiles: (Missile, Missile)
	private(set) public var ball: Ball
	private(set) public var playfield: Playfield
	private(set) public var backgroundColor: Int
	
	//	private(set) public var collistions: [GraphicsObject: Set<GraphicsObject>] = [:]
	
	init() {
		self.screenClock = 0
		self.verticalSyncClock = -1
		
		self.verticalBlank = true
		self.waitingHorizontalSync = false
		
		self.players = (.random(), .random())
		self.missiles = (.random(), .random())
		self.ball = .random()
		self.playfield = .random()
		self.backgroundColor = .random(in: 0x00...0x7f)
	}
	
	func advanceClock(cycles: Int = 1) {
		self.output?.write(color: self.color)
		self.screenClock += 1
		
		if self.screenClock % 228 == 0 {
			self.waitingHorizontalSync = false
		}
	}
	
	@discardableResult
	func advanceClockToHorizontalSync() -> Int {
		// do not advance to the next scan line when color clock is at 0
		guard self.colorClock > 0 else {
			self.waitingHorizontalSync = false
			return 0
		}
		
		let cycles = 228 - self.colorClock
		self.advanceClock(cycles: cycles)
		self.waitingHorizontalSync = false
		
		return cycles
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
}

// MARK: -
// MARK: Convenience registers
extension TIA {
	public var colorClock: Int {
		return self.screenClock % 228
	}
	
	public var verticalSync: (Bool, Int) {
		return (self.verticalSyncClock > -1, self.verticalSyncClock)
	}
	
	public var horizontalBlank: Bool {
		return self.colorClock < 68
	}
	
	public var overscan: Bool {
		return self.screenClock >= 232 * 228
	}
}

extension TIA {
	private var color: Int {
		guard self.verticalBlank == false,
			  self.horizontalBlank == false else {
			return 0
		}
		
		let point = self.colorClock - 68
		let points = [
			self.players.0.draws(at: point),
			self.players.1.draws(at: point),
			self.missiles.0.draws(at: point),
			self.missiles.0.draws(at: point),
			self.ball.draws(at: point),
			self.playfield.draws(at: point)
		]
		
		//		for (index1, object) in GraphicsObject.allCases.enumerated() {
		//			var collisions = self.collistions[object] ?? []
		//			for index2 in points.indices {
		//				if points[index1] && points[index2] && index1 != index2 {
		//					collisions.insert(GraphicsObject.allCases[index2])
		//				}
		//			}
		//
		//			self.collistions[object] = collisions
		//		}
		
		
		if self.players.0.draws(at: point)
			|| self.missiles.0.draws(at: point) {
			return self.players.0.color
		}
		if self.players.1.draws(at: point)
			|| self.missiles.1.draws(at: point) {
			return self.players.1.color
		}
		if self.ball.draws(at: point) {
			return self.playfield.color
		}
		if self.playfield.draws(at: point) {
			if self.playfield.control[.scoreMode] {
				return point < 80
				? self.players.0.color
				: self.players.1.color
			} else {
				return self.playfield.color
			}
		}
		return self.backgroundColor
	}
}

// MARK: -
// MARK: Bus integration
extension TIA: Addressable {
	public func read(at address: Int) -> Int {
		switch address % 0x10 {
		case 0x00:
			// MARK: CXM0P
			return 0x30
		case 0x01:
			// MARK: CXM1P
			return 0x31
		case 0x02:
			// MARK: CXP0FB
			return 0x32
		case 0x03:
			// MARK: CXP1FB
			return 0x33
		case 0x04:
			// MARK: CXM0FB
			return 0x34
		case 0x05:
			// MARK: CXM1FB
			return 0x35
		case 0x06:
			// MARK: CXBLPF
			return 0x36
		case 0x07:
			// MARK: CXPPMM
			return 0x37
			
			//		case 0x00:
			//			// MARK: CXM0P
			//			return self.collided(.missile0, with: .player0)
			//			|| self.collided(.missile0, with: .player1) ? 0xc0 : 0x30
			//		case 0x01:
			//			// MARK: CXM1P
			//			return self.collided(.missile1, with: .player0)
			//			|| self.collided(.missile1, with: .player1) ? 0xc0 : 0x31
			//		case 0x02:
			//			// MARK: CXP0FB
			//			return self.collided(.player0, with: .playfield)
			//			|| self.collided(.player0, with: .ball) ? 0xc0 : 0x32
			//		case 0x03:
			//			// MARK: CXP1FB
			//			return self.collided(.player1, with: .playfield)
			//			|| self.collided(.player1, with: .ball) ? 0xc0 : 0x33
			//		case 0x04:
			//			// MARK: CXM0FB
			//			return self.collided(.missile0, with: .playfield)
			//			|| self.collided(.player0, with: .ball) ? 0xc0 : 0x34
			//		case 0x05:
			//			// MARK: CXM1FB
			//			return self.collided(.missile1, with: .playfield)
			//			|| self.collided(.player0, with: .ball) ? 0xc0 : 0x35
			//		case 0x06:
			//			// MARK: CXBLPF
			//			return self.collided(.ball, with: .playfield) ? 0xc0 : 0x36
			//		case 0x07:
			//			// MARK: CXPPMM
			//			return self.collided(.player0, with: .player1)
			//			|| self.collided(.missile0, with: .missile1) ? 0xc0 : 0x37
		case 0x0c:
			// MARK: INPT4
			return 0x80
		default:
			return .random(in: 0x00..<0x100)
		}
	}
	
	public func write(_ data: Int, at address: Int) {
		switch address {
		case 0x00:
			// MARK: VSYNC
			if data[1] {
				// begin counting vertical sync time
				self.verticalSyncClock = 0
			} else {
				// ensure vertical sync is on
				guard self.verticalSyncClock > -1 else {
					return
				}
				
				// when vertical sync has been on for at least 3 scan lines,
				// send composite sync signal to the screen and reset frame
				// clock
				let elapsedCycles = self.screenClock - self.verticalSyncClock
				let scanLines = elapsedCycles / 228
				if scanLines >= 3 {
					self.screenClock = 0
					self.output?.sync()
				}
				
				// stop counting vertical sync time
				self.verticalSyncClock = -1
			}
		case 0x01:
			// MARK: VBLANK
			self.verticalBlank = data[1]
		case 0x02:
			// MARK: WSYNC
			self.waitingHorizontalSync = true
		case 0x03:
			// MARK: RSYNC
			self.advanceClockToHorizontalSync()
			self.screenClock -= 3
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
		case 0x07:
			// MARK: COLUP1
			self.players.1.color = data
			self.missiles.1.color = data
		case 0x08:
			// MARK: COLUPF
			self.playfield.color = data
		case 0x09:
			// MARK: COLUBK
			self.backgroundColor = data
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
			//		case 0x2c:
			// MARK: CXCLR
			//			self.collistions = [:]
			
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
