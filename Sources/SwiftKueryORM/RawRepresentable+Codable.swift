/**
Copyright IBM Corporation 2018

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/


import Foundation

/// Support for encoding Codable & RawRepresentable enum for persistence in the ORM.
extension KeyedEncodingContainer {

	/// Database encode an enum which has the RawValue of String
	internal mutating func encodeIfPresent<T>(_ value: T?, forKey key: K) throws where T : Encodable & RawRepresentable, T.RawValue == String {
		try encodeIfPresent(value?.rawValue, forKey: key)
	}

	/// Database encode an enum which has the RawValue of Int
	internal mutating func encodeIfPresent<T>(_ value: T?, forKey key: K) throws where T : Encodable & RawRepresentable, T.RawValue == Int {
		try encodeIfPresent(value?.rawValue, forKey: key)
	}
}

/// Support for decoding Codable & RawRepresentable enum for persistence in the ORM.
extension KeyedDecodingContainer {

	/// Database decode an enum which has the RawValue of String
	internal func decodeIfPresent<T>(_ type: T.Type, forKey key: K) throws -> T? where T : Decodable & RawRepresentable, T.RawValue == String {
		if let value = try decodeIfPresent(String.self, forKey: key) {
			return T.init(rawValue: value)
		}
		return nil
	}

	/// Database decode an enum which has the RawValue of Int
	internal func decodeIfPresent<T>(_ type: T.Type, forKey key: K) throws -> T? where T : Decodable & RawRepresentable, T.RawValue == Int {
		if let value = try decodeIfPresent(Int.self, forKey: key) {
			return T.init(rawValue: value)
		}
		return nil
	}
}
