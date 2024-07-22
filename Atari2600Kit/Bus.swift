//
//  Bus.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 20.7.2024.
//

public typealias Address = Int

public protocol Bus {
	func read(at address: Address) -> Int
	mutating func write(_ value: Int, at address: Address)
}
