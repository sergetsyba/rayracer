//
//  Addressable.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 20.7.2024.
//

public protocol Addressable {
	func read(at address: Int) -> Int
	mutating func write(_ value: Int, at address: Int)
}
