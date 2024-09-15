//
//  OptionSet+Subscript.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 15.9.2024.
//

extension OptionSet {
	subscript (option: Self.Element) -> Bool {
		get {
			return self.contains(option)
		}
		set {
			if newValue {
				self.insert(option)
			} else {
				self.remove(option)
			}
		}
	}
}
