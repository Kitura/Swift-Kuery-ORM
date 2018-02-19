import Foundation

struct InternalError: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}

// Protocol and extension for detecting type erased dictionaries
// and extracting their Key and Vaue types
protocol DictionaryType {
    static func getKeyType() -> Any.Type
    static func getValueType() -> Any.Type
}
extension Dictionary: DictionaryType {
    static func getKeyType() -> Any.Type { return Key.self }
    static func getValueType() -> Any.Type { return Value.self }
}

// Protocols that allow a type to provide valid dummy values to
// the TypeDecoder so that validation will pass
protocol DummyKeyedCodingValueProvider {
    static func dummyCodingValue(forKey: CodingKey) -> Any?
}
protocol DummyCodingValueProvider {
    static func dummyCodingValue() -> Any?
}

// Extensions of Foundation classes that have validations to provide
// valid dummy values
extension URL: DummyKeyedCodingValueProvider {
    static func dummyCodingValue(forKey key: CodingKey) -> Any? {
        switch key.intValue {
        case 1?: return "http://example.com/"
        default: return nil
        }
    }
}
extension TimeZone: DummyKeyedCodingValueProvider {
    static func dummyCodingValue(forKey key: CodingKey) -> Any? {
        switch key.intValue {
        case 0?: return TimeZone.current.identifier
        default: return nil
        }
    }
}
extension UUID: DummyCodingValueProvider {
    static func dummyCodingValue() -> Any? {
        return UUID().uuidString
    }
}

// Main enum used to describe a decoded type
// TODO: the associated data could do with labels
indirect enum TypeInfo {
    case single(Any.Type, Any.Type)
    case keyed(Any.Type, [String: TypeInfo])
    case dynamicKeyed(Any.Type, key: TypeInfo, value: TypeInfo)
    case unkeyed(Any.Type, TypeInfo)
    case optional(TypeInfo)
    case cyclic(Any.Type)
    case opaque(Any.Type)
}

extension TypeInfo: CustomStringConvertible {
    public var description: String { return describeTypeInfo(self) }

    // Function to pretty print a TypeInfo
    // TODO: Maybe add a few more bits of info to the output
    func describeTypeInfo(_ t: TypeInfo?, desc: String = "", indent: Int = 0) -> String {
        guard let t = t else { return "No type info" }
        let ind = String(repeating: " ", count: indent)
        let nextInd = String(repeating: " ", count: indent+2)
        switch t {
        case .keyed(let original, let properties):
            return desc + "\(original){\n\(properties.map({ (k,v) in nextInd + "\(k): \(describeTypeInfo(v, indent: indent + 2))"}).joined(separator: ",\n"))\n\(ind)}"
        case .dynamicKeyed(_ /*let original*/, let keyTypeInfo, let valueTypeInfo):
            return desc + "[\(describeTypeInfo(keyTypeInfo)):\(describeTypeInfo(valueTypeInfo, indent: indent + 2))]"
        case .unkeyed(_ /*let original*/, let elementTypeInfo):
            return desc + "[\(describeTypeInfo(elementTypeInfo, indent: indent))]"
        case .cyclic(let type):
            return desc + "\(type){<cyclic>}"
        case .single(_ /*let original*/, let type):
            return desc + "\(type)"
        case .optional(let wrappedTypeInfo):
            return desc + "\(describeTypeInfo(wrappedTypeInfo, indent: indent))?"
        case .opaque(let type):
            return desc + "<opaque: \(type)>"
        }
    }
}

class InternalTypeDecoder: Decoder {
    let decodingType: Any.Type
    fileprivate var typePath: [Any.Type]
    fileprivate var typeInfo: TypeInfo

    init(_ type: Any.Type, typePath: [Any.Type]) throws {
        decodingType = type
        typeInfo = .opaque(decodingType)

        var newTypePath = typePath
        newTypePath.append(type)

        guard !typePath.contains(where: { $0 == type }) else {
            self.typePath = newTypePath
            typeInfo = .cyclic(type)
            return
        }
        self.typePath = newTypePath

        if let dictionaryType = decodingType as? DictionaryType.Type,
            let keyType = dictionaryType.getKeyType() as? Decodable.Type,
            let valueType = dictionaryType.getValueType() as? Decodable.Type {

            typeInfo = .dynamicKeyed(decodingType,
                                     key: try TypeDecoder.decodeInternal(keyType, typePath: typePath),
                                     value: try TypeDecoder.decodeInternal(valueType, typePath: typePath))

        }
    }

    public var codingPath: [CodingKey] { return [] }
    public var userInfo: [CodingUserInfoKey : Any] = [:]

