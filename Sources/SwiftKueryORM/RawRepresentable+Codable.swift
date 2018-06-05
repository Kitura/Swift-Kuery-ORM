//
//  RawRepresentable+Codable.swift
//  SwiftKueryORM
//
//  Created by Jeremy Quinn on 05/06/2018.
//

import Foundation

extension KeyedEncodingContainer {
	public mutating func encodeIfPresent<T>(_ value: T?, forKey key: K) throws where T : Encodable & RawRepresentable, T.RawValue == Int {
		try encodeIfPresent(value?.rawValue, forKey: key)
	}
}

extension KeyedDecodingContainer {
	public func decodeIfPresent<T>(_ type: T.Type, forKey key: K) throws -> T? where T : Decodable & RawRepresentable, T.RawValue == Int {
		if let value = try decodeIfPresent(Int.self, forKey: key) {
			return T.init(rawValue: value)
		}
		return nil
	}
}
