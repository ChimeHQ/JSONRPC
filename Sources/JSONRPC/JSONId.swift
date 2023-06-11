import Foundation

public enum JSONId: Sendable {
    case numericId(Int)
    case stringId(String)

    public init(_ value: Int) {
        self = .numericId(value)
    }

    public init(_ value: String) {
        self = .stringId(value)
    }
}

extension JSONId: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(Int.self) {
            self = .numericId(value)
        } else if let value = try? container.decode(String.self) {
            self = .stringId(value)
        } else {
            let ctx = DecodingError.Context(codingPath: container.codingPath, debugDescription: "Unknown JSONId Type")
            throw DecodingError.typeMismatch(JSONId.self, ctx)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .numericId(let value):
            try container.encode(value)
        case .stringId(let value):
            try container.encode(value)
        }
    }
}

extension JSONId: Hashable {
}

extension JSONId: CustomStringConvertible {
    public var description: String {
        switch self {
        case .stringId(let str):
            return str
        case .numericId(let num):
            return String(num)
        }
    }
}

extension JSONId: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

extension JSONId: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
