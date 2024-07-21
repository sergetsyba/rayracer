//
//  TIA.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 29.6.2023.
//

public class TIA {
	private var screen: Screen
	private var screenClock: Int
	
	private(set) internal var verticalSyncClock: Int
	private(set) public var verticalBlank: Bool
	private(set) public var waitingHorizontalSync: Bool
	
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
	
	func advanceClockToHorizontalSync() {
		if self.colorClock > 0 {
			let cycles = self.screen.width - self.colorClock
			self.advanceClock(cycles: cycles)
		}
		self.waitingHorizontalSync = false
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
}


// MARK: -
// MARK: Drawing
extension TIA {
	private var color: Int {
		guard self.verticalBlank == false else {
			return 0
		}
		
		let point = self.colorClock - 68
		guard point >= 0 else {
			return 0
		}
		
		if self.player0(at: point) || self.missile0(at: point) {
			return self.player0Color
		}
		if self.player1(at: point) || self.missile1(at: point) {
			return self.player1Color
		}
		if self.playfield(at: point) {
			if self.playfieldScoreMode {
				return point < 80
				? self.player0Color
				: self.player1Color
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
	
	private func player0(at point: Int) -> Bool {
		// ensure beam position is within possible player graphics
		// positions range
		let counter = point - self.player0Position
		guard (0..<80).contains(counter) else {
			return false
		}
		
		// ensure player copy appears in the current 8-point section
		guard sectionLookUp[self.player0Copies][counter / 8] else {
			return false
		}
		
		let graphics = self.player0Delay
		? self.player0Graphics.1
		: self.player0Graphics.0
		
		// ensure player graphics enabled
		guard graphics > 0 else {
			return false
		}
		
		return self.player0Reflected
		? graphics[counter % 8]
		: graphics[7 - counter % 8]
	}
	
	private func missile0(at point: Int) -> Bool {
		guard self.missile0Enabled else {
			return false
		}
		
		let counter = point - self.missile0Position
		let size = self.missile0Size
		
		return (0..<size)
			.contains(counter)
	}
	
	private func player1(at point: Int) -> Bool {
		// ensure beam position is within possible player graphics
		// positions range
		let counter = point - self.player1Position
		guard (0..<80).contains(counter) else {
			return false
		}
		
		// ensure player copy appears in the current 8-point section
		guard sectionLookUp[self.player1Copies][counter / 8] else {
			return false
		}
		
		let graphics = self.player1Delay
		? self.player1Graphics.1
		: self.player1Graphics.0
		
		// ensure player graphics enabled
		guard graphics > 0 else {
			return false
		}
		
		return self.player1Reflected
		? graphics[counter % 8]
		: graphics[7 - counter % 8]
	}
	
	private func missile1(at point: Int) -> Bool {
		guard self.missile1Enabled else {
			return false
		}
		
		let counter = point - self.missile1Position
		let size = self.missile1Size
		
		return (0..<size)
			.contains(counter)
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
					self.screenClock = 0
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
			self.player0Position = max(0, self.colorClock - 68) + 5
		case 0x11:
			// MARK: RESP1
			// resetting player position takes additional 4 color clock to
			// decode and 1 to latch
			self.player1Position = max(0, self.colorClock - 68) + 5
		case 0x12:
			// MARK: RESM0
			// resetting missile position takes additional 4 color clocks to
			// decode
			self.missile0Position = max(0, self.colorClock - 68) + 4
		case 0x13:
			// MARK: RESM1
			// resetting missile position takes additional 4 color clocks to
			// decode
			self.missile1Position = max(0, self.colorClock - 68) + 4
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
