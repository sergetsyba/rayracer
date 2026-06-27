//
//  Cartridge.swift
//  RayRacer
//
//  Created by Serge Tsyba on 14.6.2026.
//

import Foundation
import CryptoKit
import librayracer

struct Cartridge: Equatable {
	var name: String
	var id: String
	var kind: CartridgeKind
	
	var bookmark: Data
	var program: Data?
}

extension Cartridge {
	static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.id == rhs.id
	}
}

// MARK: -
// MARK: File integration
extension Cartridge {
	init(at url: URL) throws {
		let bookmark = try url.bookmarkData(options: .readOnlySecurityScope)
		self = try url.withSecurityScopedData {
			Cartridge(
				name: url.fileName,
				id: $0.md5,
				kind: CartridgeKind(size: $0.count),
				bookmark: bookmark,
				program: $0)
		}
	}
	
	mutating func load() throws {
		var isStale = false
		let url = try URL(resolvingBookmarkData: self.bookmark, options: .securityScope, bookmarkDataIsStale: &isStale)
		
		// update name and bookmark when file was moved or renamed
		if isStale {
			self.name = url.fileName
			self.bookmark = try url.bookmarkData(options: .readOnlySecurityScope)
		}
		
		// load program data
		try url.withSecurityScopedData {
			self.program = $0
		}
	}
}

// MARK: -
// MARK: User defaults integration
extension UserDefaults {
	var cartridges: [Cartridge] {
		get {
			let decoder = PropertyListDecoder()
			guard let data = self.data(forKey: .cartridges),
				  let cartridges = try? decoder.decode([Cartridge].self, from: data) else {
				return []
			}
			return cartridges
		}
		set {
			let encoder = PropertyListEncoder()
			if let data = try? encoder.encode(newValue) {
				self.set(data, forKey: .cartridges)
			}
		}
	}
}

extension Cartridge: Codable {
	enum CodingKeys: CodingKey {
		case name
		case id
		case kind
		case bookmark
	}
}

extension CartridgeKind: @retroactive Codable {
}

private extension String {
	static let cartridges = "Cartridges"
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
	
	func withSecurityScopedData<Result>(_ perform: (Data) throws -> Result) throws -> Result {
		guard self.startAccessingSecurityScopedResource() else {
			fatalError("Failed to access security scoped file at \(self.absoluteString).")
		}
		defer {
			self.stopAccessingSecurityScopedResource()
		}
		
		let data = try Data(contentsOf: self, options: [.mappedIfSafe])
		return try perform(data)
	}
}

private extension Data {
	var md5: String {
		Insecure.MD5
			.hash(data: self)
			.map({ String(format: "%02x", $0) })
			.joined()
	}
}
