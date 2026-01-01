//
//  RayRacer+Preferences.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.9.2024.
//

import Foundation

extension UserDefaults {
	var consoleSwitches: Switches {
		get {
			// by default, TV type is set to `color` and both difficulties
			// to `advanced`
			return self.options(forKey: .consoleSwitches)
			?? [.color, .difficulty0, .difficulty1]
		}
		set { self.setOptions(newValue, forKey: .consoleSwitches) }
	}
	
	/// Number of milliseconds to simulate holding a trigger switch for (game select or game reset).
	/// Default is 500 milliseconds.
	var consoleSwitchHoldInterval: Int {
		get { self.object(forKey: .consoleSwitchHoldInterval) as? Int ?? 500 }
		set { self.setValue(newValue, forKey: .consoleSwitchHoldInterval) }
	}
	
	var openedFileURLs: [URL] {
		// show up to 10 recently opened files
		return self.openedFileBookmarks
			.prefix(10)
			.map({ $0.0 })
	}
	
	func addOpenedFileURL(_ url: URL, bookmark: Data) {
		// read bookmark data in user defaults, excluding bookmark data of
		// the new URL; read bookmark data of 9 recently opened files to
		// limit the result to 10, once the new data is added
		var openedFileBookmarks = self.openedFileBookmarks
			.filter({ $0.0 != url })
			.prefix(9)
			.map({ $0.1 })
		
		// prepend bookmark data of the new URL at the beginning and write
		// bookmark data to user defaults
		openedFileBookmarks.insert(bookmark, at: 0)
		self.setValue(openedFileBookmarks, forKey: .openedFileBookmarks)
	}
	
	func clearOpenedFileURLs() {
		self.removeObject(forKey: .openedFileBookmarks)
	}
	
	private var openedFileBookmarks: [(URL, Data)] {
		guard let data = self.value(forKey: .openedFileBookmarks) as? [Data] else {
			return []
		}
		
		// resolve file URLs from bookmark data and only keep unique ones
		var bookmarks: [(URL, Data)] = []
		for data in data {
			var stale = false
			
			// resolve file URLs from bookmark data and only keep unique ones
			if let url = try? URL(resolvingBookmarkData: data, options: .securityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
			   bookmarks.contains(where: { $0.0 == url }) == false {
				bookmarks.append((url, data))
			}
			
			if stale {
				// TODO: update opened file URL stale bookmark
			}
		}
		
		return bookmarks
	}
}

private extension String {
	static let consoleSwitches = "ConsoleSwitches"
	static let consoleSwitchHoldInterval = "ConsoleSwitchHoldInterval"
	static let openedFileBookmarks = "OpenedFileBookmarks"
}

private extension URL.BookmarkCreationOptions {
	static let readOnlySecurityScope: Self = [
		.withSecurityScope,
		.securityScopeAllowOnlyReadAccess
	]
}

private extension URL.BookmarkResolutionOptions {
	static let securityScope: Self = [
		.withSecurityScope,
		.withoutUI
	]
}

extension UserDefaults {
	func options<O: OptionSet>(forKey key: String) -> O? {
		guard let rawValue = self.object(forKey: key) as? O.RawValue else {
			return nil
		}
		return O(rawValue: rawValue)
	}
	
	func setOptions<O: OptionSet>(_ value: O?, forKey key: String) {
		if let rawValue = value?.rawValue {
			self.setValue(rawValue, forKey: key)
		} else {
			self.removeObject(forKey: key)
		}
	}
}
