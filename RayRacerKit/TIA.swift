//
//  TIA.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 29.6.2023.
//

public class TIA {
	private var screen: Screen
	var screenClock: Int
	private var verticalSyncClock: Int
	
	private(set) public var verticalBlank: Bool
	internal(set) public var waitingHorizontalSync: Bool
	
	private(set) public var backgroundColor: Int
	private(set) public var playfield: Int
	private(set) public var playfieldControl: Int
	private(set) public var playfieldColor: Int
	
	private(set) public var numberSize0: Int
	private(set) public var numberSize1: Int
	
	private(set) public var players: (Player, Player) = (.random(), .random())
	private(set) public var missiles: (Missile, Missile) = (.random(), .random())
	
	private(set) public var ballEnabled: (Bool, Bool)
	private(set) public var ballPosition: Int
	private(set) public var ballMotion: Int
	private(set) public var ballDelay: Bool
	
	private(set) public var collistions: [GraphicsObject: Set<GraphicsObject>] = [:]
	
	init(screen: Screen) {
		self.screen = screen
		self.screenClock = 0
		self.verticalSyncClock = -1
		
		self.verticalBlank = true
		self.waitingHorizontalSync = false
		
		self.backgroundColor = .random(in: 0x00...0x7f)
		
		self.playfield = .random(in: 0x0...0xf0ffff)
		self.playfieldControl = .random(in: 0x00...0xff)
		self.playfieldColor = .random(in: 0x00...0x7f)
		
		self.numberSize0 = .random(in: 0x00...0xff)
		self.numberSize1 = .random(in: 0x00...0xff)
		
		self.ballEnabled = (.random(), .random())
		self.ballPosition = .random(in: 4...159)
		self.ballMotion = .random(in: -8...7)
		self.ballDelay = .random()
	}
	
	public func reset() {
		self.screenClock = 0
		self.verticalSyncClock = -1
	}
	
	func advanceClock(cycles: Int) {
		for _ in 0..<cycles {
			self.screen.write(color: self.color)
			self.screenClock += 1
		}
	}
	
	@discardableResult
	func advanceClockToHorizontalSync() -> Int {
		// do not advance to the next scan line when color clock is at 0
		guard self.colorClock > 0 else {
			self.waitingHorizontalSync = false
			return 0
		}
		
		let cycles = self.screen.width - self.colorClock
		self.advanceClock(cycles: cycles)
		self.waitingHorizontalSync = false
		
		return cycles
	}
}


// MARK: -
// MARK: Player
extension TIA {
	public struct Player {
		public var graphics: (Int, Int)
		public var reflected: Bool
		public var color: Int = 0
		public var position: Int
		public var motion: Int
		public var delayed: Bool
		
		init(graphics: (Int, Int), reflected: Bool, color: Int, position: Int, motion: Int, delayed: Bool) {
			self.graphics = graphics
			self.reflected = reflected
			self.color = color
			self.position = position
			self.motion = motion
			self.delayed = delayed
		}
		
		static func random() -> Player {
			return Player(
				graphics: (.random(in: 0x00...0xff), .random(in: 0x00...0xff)),
				reflected: .random(),
				color: .random(in: 0x00...0xff),
				position: .random(in: 5...160),
				motion: .random(in: -8...7),
				delayed: .random())
		}
	}
}

private extension TIA.Player {
	func draws(at point: Int, copies: Int) -> Bool {
		// ensure beam position is within possible player graphics
		// positions range
		let counter = point - self.self.position
		guard (0..<80).contains(counter) else {
			return false
		}
		
		// ensure player copy appears in the current 8-point section
		guard sectionLookUp[copies][counter / 8] else {
			return false
		}
		
		let graphics = self.delayed
		? self.graphics.0
		: self.graphics.1
		
		return self.reflected
		? graphics[counter % 8]
		: graphics[7 - counter % 8]
	}
}


