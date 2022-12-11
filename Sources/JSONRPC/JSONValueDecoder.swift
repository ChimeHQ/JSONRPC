import Foundation
import Combine

/// An object that decodes instances of a data type from `JSONValue` objects.
public class JSONValueDecoder: TopLevelDecoder {
    public typealias Input = JSONValue

    public init() {
        // Do nothing, this definition here just to bump constructor visibility
    }

    /// Returns a value of the type you specify, decoded from a `JSONValue` object.
    public func decode<T>(
        _ type: T.Type,
        from: JSONValueDecoder.Input
    ) throws -> T where T: Decodable {
        return try T(from: JSONValueDecoderImpl(referencing: from))
    }
}

internal struct JSONKey: CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }

    internal static let `super` = JSONKey(stringValue: "super")
}

internal class JSONUnkeyedContainer: UnkeyedDecodingContainer {
    private let decoder: JSONValueDecoderImpl
    private let container: [JSONValue]
    private(set) public var currentIndex: Int = 0

    internal init(referencing decoder: JSONValueDecoderImpl, wrapping container: [JSONValue]) {
        self.decoder = decoder
        self.container = container
    }

    public var codingPath: [CodingKey] {
        return decoder.codingPath
    }

    public var count: Int? {
        return container.count
    }

    public var isAtEnd: Bool {
        return currentIndex >= container.count
    }

    private func withNextValue<T>(result: (_ value: JSONValue) throws -> T) throws -> T {
        decoder.codingPath.append(JSONKey(intValue: self.currentIndex))
        defer { decoder.codingPath.removeLast() }

        if isAtEnd {
            throw DecodingError.valueNotFound(
                JSONValue?.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Array exhausted."
                )
            )
        }

        let value = container[currentIndex]
        currentIndex += 1

        return try result(value)
    }

    func decodeNil() throws -> Bool {
        return try withNextValue { value in return value == .null }
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try withNextValue { value in
            return try decoder.nested(for: value).singleValueContainer().decode(type)
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws ->
            KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        return try withNextValue { value in
            return try decoder.nested(for: value).container(keyedBy: type)
        }
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        return try withNextValue { value in
            return try decoder.nested(for: value).unkeyedContainer()
        }
    }

    func superDecoder() throws -> Decoder {
        throw DecodingError.valueNotFound(
            JSONValue?.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Super not supported for arrays."
            )
        )
    }
}

internal class JSONKeyedContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    let decoder: JSONValueDecoderImpl
    let container: [String: JSONValue]

    internal init(referencing decoder: JSONValueDecoderImpl,
                  wrapping container: [String: JSONValue]) {
        self.decoder = decoder
        self.container = container
    }

    public var codingPath: [CodingKey] {
        return decoder.codingPath
    }

    public var allKeys: [Key] {
        return container.keys.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        return container[key.stringValue] != nil
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        if let entry = container[key.stringValue] {
            return entry == .null
        } else {
            return true
        }
    }

    private func withValue<T>(forKey key: CodingKey,
                              result: (_ entry: JSONValue) throws -> T) throws -> T {
        guard let value = container[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "No value associated with key \(key) (\"\(key.stringValue)\")"
                )
            )
        }

        decoder.codingPath.append(key)
        defer { decoder.codingPath.removeLast() }

        return try result(value)
    }

    func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
        try withValue(forKey: key) { value in
            return try decoder.nested(for: value).singleValueContainer().decode(type)
        }
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key)
            throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        try withValue(forKey: key) { value in
            return try decoder.nested(for: value).container(keyedBy: type)
        }
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        try withValue(forKey: key) { value in
            return try decoder.nested(for: value).unkeyedContainer()
        }
    }

    public func superDecoder() throws -> Decoder {
        try withValue(forKey: JSONKey.super) { value in decoder.nested(for: value) }
    }

    public func superDecoder(forKey key: Key) throws -> Decoder {
        try withValue(forKey: key) { value in decoder.nested(for: value) }
    }
}

internal class JSONValueDecoderImpl: Decoder, SingleValueDecodingContainer {
    internal(set) public var codingPath: [CodingKey]
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    private let value: JSONValue

    init(referencing value: JSONValue, at codingPath: [CodingKey] = []) {
        self.value = value
        self.codingPath = codingPath
    }

    internal func nested(for value: JSONValue) -> JSONValueDecoderImpl {
        return JSONValueDecoderImpl(referencing: value, at: codingPath)
    }

    private func unsatisfiedType(_ type: Any.Type) throws -> Never {
        throw DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "\(String(describing: value)) not a \(type)",
                underlyingError: nil
            )
        )
    }

    private func inconvertibleType(_ type: Any.Type) throws -> Never {
        throw DecodingError.typeMismatch(
            type,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "\(String(describing: value)) cannot be converted to \(type)",
                underlyingError: nil
            )
        )
    }

    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
            where Key: CodingKey {
        if case let .hash(dictionary) = value {
            return KeyedDecodingContainer(JSONKeyedContainer<Key>(referencing: self, wrapping: dictionary))
        } else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "\(String(describing: value)) not a container",
                    underlyingError: nil
                )
            )
        }
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        if case let .array(array) = value {
            return JSONUnkeyedContainer(referencing: self, wrapping: array)
        } else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "\(String(describing: value)) not a container",
                    underlyingError: nil
                )
            )
        }
    }

    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        self
    }

    func decodeNil() -> Bool {
        return self.value == .null
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case let .bool(value) = self.value else { try unsatisfiedType(type) }
        return value
    }

    func decode(_ type: String.Type) throws -> String {
        guard case let .string(value) = self.value else { try unsatisfiedType(type) }
        return value
    }

    func decode(_ type: Double.Type) throws -> Double {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        return value
    }

    func decode(_ type: Float.Type) throws -> Float {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        return Float(value)
    }

    func decode(_ type: Int.Type) throws -> Int {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = Int(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = Int8(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = Int16(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = Int32(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = Int64(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = UInt(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = UInt8(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = UInt16(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = UInt32(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard case let .number(value) = self.value else { try unsatisfiedType(type) }
        guard let value = UInt64(exactly: value) else { try inconvertibleType(type) }
        return value
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        return try T(from: self)
    }
}
