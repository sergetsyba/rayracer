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
	
	private(set) public var players: (Player, Player)
	private(set) public var missiles: (Missile, Missile)
	private(set) public var ball: Ball
	private(set) public var playfield: Playfield
	private(set) public var backgroundColor: Int
	
	private(set) public var collistions: [GraphicsObject: Set<GraphicsObject>] = [:]
	
	init(screen: Screen) {
		self.screen = screen
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
	
	public func reset() {
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
// MARK: Graphics objects
extension TIA {
	public struct Player {
		public var graphics: (Int, Int)
		public var reflected: Bool
		public var copies: Int
		public var color: Int = 0
		public var position: Int
		public var motion: Int
		public var delayed: Bool
		
		static func random() -> Player {
			return Player(
				graphics: (.random(in: 0x00...0xff), .random(in: 0x00...0xff)),
				reflected: .random(),
				copies: .random(in: 1...3),
				color: .random(in: 0x00...0xff),
				position: .random(in: 5...160),
				motion: .random(in: -8...7),
				delayed: .random())
		}
	}
	
	public struct Missile {
		public var enabled: Bool
		public var size: Int
		public var color: Int
		public var position: Int
		public var motion: Int
		
		static func random() -> Missile {
			return Missile(
				enabled: .random(),
				size: .random(in: 1...8),
				color: .random(in: 0x00...0xff),
				position: .random(in: 4...160),
				motion: .random(in: -8...7))
		}
	}
	
	public struct Ball {
		public var enabled: (Bool, Bool)
		public var size: Int
		public var position: Int
		public var motion: Int
		public var delayed: Bool
		
		static func random() -> Ball {
			return Ball(
				enabled: (.random(), .random()),
				size: .random(in: 1...8),
				position: .random(in: 0...160),
				motion: .random(in: -8...7),
				delayed: .random())
		}
	}
	
	public struct Playfield {
		public var graphics: Int
		public var control: PlayfieldControl
		public var color: Int
		
		static func random() -> Playfield {
			return Playfield(
				graphics: .random(in: 0x000000...0xffffff),
				control: .random(),
				color: .random(in: 0x00...0xff))
		}
	}
	
	public struct PlayfieldControl: OptionSet {
		public static let reflected = PlayfieldControl(rawValue: 1 << 0)
		public static let scoreMode = PlayfieldControl(rawValue: 1 << 1)
		public static let priority = PlayfieldControl(rawValue: 1 << 2)
		
		public var rawValue: Int
		
		static func random() -> PlayfieldControl {
			return PlayfieldControl(rawValue: .random(in: 0x00...0xff))
		}
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
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
}


// MARK: -
// MARK: Drawing
private extension TIA.Player {
	func draws(at point: Int) -> Bool {
		// ensure beam position is within possible player graphics
		// positions range
		let counter = point - self.self.position
		guard (0..<80).contains(counter) else {
			return false
		}
		
		// ensure player copy appears in the current 8-point section
		guard sectionLookUp[self.copies][counter / 8] else {
			return false
		}
		
		let graphics = self.delayed
		? self.graphics.1
		: self.graphics.0
		
		return self.reflected
		? graphics[counter % 8]
		: graphics[7 - counter % 8]
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

private extension TIA.Ball {
	func draws(at point: Int) -> Bool {
		let enabled = self.delayed
		? self.enabled.1
		: self.enabled.0
		
		guard enabled else {
			return false
		}
		
		let counter = point - self.position
		return (0..<self.size)
			.contains(counter)
	}
}

private extension TIA.Playfield {
	func draws(at point: Int) -> Bool {
		let bit = (point / 4) % 20
		if point < 80 {
			// left playfield side
			return self.graphics[bit]
		} else {
			// right playfield side
			return self.control.contains(.reflected)
			? self.graphics[19 - bit]
			: self.graphics[bit]
		}
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
			if self.playfield.control.contains(.scoreMode) {
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
			if data[0] {
				self.playfield.control.insert(.reflected)
			} else {
				self.playfield.control.remove(.reflected)
			}
			if data[1] {
				self.playfield.control.insert(.scoreMode)
			} else {
				self.playfield.control.remove(.scoreMode)
			}
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
