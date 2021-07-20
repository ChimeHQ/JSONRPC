import Foundation
import AnyCodable

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
    public var result: T?
    public var error: AnyJSONRPCResponseError?

    public init(id: JSONId, result: T) {
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
}

public typealias AnyJSONRPCResponse = JSONRPCResponse<AnyCodable>