    var cyclic: Bool { if case .cyclic = typeInfo { return true } else { return false } }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        if case .opaque = typeInfo {
            return KeyedDecodingContainer(TypeKeyedDecodingContainer<Key>(self))
        } else {
            return KeyedDecodingContainer(DummyKeyedDecodingContainer<Key>(DummyDecoder(decodingType)))
        }
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        if case .opaque = typeInfo {
            return TypeUnkeyedDecodingContainer(self)
        } else {
            return DummyUnkeyedDecodingContainer(DummyDecoder(decodingType))
        }
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        if case .opaque = typeInfo {
            return TypeSingleValueDecodingContainer(self)
        } else {
            return DummySingleValueDecodingContainer(DummyDecoder(decodingType))
        }
    }
}

class TypeKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    var decoder: InternalTypeDecoder
    var optionalKeys = Set<String>()

    init(_ decoder: InternalTypeDecoder) {
        self.decoder = decoder
    }

    var codingPath: [CodingKey] { return [] }
    var allKeys: [Key] { return [] }

    func contains(_ key: Key) -> Bool { return true }

    private func keyDesc(_ key: Key) -> String {
        return "[\(key.stringValue):\(key.intValue ?? 0)]"
    }

    private func updateKeyedTypeInfo(with propertyTypeInfo: TypeInfo, forKey key: Key) throws {
        let info = optionalKeys.contains(keyDesc(key)) ? .optional(propertyTypeInfo) : propertyTypeInfo
        switch decoder.typeInfo {
        case .opaque:
            // Initialize
            decoder.typeInfo = .keyed(decoder.decodingType, [key.stringValue: info])
        case .keyed(let decodingType, var allPropertyTypeInfos) where decodingType == decoder.decodingType:
            // Add new property
            allPropertyTypeInfos[key.stringValue] = info
            decoder.typeInfo = .keyed(decoder.decodingType, allPropertyTypeInfos)
        default:
            // Something changed in an unexpected way
            assert(false)
            throw InternalError("Key type mismatch, expected .keyed(\(decoder.decodingType), ...), got \(String(describing: decoder.typeInfo))")
        }
    }

    func dummy<T>(forKey key: Key) -> T? {
        return (decoder.decodingType as? DummyKeyedCodingValueProvider.Type)?.dummyCodingValue(forKey: key) as? T
    }

    func decodeNil(forKey key: Key) throws -> Bool                     { optionalKeys.insert(keyDesc(key)); return decoder.cyclic }
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool     { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? false }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int       { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8     { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16   { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32   { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64   { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt     { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8   { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float   { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? 0 }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { try updateKeyedTypeInfo(with: .single(type, type), forKey: key); return dummy(forKey: key) ?? "" }
    func decode<T : Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let propertyInternalDecoder = try InternalTypeDecoder(type, typePath: decoder.typePath)
        let propertyValue = try T(from: propertyInternalDecoder)
        let propertyTypeInfo = propertyInternalDecoder.typeInfo
        try updateKeyedTypeInfo(with: propertyTypeInfo, forKey: key)
        return propertyValue
    }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        // FIXME
        return KeyedDecodingContainer(TypeKeyedDecodingContainer<NestedKey>(decoder))
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        // FIXME
        return TypeUnkeyedDecodingContainer(decoder)
    }
    func superDecoder() throws -> Decoder {
        return try InternalTypeDecoder(decoder.decodingType, typePath: decoder.typePath) // FIXME
    }
    func superDecoder(forKey key: Key) throws -> Decoder {
        return try InternalTypeDecoder(decoder.decodingType, typePath: decoder.typePath) // FIXME
    }
}

class TypeSingleValueDecodingContainer: SingleValueDecodingContainer {
    var decoder: InternalTypeDecoder
    var isOptional = false

    init(_ decoder: InternalTypeDecoder) {
        self.decoder = decoder
    }

    var codingPath: [CodingKey] { return [] }

    private func setTypeInfo(to typeInfo: TypeInfo) {
        decoder.typeInfo = isOptional ? .optional(typeInfo) : typeInfo
    }

    func dummy<T>() -> T? {
        return (decoder.decodingType as? DummyCodingValueProvider.Type)?.dummyCodingValue() as? T
    }

    func decodeNil() -> Bool                          { isOptional = true; return decoder.cyclic }
    func decode(_ type: Bool.Type) throws -> Bool     { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? false }
    func decode(_ type: Int.Type) throws -> Int       { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: Int8.Type) throws -> Int8     { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: Int16.Type) throws -> Int16   { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: Int32.Type) throws -> Int32   { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: Int64.Type) throws -> Int64   { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: UInt.Type) throws -> UInt     { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8   { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: Float.Type) throws -> Float   { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: Double.Type) throws -> Double { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? 0 }
    func decode(_ type: String.Type) throws -> String { setTypeInfo(to: .single(decoder.decodingType, type)); return dummy() ?? "" }
    func decode<T : Decodable>(_ type: T.Type) throws -> T {
        let internalDecoder = try InternalTypeDecoder(type, typePath: decoder.typePath)
        let value = try T(from: internalDecoder)
        let typeInfo = internalDecoder.typeInfo
        setTypeInfo(to: typeInfo)
        return value
    }
}

struct TypeUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    var decoder: InternalTypeDecoder
    var isOptional = false

    init(_ decoder: InternalTypeDecoder) {
        self.decoder = decoder
        self.isAtEnd = decoder.cyclic
    }

    var codingPath: [CodingKey] { return [] }
    var count: Int? { return 1 }
    var isAtEnd: Bool
    var currentIndex = 0

    private func setTypeInfo(to typeInfo: TypeInfo) {
        decoder.typeInfo = .unkeyed(decoder.decodingType, isOptional ? .optional(typeInfo) : typeInfo)
    }

    mutating func decodeNil() throws -> Bool                   { isOptional = true; return decoder.cyclic }
    mutating func decode(_ type: Bool.Type) throws -> Bool     { isAtEnd = true; setTypeInfo(to: .single(type, type)); return false }
    mutating func decode(_ type: Int.Type) throws -> Int       { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: Int8.Type) throws -> Int8     { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: Int16.Type) throws -> Int16   { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: Int32.Type) throws -> Int32   { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: Int64.Type) throws -> Int64   { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: UInt.Type) throws -> UInt     { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8   { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: Float.Type) throws -> Float   { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: Double.Type) throws -> Double { isAtEnd = true; setTypeInfo(to: .single(type, type)); return 0 }
    mutating func decode(_ type: String.Type) throws -> String { isAtEnd = true; setTypeInfo(to: .single(type, type)); return "" }
    mutating func decode<T : Decodable>(_ type: T.Type) throws -> T {
        isAtEnd = true
        let internalDecoder = try InternalTypeDecoder(type, typePath: decoder.typePath)
        let value = try T(from: internalDecoder)
        let typeInfo = internalDecoder.typeInfo
        setTypeInfo(to: typeInfo)
        return value
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        // FIXME: Not implemented (dummy code just to keep the compiler happy)
        return KeyedDecodingContainer(TypeKeyedDecodingContainer<NestedKey>(decoder))
    }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        // FIXME: Not implemented (dummy code just to keep the compiler happy)
        return TypeUnkeyedDecodingContainer(decoder)
    }
    mutating func superDecoder() throws -> Decoder {
        // FIXME: Not implemented (dummy code just to keep the compiler happy)
        isAtEnd = true
        return try InternalTypeDecoder(decoder.decodingType, typePath: decoder.typePath)
    }
}

// This decoder is for when we don't care about type information and just need to
// create a value of the decode type (used when we have already decoded the type
// without recursing, eg for Dictionary and when a cycle is detected)
struct DummyDecoder: Decoder {
    let decodingType: Any.Type
    public let codingPath: [CodingKey] = []
    public var userInfo: [CodingUserInfoKey : Any] = [:]

    init(_ type: Any.Type) { decodingType = type }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        return KeyedDecodingContainer(DummyKeyedDecodingContainer<Key>(self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return DummyUnkeyedDecodingContainer(self)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return DummySingleValueDecodingContainer(self)
    }

}
struct DummyKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: DummyDecoder
    let codingPath: [CodingKey] = []
    let allKeys: [Key] = []

    init(_ decoder: DummyDecoder) { self.decoder = decoder }

    func contains(_ key: Key) -> Bool { return false }

    func dummy<T>(forKey key: Key) -> T? {
        return (decoder.decodingType as? DummyKeyedCodingValueProvider.Type)?.dummyCodingValue(forKey: key) as? T
    }

    func decodeNil(forKey: Key) throws -> Bool { return true }
    func decode(_ type: Bool.Type, forKey: Key) throws -> Bool     { return dummy(forKey: forKey) ?? false }
    func decode(_ type: Int.Type, forKey: Key) throws -> Int       { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: Int8.Type, forKey: Key) throws -> Int8     { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: Int16.Type, forKey: Key) throws -> Int16   { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: Int32.Type, forKey: Key) throws -> Int32   { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: Int64.Type, forKey: Key) throws -> Int64   { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: UInt.Type, forKey: Key) throws -> UInt     { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: UInt8.Type, forKey: Key) throws -> UInt8   { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: UInt16.Type, forKey: Key) throws -> UInt16 { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: UInt32.Type, forKey: Key) throws -> UInt32 { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: UInt64.Type, forKey: Key) throws -> UInt64 { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: Float.Type, forKey: Key) throws -> Float   { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: Double.Type, forKey: Key) throws -> Double { return dummy(forKey: forKey) ?? 0 }
    func decode(_ type: String.Type, forKey: Key) throws -> String { return dummy(forKey: forKey) ?? "" }
    func decode<T: Decodable>(_ type: T.Type, forKey: Key) throws -> T { return try T(from: DummyDecoder(type)) }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        return KeyedDecodingContainer(DummyKeyedDecodingContainer<NestedKey>(decoder))
    }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        return DummyUnkeyedDecodingContainer(decoder)
    }
    func superDecoder() throws -> Decoder { return DummyDecoder(decoder.decodingType) }
    func superDecoder(forKey key: Key) throws -> Decoder { return DummyDecoder(decoder.decodingType) }
}
struct DummyUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let decoder: DummyDecoder
    let codingPath: [CodingKey] = []
    let count: Int? = 0
    let isAtEnd = true
    let currentIndex = 0

    init(_ decoder: DummyDecoder) { self.decoder = decoder }

    func decodeNil() throws -> Bool { return true }
    func decode(_ type: Bool.Type) throws -> Bool     { return false }
    func decode(_ type: Int.Type) throws -> Int       { return 0 }
    func decode(_ type: Int8.Type) throws -> Int8     { return 0 }
    func decode(_ type: Int16.Type) throws -> Int16   { return 0 }
    func decode(_ type: Int32.Type) throws -> Int32   { return 0 }
    func decode(_ type: Int64.Type) throws -> Int64   { return 0 }
    func decode(_ type: UInt.Type) throws -> UInt     { return 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8   { return 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return 0 }
    func decode(_ type: Float.Type) throws -> Float   { return 0 }
    func decode(_ type: Double.Type) throws -> Double { return 0 }
    func decode(_ type: String.Type) throws -> String { return "" }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { return try T(from: DummyDecoder(type)) }
    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        return KeyedDecodingContainer(DummyKeyedDecodingContainer<NestedKey>(decoder))
    }
    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return DummyUnkeyedDecodingContainer(decoder)
    }
    func superDecoder() throws -> Decoder {
        return DummyDecoder(decoder.decodingType)
    }
}
struct DummySingleValueDecodingContainer: SingleValueDecodingContainer {
    let decoder: DummyDecoder
    let codingPath: [CodingKey] = []

