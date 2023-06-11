import Foundation

public enum JSONRPCProtocolError: Error {
    case unsupportedVersion(String)
    case malformedMessage
}

public enum JSONRPCMessage {
    case notification(String, JSONValue)
    case request(JSONId, String, JSONValue?)
    case response(JSONId)
    case undecodableId(AnyJSONRPCResponseError)
}

extension JSONRPCMessage: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case error
        case result
        case method
        case params
        case jsonrpc
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let version = try container.decode(String.self, forKey: .jsonrpc)
        if version != "2.0" {
            throw JSONRPCProtocolError.unsupportedVersion(version)
        }

        // no id means notification
        if container.contains(.id) == false {
            let method = try container.decode(String.self, forKey: .method)
            let params = try? container.decode(JSONValue.self, forKey: .params)

			self = .notification(method, params ?? .null)
            return
        }

        // id = null
        if (try? container.decodeNil(forKey: .id)) == true {
            let error = try container.decode(AnyJSONRPCResponseError.self, forKey: .error)

            self = .undecodableId(error)
            return
        }

        let id = try container.decode(JSONId.self, forKey: .id)

        if container.contains(.method) {
            let method = try container.decode(String.self, forKey: .method)
            let params = try? container.decode(JSONValue.self, forKey: .params)

            self = .request(id, method, params)
            return
        }

        self = .response(id)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode("2.0", forKey: .jsonrpc)

        switch self {
        case .undecodableId(let error):
            try container.encodeNil(forKey: .id)
            try container.encode(error, forKey: .error)
        case .notification(let method, let params):
            try container.encode(method, forKey: .method)

			if params != JSONValue.null {
                try container.encode(params, forKey: .params)
            }
        case .request(let id, let method, let params):
            try container.encode(id, forKey: .id)
            try container.encode(method, forKey: .method)

            if let params = params {
                try container.encode(params, forKey: .params)
            }
        case .response(let id):
            try container.encode(id, forKey: .id)

            throw JSONRPCProtocolError.malformedMessage
        }
    }

}

public struct JSONRPCRequest<T> {
    public var jsonrpc = "2.0"
    public var id: JSONId
    public var method: String
    public var params: T?

    public init(id: JSONId, method: String, params: T? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }

    public init(id: Int, method: String, params: T? = nil) {
        self.init(id: .numericId(id), method: method, params: params)
    }
}

extension JSONRPCRequest: Encodable where T: Encodable {
}

extension JSONRPCRequest: Decodable where T: Decodable {
}

extension JSONRPCRequest: Equatable where T: Equatable {
}

extension JSONRPCRequest: Hashable where T: Hashable {
}

public typealias AnyJSONRPCRequest = JSONRPCRequest<JSONValue>

public struct JSONRPCNotification<T> {
    public var jsonrpc = "2.0"
    public var method: String
    public var params: T?

    public init(method: String, params: T? = nil) {
        self.method = method
        self.params = params
    }
}

extension JSONRPCNotification: Encodable where T: Encodable {
}

extension JSONRPCNotification: Decodable where T: Decodable {
}

extension JSONRPCNotification: Equatable where T: Equatable {
}

extension JSONRPCNotification: Hashable where T: Hashable {
}

public typealias AnyJSONRPCNotification = JSONRPCNotification<JSONValue>

public struct JSONRPCResponseError<T> {
    public var code: Int
    public var message: String
    public var data: T?

    public init(code: Int, message: String, data: T? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

extension JSONRPCResponseError: Encodable where T: Encodable {}
extension JSONRPCResponseError: Decodable where T: Decodable {}
extension JSONRPCResponseError: Equatable where T: Equatable {}
extension JSONRPCResponseError: Hashable where T: Hashable {}
extension JSONRPCResponseError: Sendable where T: Sendable {}

public typealias AnyJSONRPCResponseError = JSONRPCResponseError<JSONValue>

public enum JSONRPCResponse<T> {
    case result(JSONId, T)
    case failure(JSONId, AnyJSONRPCResponseError)

	private enum CodingKeys: String, CodingKey {
		case id
		case error
		case result
		case jsonrpc
	}
	
    public init(id: JSONId, result: T) {
        self = .result(id, result)
    }

    public var result: T? {
        switch self {
        case .result(_, let value):
            return value
        default:
            return nil
        }
    }

    public var error: AnyJSONRPCResponseError? {
        switch self {
        case .result:
            return nil
        case .failure(_, let error):
            return error
        }
    }

    public var id: JSONId {
        switch self {
        case .result(let id, _):
            return id
        case .failure(let id, _):
            return id
        }
    }

    public var jsonrpc: String {
        return "2.0"
    }
}

extension JSONRPCResponse: Decodable where T: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let version = try container.decode(String.self, forKey: .jsonrpc)
        if version != "2.0" {
            throw JSONRPCProtocolError.unsupportedVersion(version)
        }

        let id = try container.decode(JSONId.self, forKey: .id)

        if container.contains(.error) == false {
            let value = try container.decode(T.self, forKey: .result)
            self = .result(id, value)

            return
        }

        if container.contains(.result) == false {
            let error = try container.decode(AnyJSONRPCResponseError.self, forKey: .error)
            self = .failure(id, error)

            return
        }

        // ok, we have both. This is not allowed by the spec, but we
        // don't want to be too strict with what we accept
        if try container.decodeNil(forKey: .error) {
            let value = try container.decode(T.self, forKey: .result)
            self = .result(id, value)

            return
        }

        // in this case,
        if try container.decodeNil(forKey: .result) {
            let error = try container.decode(AnyJSONRPCResponseError.self, forKey: .error)
            self = .failure(id, error)

            return
        }

        throw JSONRPCProtocolError.malformedMessage
    }
}

extension JSONRPCResponse: Encodable where T: Encodable {
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode("2.0", forKey: .jsonrpc)

		switch self {
		case .failure(let id, let error):
			try container.encode(id, forKey: .id)
			try container.encode(error, forKey: .error)
		case .result(let id, let value):
			try container.encode(id, forKey: .id)
			try container.encode(value, forKey: .result)
		}
	}
}

extension JSONRPCResponse: Equatable where T: Equatable {}
extension JSONRPCResponse: Hashable where T: Hashable {}
extension JSONRPCResponse: Sendable where T: Sendable {}

extension JSONRPCResponse {
    static func internalError(id: JSONId, message: String, data: JSONValue = nil) -> JSONRPCResponse<JSONValue> {
        let error = AnyJSONRPCResponseError(code: JSONRPCErrors.internalError,
                                            message: message,
                                            data: data)
        return .failure(id, error)
    }
}

public typealias AnyJSONRPCResponse = JSONRPCResponse<JSONValue>
