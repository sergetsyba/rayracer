//
//  Console+ControllerPorts.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 7.12.2024.
//

// MARK: -
// MARK: MOS6532 peripheral
extension Atari2600: MOS6532.Peripheral {
	@_implements(MOS6532.Peripheral, read())
	public func readFromRIOT() -> Int {
		let data0 = self.controllers.0.output
		let data1 = self.controllers.1.output
		
		return (data1 & 0x0f) | ((data0 << 4) & 0xf0)
	}
	
	public func write(_ data: Int, mask: Int) {
		// TODO:
	}
}

// MARK: -
// MARK: TIA peripheral
extension Atari2600: TIA.Peripheral {
	@_implements(TIA.Peripheral, read())
	public func readFromTIA() -> Int {
		let data0 = self.controllers.0.output
		let data1 = self.controllers.1.output
		
		return ((data0 >> 1) | 0xef) & (data1 | 0xdf)
	}
}
