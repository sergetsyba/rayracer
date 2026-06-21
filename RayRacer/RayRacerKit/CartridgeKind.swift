//
//  CartridgeKind.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2026.
//

import librayracer

typealias CartridgeKind = racer_cartridge_type
extension CartridgeKind: @retroactive OptionSet, SetAlgebra {
	static let atari2KB = CARTRIDGE_ATARI_2KB
	static let atari4KB = CARTRIDGE_ATARI_4KB
	static let atari8KB = CARTRIDGE_ATARI_8KB
	static let atari12KB = CARTRIDGE_ATARI_12KB
	static let atari16KB = CARTRIDGE_ATARI_16KB
	static let atari32KB = CARTRIDGE_ATARI_32KB

	init(size: Int) {
		switch size {
		case 0x1000/2: self = .atari2KB
		case 0x1000: self = .atari4KB
		case 0x1000*2: self = .atari8KB
		case 0x1000*3: self = .atari12KB
		case 0x1000*4: self = .atari16KB
		case 0x1000*8: self = .atari32KB
		default:
			fatalError("Unsupported cartridge type of size \(size).")
		}
	}
}
