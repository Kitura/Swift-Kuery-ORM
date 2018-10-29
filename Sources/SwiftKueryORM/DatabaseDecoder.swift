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

import SwiftKuery
import Foundation
import KituraContracts


/// Class used to construct a Model from a row in the database
open class DatabaseDecoder {
  fileprivate let decoder = _DatabaseDecoder()

  /// Decode from a dictionary [String: Any] to a Decodable type
  open func decode<T : Decodable>(_ type: T.Type, _ values: [String : Any?]) throws -> T {
    decoder.values = values
    return try T(from: decoder)
  }

  fileprivate class _DatabaseDecoder : Decoder {
    public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey:Any] = [:]
    public var values = [String:Any?]()

    fileprivate init(at codingPath: [CodingKey] = []){
      self.codingPath = codingPath
    }

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
      return KeyedDecodingContainer<Key>(_DatabaseKeyedDecodingContainer<Key>(decoder: self, codingPath: self.codingPath))
    }
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
      return _UnKeyedDecodingContainer(decoder: self)
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
      return _SingleValueDecodingContainer(decoder: self)
    }
  }

  fileprivate struct _DatabaseKeyedDecodingContainer<K : CodingKey> : KeyedDecodingContainerProtocol {
    typealias Key = K

    private let decoder: _DatabaseDecoder
    private let container: [String : Any] = [:]

    public var codingPath: [CodingKey]

    fileprivate init(decoder: _DatabaseDecoder, codingPath: [CodingKey]){
      self.decoder = decoder
      self.codingPath = codingPath
    }

    public var allKeys: [Key] {
      return []
    }

    public func contains(_ key: Key) -> Bool {
      return false
    }
    public func decodeNil(forKey key: Key) throws -> Bool {
      return true
    }

    /// Check that value exists in the data return from the database
    private func checkValueExitence(_ key: Key) throws -> Any? {
        let keyNameLower = key.stringValue.lowercased()
        
        for key in decoder.values {
            decoder.values[key.key.lowercased()] = decoder.values.removeValue(forKey: key.key)
        }
        
        guard let value = decoder.values[keyNameLower] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: [key],
                debugDescription: "No value for property with this key"
            ))
        }
        return value
    }

    /// Unwrap value from database
    private func unwrapValue(_ key: Key, _ value: Any?) throws -> Any? {
      guard let unwrappedValue = value as Any? else {
        throw DecodingError.valueNotFound(Any.self, DecodingError.Context(
          codingPath: [key],
          debugDescription: "Null value in table for non-optional property"
        ))
      }
      return unwrappedValue
    }

    /// Cast value from database to expect type in the model
    private func castedValue<T : Any>(_ value: Any?, _ type: T.Type, _ key: Key) throws -> T {
      guard let castedValue = value as? T else {
        throw DecodingError.typeMismatch(type, DecodingError.Context(
          codingPath: [key],
          debugDescription: "Could not cast " + String(describing: value)
        ))
      }
      return castedValue
    }

    /// Special case for integer, no integer type in database
    public func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      let returnValue: Int
      switch(unwrappedValue) {
      case let v as Int16: returnValue = Int(v)
      case let v as Int32: returnValue = Int(v)
      case let v as Int64: returnValue = Int(v)
      default:
        throw DecodingError.typeMismatch(type, DecodingError.Context(
          codingPath: [key],
          debugDescription: "Could not convert " + String(describing: unwrappedValue)
        ))
      }
      return returnValue
    }
    public func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: String.Type, forKey key: Key) throws -> String {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
      let unwrappedValue = try unwrapValue(key, checkValueExitence(key))
      return try castedValue(unwrappedValue, type, key)
    }
    public func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
      let value = try checkValueExitence(key)
      if type is Data.Type && value != nil {
        let castValue = try castedValue(value, String.self, key)
        guard let data = Data(base64Encoded: castValue) else {
          throw RequestError(.ormCodableDecodingError, reason: "Error decoding value of Data Type for Key: \(String(describing: key)) , value: \(String(describing: value)) is not base64encoded")
        }
        return try castedValue(data, type, key)
      } else if type is URL.Type && value != nil {
        let castValue = try castedValue(value, String.self, key)
        let url = URL(string: castValue)
        return try castedValue(url, type, key)
      } else if type is UUID.Type && value != nil {
        let castValue = try castedValue(value, String.self, key)
        let uuid = UUID(uuidString: castValue)
        return try castedValue(uuid, type, key)
      } else if type is Date.Type && value != nil {
        let castValue = try castedValue(value, Double.self, key)
        let date = Date(timeIntervalSinceReferenceDate: castValue)
        return try castedValue(date, type, key)
      } else {
        throw RequestError(.ormDatabaseDecodingError, reason: "Unsupported type: \(String(describing: type)) for value: \(String(describing: value))")
      }
    }

    public func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
      let value = try checkValueExitence(key)
      if value == nil { return nil}
      let returnValue: Int
      switch(value){
      case let v as Int16: returnValue = Int(v)
      case let v as Int32: returnValue = Int(v)
      case let v as Int64: returnValue = Int(v)
      default:
        throw DecodingError.typeMismatch(type, DecodingError.Context(
          codingPath: [key],
          debugDescription: "Could not convert " + String(describing: value)
        ))
      }
      return returnValue
    }
    public func decodeIfPresent(_ type: Int8.Type, forKey key: Key) throws -> Int8? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: Int16.Type, forKey key: Key) throws -> Int16? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: Int32.Type, forKey key: Key) throws -> Int32? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: Int64.Type, forKey key: Key) throws -> Int64? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: UInt.Type, forKey key: Key) throws -> UInt? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: UInt8.Type, forKey key: Key) throws -> UInt8? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: UInt16.Type, forKey key: Key) throws -> UInt16? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: UInt32.Type, forKey key: Key) throws -> UInt32? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: UInt64.Type, forKey key: Key) throws -> UInt64? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: Float.Type, forKey key: Key) throws -> Float? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }
    public func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      return try castedValue(value, type, key)
    }

    public func decodeIfPresent<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
      let value = try checkValueExitence(key)
      if value == nil {return nil}
      if type is Data.Type {
        let castValue = try castedValue(value, String.self, key)
        guard let data = Data(base64Encoded: castValue) else {
          throw RequestError(.ormCodableDecodingError, reason: "Error decoding value of Data Type for Key: \(String(describing: key)) , value: \(String(describing: value)) is not base64encoded")
        }

        return data as? T
      } else if type is URL.Type {
        let castValue = try castedValue(value, String.self, key)
        let url = URL(string: castValue)
        return try castedValue(url, type, key)
      } else if type is Date.Type {
        let castValue = try castedValue(value, Double.self, key)
        let date = Date(timeIntervalSinceReferenceDate: castValue)
        return try castedValue(date, type, key)
      } else {
        throw RequestError(.ormDatabaseDecodingError, reason: "Unsupported type: \(String(describing: type)) for value: \(String(describing: value))")
      }
    }

    public func nestedContainer<NestedKey>(keyedBy: NestedKey.Type, forKey: Key) throws -> KeyedDecodingContainer<NestedKey> {
      return KeyedDecodingContainer<NestedKey>(_DatabaseKeyedDecodingContainer<NestedKey>(decoder: decoder, codingPath: codingPath))
    }

    public func nestedUnkeyedContainer(forKey: Key) throws -> UnkeyedDecodingContainer {
      return _UnKeyedDecodingContainer(decoder: decoder)
    }

    public func superDecoder() throws -> Decoder {
      return decoder
    }

    public func superDecoder(forKey: Key) throws -> Decoder {
      return decoder
    }

  }

  fileprivate class _SingleValueDecodingContainer : SingleValueDecodingContainer {

    var codingPath: [CodingKey] {
      return []
    }

    var decoder: _DatabaseDecoder

    fileprivate init(decoder: _DatabaseDecoder){
      self.decoder = decoder
    }

    public func decodeNil() -> Bool {
      return true
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
      let child = _DatabaseDecoder()
      let result = try T(from: child)
      return result
    }
  }

  fileprivate class _UnKeyedDecodingContainer: UnkeyedDecodingContainer {

    var codingPath: [CodingKey] {
      return decoder.codingPath
    }

    public var count: Int? {
      return 1
    }

    var isAtEnd: Bool = true

    public var currentIndex: Int = 0

    private let decoder: _DatabaseDecoder

    fileprivate init(decoder: _DatabaseDecoder){
      self.decoder = decoder
    }

    public func decodeNil() -> Bool {
      return true
    }

    public func decode<T: Decodable>(_ type: T.Type) throws -> T {
      return try T(from: decoder)
    }

    public func nestedContainer<NestedKey>(keyedBy: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
      return KeyedDecodingContainer<NestedKey>(_DatabaseKeyedDecodingContainer<NestedKey>(decoder: decoder, codingPath: codingPath))
    }

    public func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
      return self
    }

    public func superDecoder() throws -> Decoder {
      return decoder
    }
  }
}
