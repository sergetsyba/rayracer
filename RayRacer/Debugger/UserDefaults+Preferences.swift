//
//  UserDefaults+Preferences.swift
//  RayRacer
//
//  Created by Serge Tsyba on 25.6.2023.
//

import Foundation
import RayRacerKit

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
}
