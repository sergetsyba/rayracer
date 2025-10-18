//
//  MOS6507+Status.swift
//  RayRacerKit
//
//  Created by Serge Tsyba on 7.9.2024.
//

extension MOS6507 {
	public struct Status: OptionSet, ExpressibleByIntegerLiteral {
		public static let carry = Status(rawValue: 1 << 0)
		public static let zero = Status(rawValue: 1 << 1)
		public static let interruptDisabled = Status(rawValue: 1 << 2)
		public static let decimalMode = Status(rawValue: 1 << 3)
		public static let `break` = Status(rawValue: 1 << 4)
		public static let overflow = Status(rawValue: 1 << 6)
		public static let negative = Status(rawValue: 1 << 7)
		
		public var rawValue: Int
		
		public init(rawValue: Int) {
			self.rawValue = rawValue
		}
		
		public init(integerLiteral value: Int) {
			self.rawValue = value
		}
	}
}