// MARK: -
// MARK: Missile
extension TIA {
	public struct Missile {
		public var enabled: Bool
		public var size: Int
		public var position: Int
		public var motion: Int
		
		init(enabled: Bool, size: Int, position: Int, motion: Int) {
			self.enabled = enabled
			self.size = size
			self.position = position
			self.motion = motion
		}
		
		static func random() -> Missile {
			return Missile(
				enabled: .random(),
				size: .random(in: 1...8),
				position: .random(in: 4...160),
				motion: .random(in: -8...7))
		}
	}
}

private extension TIA.Missile {
	func draws(at point: Int) -> Bool {
		guard self.enabled else {
			return false
		}
		
		let counter = point - self.position
		return (0..<self.size)
			.contains(counter)
	}
}


// MARK: -
// MARK: Convenience registers
extension TIA {
	public var colorClock: Int {
		return self.screenClock % self.screen.width
	}
	
	public var verticalSync: (Bool, Int) {
		return (self.verticalSyncClock > -1, self.verticalSyncClock)
	}
	
	public var horizontalBlank: Bool {
		return self.colorClock < 68
	}
	
	public var playfieldReflected: Bool {
		return self.playfieldControl[0]
	}
	
	public var playfieldScoreMode: Bool {
		return self.playfieldControl[1]
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
	
	public var ballSize: Int {
		return 1 << ((self.playfieldControl >> 4) & 0x3)
	}
}


// MARK: -
// MARK: Drawing
extension TIA {
	private var color: Int {
		guard self.verticalBlank == false,
			  self.horizontalBlank == false else {
			return 0
		}
		
		let point = self.colorClock - 68
		let points = [
			self.players.0.draws(at: point, copies: self.player0Copies),
			self.players.1.draws(at: point, copies: self.player1Copies),
			self.missiles.0.draws(at: point),
			self.missiles.0.draws(at: point),
			self.ball(at: point),
			self.playfield(at: point)
		]
		
		for (index1, object) in GraphicsObject.allCases.enumerated() {
			var collisions = self.collistions[object] ?? []
			for index2 in points.indices {
				if points[index1] && points[index2] && index1 != index2 {
					collisions.insert(GraphicsObject.allCases[index2])
				}
			}
			
			self.collistions[object] = collisions
		}
		
		
		if self.players.0.draws(at: point, copies: self.player0Copies) || self.missiles.0.draws(at: point) {
			return self.players.0.color
		}
		if self.players.1.draws(at: point, copies: self.player1Copies) || self.missiles.1.draws(at: point) {
			return self.players.1.color
		}
		if self.ball(at: point) {
			return self.playfieldColor
		}
		if self.playfield(at: point) {
			if self.playfieldScoreMode {
				return point < 80
				? self.players.0.color
				: self.players.1.color
			} else {
				return self.playfieldColor
			}
		}
		return self.backgroundColor
	}
	
	private func playfield(at point: Int) -> Bool {
		let bit = (point / 4) % 20
		if point < 80 {
			// left playfield side
			return self.playfield[bit]
		} else {
			// right playfield side
			return self.playfieldReflected
			? self.playfield[19 - bit]
			: self.playfield[bit]
		}
	}
	
