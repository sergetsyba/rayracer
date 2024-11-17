//
//  MOS6532Tests.swift
//  RayRacerKitTests
//
//  Created by Serge Tsyba on 16.11.2024.
//

import Testing
import RayRacerKit

@Suite("MOS6532")
struct MOS6532Tests {
	@Suite("I/O tests")
	struct IOTests {
		private let riot = MOS6532()
		
		@Test("Reads port data A", arguments: [0x00, 0x08, 0x10, 0x18])
		func readsPortDataA(address: Int) {
			self.riot.peripherals.a = TestPeripheral(data: 0b11001011)
			self.riot.data.a = 0b01110110
			self.riot.dataDirection.a = 0b11001100
			
			let data = self.riot.read(at: address)
			#expect(data == 0b01000111)
		}
		
		@Test("Writes port data A", arguments: [0x00, 0x08, 0x10, 0x18])
		func writesPortDataA(address: Int) {
			let peripheral = TestPeripheral(data: 0b11010101)
			self.riot.peripherals.a = peripheral
			self.riot.data.a = 0b11101011
			self.riot.dataDirection.a = 0b01100111
			
			self.riot.write(0b00110010, at: address)
			#expect(self.riot.data.a == 0b00110010)
			#expect(peripheral.data == 0b00100010)
		}
		
		@Test("Reads port data direction A", arguments: [0x01, 0x09, 0x11, 0x19])
		func readsDataDirectionA(address: Int) {
			let data = self.riot.read(at: address)
			#expect(data == self.riot.dataDirection.a)
		}
		
		@Test("Writes port data direction A", arguments: [0x01, 0x09, 0x11, 0x19])
		func writesDataDirectionA(address: Int) {
			let peripheral = TestPeripheral(data: 0b00011000)
			self.riot.peripherals.a = peripheral
			self.riot.data.a = 0b01111011
			self.riot.dataDirection.a = 0b00111110
			
			self.riot.write(0b00011101, at: address)
			#expect(self.riot.dataDirection.a == 0b00011101)
			#expect(peripheral.data == 0b00011001)
		}
		
		@Test("Reads port data B", arguments: [0x02, 0x0a, 0x12, 0x1a])
		func readPortDataB(address: Int) {
			self.riot.peripherals.b = TestPeripheral(data: 0b11101100)
			self.riot.data.b = 0b00111100
			self.riot.dataDirection.b = 0b00011000
			
			let data = self.riot.read(at: address)
			#expect(data == 0b11111100)
		}
		
		@Test("Writes port data B", arguments: [0x02, 0x0a, 0x12, 0x1a])
		func writesPortDataB(address: Int) {
			let peripheral = TestPeripheral(data: 0b00111101)
			self.riot.peripherals.b = peripheral
			self.riot.data.b = 0b11101100
			self.riot.dataDirection.b = 0b01110001
			
			self.riot.write(0b00101100, at: address)
			#expect(self.riot.data.b == 0b00101100)
			#expect(peripheral.data == 0b00100000)
		}
		
		@Test("Reads port data direction B", arguments: [0x03, 0x0b, 0x13, 0x1b])
		func readsDataDirectionB(address: Int) {
			let data = self.riot.read(at: address)
			#expect(data == self.riot.dataDirection.b)
		}
		
		@Test("Writes port data direction B", arguments: [0x03, 0x0b, 0x13, 0x1b])
		func writesDataDirectionB(address: Int) {
			let peripheral = TestPeripheral(data: 0b00001001)
			self.riot.peripherals.b = peripheral
			self.riot.data.b = 0b00001111
			self.riot.dataDirection.b = 0b00110000
			
			self.riot.write(0b11100000, at: address)
			#expect(self.riot.dataDirection.b == 0b11100000)
			#expect(peripheral.data == 0b00000000)
		}
	}
}

// MARK: -
private class TestPeripheral: MOS6532.Peripheral {
	var data: Int
	
	init(data: Int = 0x0) {
		self.data = data
	}
	
	func read() -> Int {
		return data
	}
	
	func write(_ data: Int) {
		self.data = data
	}
}
