//
//  TIATests.swift
//  RayRacerKitTests
//
//  Created by Serge Tsyba on 23.11.2024.
//

import Testing
import RayRacerKit

@Suite("TIA")
struct TIATests {
	@Suite("Dumped input ports tests")
	struct DumpedInputPortsTests {
		private let tia = TIA()
		
		@Test("when enabled, reads peripheral output")
		func readsPeripheralWhenEnabled() {
			// enable input ports
			self.tia.vblank = 0x00
			
			self.tia.peripheral = 0b111011
			self.tia.advanceClock()
			
			#expect(self.tia.inpt0 == 0x80)
			#expect(self.tia.inpt1 == 0x80)
			#expect(self.tia.inpt2 == 0x00)
			#expect(self.tia.inpt3 == 0x80)
		}
		
		@Test("when disabled, grounded")
		func readsLowWhenDisabled() {
			// disable dumped input ports
			self.tia.vblank = 0x80
			
			self.tia.peripheral = 0b111011
			self.tia.advanceClock()
			
			#expect(self.tia.inpt0 == 0x00)
			#expect(self.tia.inpt1 == 0x00)
			#expect(self.tia.inpt2 == 0x00)
			#expect(self.tia.inpt3 == 0x00)
		}
	}
	
	@Suite("Latched input ports tests")
	struct LatchedInputPortsTests {
		private let tia = TIA()
		
		@Test("when enabled, reads peripheral output")
		func readsPeripheralWhenEnabled() {
			// enable input ports
			self.tia.vblank = 0x00
			
			self.tia.peripheral = 0b110011
			self.tia.advanceClock()
			
			#expect(self.tia.inpt4 == 0x80)
			#expect(self.tia.inpt5 == 0x80)
		}
		
		@Test("when disabled, latches peripheral output")
		func latchesPeripheralWhenDisabled() {
			// disable latched input ports
			self.tia.vblank = 0x40
			
			// peripheral reads high;
			// latched input should read high
			self.tia.peripheral = 0b110000
			self.tia.advanceClock()
			#expect(self.tia.inpt4 == 0x80)
			#expect(self.tia.inpt5 == 0x80)
			
			// peripheral reads low;
			// latched input should read low
			self.tia.peripheral = 0b000000
			self.tia.advanceClock()
			#expect(self.tia.inpt4 == 0x00)
			#expect(self.tia.inpt5 == 0x00)
			
			// peripheral reads high;
			// latched input should read low
			self.tia.peripheral = 0b110000
			self.tia.advanceClock()
			#expect(self.tia.inpt4 == 0x00)
			#expect(self.tia.inpt5 == 0x00)
		}
		
		@Test("when disabled, resets latched peripheral output")
		func resetsLatchedWhenDisabled() {
			// disable latched input ports
			self.tia.vblank = 0x40
			
			// peripheral reads low;
			// latched input should read low
			self.tia.peripheral = 0b000000
			self.tia.advanceClock()
			#expect(self.tia.inpt4 == 0x00)
			#expect(self.tia.inpt5 == 0x00)
			
			// disable latched input ports;
			// latched input should read high
			self.tia.vblank = 0x40
			#expect(self.tia.inpt4 == 0x80)
			#expect(self.tia.inpt5 == 0x80)
		}
	}
}

private extension TIA {
	var vblank: Int {
		get { fatalError() }
		set { self.write(newValue, at: 0x1) }
	}
	
	var inpt0: Int {
		return self.read(at: 0x38)
	}
	var inpt1: Int {
		return self.read(at: 0x39)
	}
	var inpt2: Int {
		return self.read(at: 0x3a)
	}
	var inpt3: Int {
		return self.read(at: 0x3b)
	}
	var inpt4: Int {
		return self.read(at: 0x3c)
	}
	var inpt5: Int {
		return self.read(at: 0x3d)
	}
}

extension Int: @retroactive TIA.Peripheral {
	public func read() -> Int {
		return self
	}
}
