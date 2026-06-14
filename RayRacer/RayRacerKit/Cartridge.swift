//
//  Cartridge.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2026.
//

import Foundation
import librayracer

struct Cartridge {
	var bookmark: Data
	var url: URL

	init(bookmark: Data, url: URL) {
		self.bookmark = bookmark
		self.url = url
	}

	var name: String {
		self.url.fileName
	}
}

// MARK: -
// MARK: File system integration
extension Cartridge {
	init(at url: URL) throws {
		let bookmark = try url.bookmarkData(options: .readOnlySecurityScope)
		self.init(bookmark: bookmark, url: url)
	}

	init(bookmark: Data) throws {
		var bookmark = bookmark
		var isStale = false

		let url = try URL(resolvingBookmarkData: bookmark, options: .securityScope, bookmarkDataIsStale: &isStale)
		if isStale {
			bookmark = try url.bookmarkData(options: .readOnlySecurityScope)
		}

		self.init(bookmark: bookmark, url: url)
	}

	func load() throws -> (program: Data, kind: CartridgeKind) {
		var isStale = false
		let url = try URL(resolvingBookmarkData: self.bookmark, bookmarkDataIsStale: &isStale)
		guard url.startAccessingSecurityScopedResource() else {
			throw CartridgeError.accessDenied
		}
		defer {
			url.stopAccessingSecurityScopedResource()
		}

		let program = try Data(contentsOf: url, options: [.mappedIfSafe])
		let kind = try CartridgeKind(size: program.count)
		return (program, kind)
	}
}

// MARK: -
enum CartridgeError: Error {
	case accessDenied
	case unsupportedKind
}

// MARK: -
// MARK: Convenience functionality
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

private extension URL {
	var fileName: String {
		self.deletingPathExtension()
			.lastPathComponent
	}
}

// MARK: -
// MARK: User defaults integration
extension UserDefaults {
	var recentCartridges: [Cartridge] {
		get { self.openedFileBookmarks.compactMap({ try? Cartridge(bookmark: $0) }) }
		set { self.openedFileBookmarks = newValue.map(\.bookmark) }
	}

	var openedFileBookmarks: [Data] {
		get { self.value(forKey: .openedFileBookmarks) as? [Data] ?? [] }
		set { self.setValue(newValue, forKey: .openedFileBookmarks) }
	}
}

private extension String {
	static let openedFileBookmarks = "OpenedFileBookmarks"
}