    init(_ decoder: DummyDecoder) { self.decoder = decoder }

    func dummy<T>() -> T? {
        return (decoder.decodingType as? DummyCodingValueProvider.Type)?.dummyCodingValue() as? T
    }

    func decodeNil() -> Bool { return true }
    func decode(_ type: Bool.Type) throws -> Bool     { return dummy() ?? false }
    func decode(_ type: Int.Type) throws -> Int       { return dummy() ?? 0 }
    func decode(_ type: Int8.Type) throws -> Int8     { return dummy() ?? 0 }
    func decode(_ type: Int16.Type) throws -> Int16   { return dummy() ?? 0 }
    func decode(_ type: Int32.Type) throws -> Int32   { return dummy() ?? 0 }
    func decode(_ type: Int64.Type) throws -> Int64   { return dummy() ?? 0 }
    func decode(_ type: UInt.Type) throws -> UInt     { return dummy() ?? 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8   { return dummy() ?? 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { return dummy() ?? 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { return dummy() ?? 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { return dummy() ?? 0 }
    func decode(_ type: Float.Type) throws -> Float   { return dummy() ?? 0 }
    func decode(_ type: Double.Type) throws -> Double { return dummy() ?? 0 }
    func decode(_ type: String.Type) throws -> String { return dummy() ?? "" }
    func decode<T: Decodable>(_ type: T.Type) throws -> T { return try T(from: DummyDecoder(type)) }
}

// Main entry point for the TypeDecoder
struct TypeDecoder {
    fileprivate static func decodeInternal(_ type: Decodable.Type, typePath: [Any.Type]) throws -> TypeInfo {
        let internalDecoder = try InternalTypeDecoder(type, typePath: typePath)
        _ = try type.init(from: internalDecoder)
        let typeInfo = internalDecoder.typeInfo
        return typeInfo
    }

    public static func decode(_ type: Decodable.Type) throws -> TypeInfo {
        return try decodeInternal(type, typePath: [])
    }
}
