//
//  UserDefaults+Preferences.swift
//  RayRacer
//
//  Created by Serge Tsyba on 25.6.2023.
//

import Foundation
import Atari2600Kit

struct Preferences {
	var games: [String: GamePreferences]
}

struct GamePreferences {
	var breakpoints: [Breakpoint]
}

extension UserDefaults {
	func preferences(forGameIdentifier identifier: String) -> [String: Any] {
		let preferences = self.dictionary(forKey: "Games")
		return preferences?[identifier] as? [String: Any] ?? [:]
	}
	
	func setPreferences(_ gamePreferences: [String: Any], forGameIdentifier identifier: String) {
		var preferences = self.dictionary(forKey: "Games") ?? [:]
		preferences[identifier] = gamePreferences
		
		self.setValue(preferences, forKey: "Games")
	}
	
	func breakpoints(forGameIdentifier identifier: String = Atari2600.current.gameIdentifier) -> [Breakpoint] {
		let preferences = self.preferences(forGameIdentifier: identifier)
		let breakpoints = preferences["Breakpoints"] as? [String]
		
		return breakpoints?
			.map() { $0.dropFirst() }
			.compactMap() { Int($0, radix: 16) }
		?? []
	}
	
	func setBreakpoints(_ breakpoints: [Breakpoint], forGameIdentifier identifier: String = Atari2600.current.gameIdentifier) {
		var preferences = self.preferences(forGameIdentifier: identifier)
		preferences["Breakpoints"] = breakpoints
			.map() { String(format: "$%04x", $0) }
		
		self.setPreferences(preferences, forGameIdentifier: identifier)
	}
}
