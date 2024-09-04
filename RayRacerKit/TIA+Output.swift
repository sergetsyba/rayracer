//
//  TIA+Output.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 20.7.2024.
//

extension TIA {
	/// TIA outputs color signals in a raster scan for at most 262 scanlines, with 160 signals in each.
	/// The number of scanlines with actual graphics in them is controlled by a program via
	/// the VBLANK register.
	public protocol Output {
		/// Signals the start of a new field.
		mutating func sync()
		/// Signals the next color value.
		mutating func write(color: Int)
	}
}
