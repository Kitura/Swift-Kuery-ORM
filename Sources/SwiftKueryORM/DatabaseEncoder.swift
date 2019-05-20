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
import KituraContracts
import SwiftKuery

/// Class used to construct a dictionary [String: Any] from a Model
open class DatabaseEncoder {
    private var databaseEncoder = _DatabaseEncoder()

    /// Encode a Encodable type to a dictionary [String: Any]
    open func encode<T: Encodable>(_ value: T, dateEncodingStrategy: DateEncodingFormat) throws -> [String: Any] {
        databaseEncoder.dateEncodingStrategy = dateEncodingStrategy
        try value.encode(to: databaseEncoder)
        return databaseEncoder.values
    }
}

fileprivate class _DatabaseEncoder: Encoder {
    public var codingPath = [CodingKey]()

    public var values: [String: Any] = [:]

    public var dateEncodingStrategy: DateEncodingFormat = .double

    public var userInfo: [CodingUserInfoKey: Any] = [:]
    public func container<Key>(keyedBy: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = _DatabaseKeyedEncodingContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        return _DatabaseEncodingContainer(encoder: self, codingPath: codingPath, count: 0)
    }

    public func singleValueContainer() -> SingleValueEncodingContainer {
        return _DatabaseEncodingContainer(encoder: self, codingPath: codingPath, count: 0)
    }
}

fileprivate struct _DatabaseKeyedEncodingContainer<K: CodingKey> : KeyedEncodingContainerProtocol {
    typealias Key = K
    var encoder: _DatabaseEncoder

    var codingPath = [CodingKey]()

    public mutating func encodeNil(forKey key: Key) throws {}

    public mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        if let dataValue = value as? Data {
            encoder.values[key.stringValue] = dataValue.base64EncodedString()
        } else if let urlValue = value as? URL {
            encoder.values[key.stringValue] = urlValue.absoluteString
        } else if let uuidValue = value as? UUID {
            encoder.values[key.stringValue] = uuidValue.uuidString
        } else if let dateValue = value as? Date {
            switch encoder.dateEncodingStrategy {
            case .double:
                encoder.values[key.stringValue] = dateValue.timeIntervalSinceReferenceDate
            case .datetime, .timestamp:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                encoder.values[key.stringValue] = dateFormatter.string(from: dateValue)
            case .date:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                encoder.values[key.stringValue] = dateFormatter.string(from: dateValue)
            case .time:
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "HH:mm:ss"
                encoder.values[key.stringValue] = dateFormatter.string(from: dateValue)
            }
        } else if value is [Any] {
            throw RequestError(.ormDatabaseEncodingError, reason: "Encoding an array is not currently supported")
        } else if value is [AnyHashable: Any] {
            throw RequestError(.ormDatabaseEncodingError, reason: "Encoding a dictionary is not currently supported")
        } else {
            encoder.values[key.stringValue] = value
        }
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        return encoder.container(keyedBy: keyType)
    }

    public mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        return encoder.unkeyedContainer()
    }

    public mutating func superEncoder() -> Encoder {
        return _DatabaseEncoder()
    }

    public mutating func superEncoder(forKey key: Key) -> Encoder {
        return _DatabaseEncoder()
    }
}

/// Default implenations of UnkeyedEncodingContainer and SingleValueEncodingContainer
/// Should never go into these containers. Types are checked in the TypeDecoder
fileprivate struct _DatabaseEncodingContainer: UnkeyedEncodingContainer, SingleValueEncodingContainer {

    var encoder: Encoder
    var codingPath = [CodingKey]()
    var count: Int = 0

    public mutating func encodeNil() throws {}

    public mutating func encode<T: Encodable>(_ value: T) {
        // TODO when encoding Arrays ( not supported for now )
    }

    public mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
        return encoder.container(keyedBy: keyType)
    }

    public mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        return encoder.unkeyedContainer()
    }

    public mutating func superEncoder() -> Encoder {
        return encoder
    }

}
