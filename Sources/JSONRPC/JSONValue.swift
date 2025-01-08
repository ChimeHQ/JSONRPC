import Foundation

public enum JSONValue: Codable, Hashable, Sendable {
	case null
	case bool(Bool)
	case number(Double)
	case string(String)
	case array([JSONValue])
	case hash([String: JSONValue])

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()

		switch self {
		case .null:
			try container.encodeNil()
		case .bool(let value):
			try container.encode(value)
		case .number(let value):
			try container.encode(value)
		case .string(let value):
			try container.encode(value)
		case .array(let value):
			try container.encode(value)
		case .hash(let value):
			try container.encode(value)
		}
	}

	public init(from decoder: Decoder) throws {
		let single = try? decoder.singleValueContainer()

		if let value = try? single?.decode([String: JSONValue].self) {
			self = .hash(value)
			return
		}

		if let value = try? single?.decode([JSONValue].self) {
			self = .array(value)
			return
		}

		if let value = try? single?.decode(String.self) {
			self = .string(value)
			return
		}

		if let value = try? single?.decode(Double.self) {
			self = .number(value)
			return
		}

		if let value = try? single?.decode(Bool.self) {
			self = .bool(value)
			return
		}

		if single?.decodeNil() == true {
			self = .null
			return
		}

		throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "failed to decode JSON object"))
	}
}

extension JSONValue: ExpressibleByNilLiteral {
	public init(nilLiteral: ()) {
		self = .null
	}
}

extension JSONValue: ExpressibleByDictionaryLiteral {
	public init(dictionaryLiteral elements: (String, JSONValue)...) {
		var hash = [String: JSONValue]()

		for element in elements {
			hash[element.0] = element.1
		}

		self = .hash(hash)
	}
}

extension JSONValue: ExpressibleByStringLiteral {
	public init(stringLiteral: String) {
		self = .string(stringLiteral)
	}
}

extension JSONValue: ExpressibleByIntegerLiteral {
	public init(integerLiteral value: IntegerLiteralType) {
		self = .number(Double(value))
	}
}

extension JSONValue: ExpressibleByFloatLiteral {
	public init(floatLiteral value: FloatLiteralType) {
		self = .number(value)
	}
}

extension JSONValue: ExpressibleByArrayLiteral {
	public init(arrayLiteral elements: JSONValue...) {
		var array = [JSONValue]()

		for element in elements {
			array.append(element)
		}

		self = .array(array)
	}
}

extension JSONValue: ExpressibleByBooleanLiteral {
	public init(booleanLiteral value: BooleanLiteralType) {
		self = .bool(value)
	}
}

extension JSONValue: CustomStringConvertible {
	public var description: String {
		switch self {
		case .null:
			"nil"
		case let .bool(value):
			value.description
		case let .number(value):
			value.description
		case let .string(value):
			value
		case let .array(value):
			value.description
		case let .hash(value):
			value.description
		}
	}
}
