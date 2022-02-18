//
//  JSONRPCError.swift
//  JSONRPC
//
//  Created by Matthew Massicotte on 2021-07-09.
//

import Foundation

public typealias JSONRPCError = Int

public struct JSONRPCErrors {
    public static let parse: JSONRPCError = -32700
    public static let invalidRequest: JSONRPCError = 32600
    public static let methodNotFound: JSONRPCError = 32601
    public static let invalidParams: JSONRPCError = 32602
    public static let internalError: JSONRPCError = 32603
}
