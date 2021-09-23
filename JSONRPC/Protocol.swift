import Foundation
import AnyCodable
import NullCodable

public struct JSONRPCMessage: Codable {
    public enum Kind {
        case invalid
        case notification
        case request
        case response
    }

    public var jsonrpc: String
    public var id: JSONId?
    public var method: String?
    public var params: AnyCodable?

    @NullCodable
    public var result: AnyCodable?
    public var error: AnyJSONRPCResponseError?

    public var kind: Kind {
        if jsonrpc != "2.0" {
            return .invalid
        }

        let hasId = id != nil
        let hasMethod = method != nil
        let hasResultOrError = result != nil || error != nil
        let hasParams = params != nil

        switch (hasId, hasMethod, hasResultOrError, hasParams) {
        case (false, true, false, _):
            return .notification
        case (true, false, true, false):
            return .response
        case (true, true, false, _):
            return .request
        default:
            return .invalid
        }
    }
}

public struct JSONRPCRequest<T>: Codable where T: Codable {
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

extension JSONRPCRequest: Equatable where T: Equatable {
}

extension JSONRPCRequest: Hashable where T: Hashable {
}

public typealias AnyJSONRPCRequest = JSONRPCRequest<AnyCodable>

public struct JSONRPCNotification<T>: Codable where T: Codable {
    public var jsonrpc = "2.0"
    public var method: String
    public var params: T?

    public init(method: String, params: T? = nil) {
        self.method = method
        self.params = params
    }
}

extension JSONRPCNotification: Equatable where T: Equatable {
}

extension JSONRPCNotification: Hashable where T: Hashable {
}

public typealias AnyJSONRPCNotification = JSONRPCNotification<AnyCodable>

public struct JSONRPCResponseError<T>: Codable where T: Codable {
    public var code: Int
    public var message: String
    public var data: T?
}

extension JSONRPCResponseError: Equatable where T: Equatable {
}

extension JSONRPCResponseError: Hashable where T: Hashable {
}

public typealias AnyJSONRPCResponseError = JSONRPCResponseError<AnyCodable>

public struct JSONRPCResponse<T>: Codable where T: Codable {
    public var jsonrpc: String
    public var id: JSONId

    @NullCodable
    public var result: T?
    public var error: AnyJSONRPCResponseError?

    public init(id: JSONId, result: T?) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
    }

    public init(id: JSONId, errorCode: Int, message: String) {
        self.jsonrpc = "2.0"
        self.id = id
        self.error = AnyJSONRPCResponseError(code: JSONRPCErrors.internalError, message: "No response handler installed", data: nil)
    }
}

extension JSONRPCResponse: Equatable where T: Equatable {
}

extension JSONRPCResponse: Hashable where T: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(jsonrpc)
        hasher.combine(id)
        hasher.combine(result)
        hasher.combine(error)
    }
}

public typealias AnyJSONRPCResponse = JSONRPCResponse<AnyCodable>
