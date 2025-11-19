//
//  TIA+Ball.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 5.9.2024.
//

extension TIA {
	public struct Ball: MovableObject {
		public var size: Int
		public var options: Options
		
		public var position: Int = 0 {
			didSet {
				if self.position == 160 {
					self.position = 0
				}
			}
		}
		public var motion: Int = 0
		
		public init(size: Int = 1, options: Options = []) {
			self.size = size
			self.options = options
		}
	}
}

extension TIA.Ball {
	public struct Options: OptionSet {
		public static let enabled0 = Options(rawValue: 1 << 0)
		public static let enabled1 = Options(rawValue: 1 << 1)
		public static let delayed = Options(rawValue: 1 << 2)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
	}
}


// MARK: -
// MARK: Drawing
extension TIA.Ball {
	var needsDrawing: Bool {
		// ensure ball is enabled
		guard self.options == [.enabled0]
				|| self.options == [.delayed, .enabled1] else {
			return false
		}
		
		return self.position < self.size
	}
}
