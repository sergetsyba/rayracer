//
//  Screen.swift
//  Atari2600Kit
//
//  Created by Serge Tsyba on 20.7.2024.
//

public protocol Screen {
	var height: Int { get }
	var width: Int { get }
	
	mutating func sync()
	mutating func write(color: Int)
}