	private func ball(at point: Int) -> Bool {
		let enabled = self.ballDelay
		? self.ballEnabled.1
		: self.ballEnabled.0
		
		guard enabled else {
			return false
		}
		
		let counter = point - self.ballPosition
		return (0..<self.ballSize)
			.contains(counter)
	}
}

// MARK: -
// MARK: Bus integration
extension TIA: Addressable {
	public func read(at address: Int) -> Int {
		switch address % 0x10 {
		case 0x00:
			// MARK: CXM0P
			return self.collided(.missile0, with: .player0)
			|| self.collided(.missile0, with: .player1) ? 0xc0 : 0x30
		case 0x01:
			// MARK: CXM1P
			return self.collided(.missile1, with: .player0)
			|| self.collided(.missile1, with: .player1) ? 0xc0 : 0x31
		case 0x02:
			// MARK: CXP0FB
			return self.collided(.player0, with: .playfield)
			|| self.collided(.player0, with: .ball) ? 0xc0 : 0x32
		case 0x03:
			// MARK: CXP1FB
			return self.collided(.player1, with: .playfield)
			|| self.collided(.player1, with: .ball) ? 0xc0 : 0x33
		case 0x04:
			// MARK: CXM0FB
			return self.collided(.missile0, with: .playfield)
			|| self.collided(.player0, with: .ball) ? 0xc0 : 0x34
		case 0x05:
			// MARK: CXM1FB
			return self.collided(.missile1, with: .playfield)
			|| self.collided(.player0, with: .ball) ? 0xc0 : 0x35
		case 0x06:
			// MARK: CXBLPF
			return self.collided(.ball, with: .playfield) ? 0xc0 : 0x36
		case 0x07:
			// MARK: CXPPMM
			return self.collided(.player0, with: .player1)
			|| self.collided(.missile0, with: .missile1) ? 0xc0 : 0x37
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
				let scanLines = elapsedCycles / self.screen.width
				if scanLines >= 3 {
					// FIXME: Stella resets color clock to 9 after VSYNC
					self.screenClock = 9
					self.screen.sync()
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
			self.numberSize0 = data
		case 0x05:
			// MARK: NUSIZ1
			self.numberSize1 = data
		case 0x06:
			// MARK: COLUP0
			self.players.0.color = data
		case 0x07:
			// MARK: COLUP1
			self.players.1.color = data
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
			self.ballPosition = max(0, self.colorClock - 68) + 4
		case 0x1b:
			// MARK: GRP0
			self.players.0.graphics.0 = data
			self.players.1.graphics.1 = self.players.1.graphics.0
		case 0x1c:
			// MARK: GRP1
			self.players.1.graphics.0 = data
			self.players.0.graphics.1 = self.players.0.graphics.0
			self.ballEnabled.1 = self.ballEnabled.0
		case 0x1d:
			// MARK: ENAM0
			self.missiles.0.enabled = data[1]
		case 0x1e:
			// MARK: ENAM1
			self.missiles.1.enabled = data[1]
		case 0x1f:
			// MARK: ENABL
			self.ballEnabled.0 = data[1]
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
			self.ballMotion = Int(signed: data >> 4, bits: 4)
		case 0x25:
			// MARK: VDELP0
			self.players.0.delayed = data[0]
		case 0x26:
			// MARK: VDELP1
			self.players.1.delayed = data[0]
		case 0x27:
			// MARK: VDELBL
			self.ballDelay = data[0]
		case 0x2a:
			// MARK: HMOVE
			self.players.0.position -= self.players.0.motion
			self.players.1.position -= self.players.1.motion
			self.missiles.0.position -= self.missiles.0.motion
			self.missiles.1.position -= self.missiles.1.motion
			self.ballPosition -= self.ballMotion
		case 0x2b:
			// MARK: HMCLR
			self.players.0.motion = 0
			self.players.1.motion = 0
			self.missiles.0.motion = 0
			self.missiles.1.motion = 0
			self.ballMotion = 0
		case 0x2c:
			// MARK: CXCLR
			self.collistions = [:]
			
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

private let sectionLookUp = [
	0x001, // ●○○○○○○○○○
	0x005, // ●○●○○○○○○○
	0x011, // ●○○●○○○○○○
	0x015, // ●○●○●○○○○○
	0x101, // ●○○○○○○○●○
	0x001, // ●●○○○○○○○○
	0x111, // ●○○○●○○○●○
	0x001  // ●●●●○○○○○○
]

extension TIA {
	public enum GraphicsObject: CaseIterable {
		case player0
		case player1
		case missile0
		case missile1
		case ball
		case playfield
	}
	
	private func collided(_ object1: GraphicsObject, with object2: GraphicsObject) -> Bool {
		return self.collistions[object1]?
			.contains(object2) ?? false
	}
}
