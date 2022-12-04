[![Build Status][build status badge]][build status]
[![License][license badge]][license]
[![Platforms][platforms badge]][platforms]
[![Documentation][documentation badge]][documentation]

# JSONRPC
A simple Swift library for JSON-RPC. It features strong type-safety and makes no assumptions about the underlying transport stream.

## Integration

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/JSONRPC")
]
```

## Classes

### ProtocolTransport

This is the core class for using the protocol. It supports sending and receiving generic messages and notifications, as well as responding to protocol-level errors.

```swift
// takes a struct with all of the handler functions needed.
public func setHandlers(_ handlers: Handlers)

public func sendRequest<T, U>(_ params: T, method: String, responseHandler: @escaping (ResponseResult<U>) -> Void) where T: Codable, U: Decodable
public func sendRequest<T, U>(_ params: T, method: String) async throws -> JSONRPCResponse<U> where T: Codable, U: Decodable

public func sendNotification<T>(_ params: T?, method: String, completionHandler: @escaping (Error?) -> Void = {_ in }) where T: Codable
public func sendNotification<T>(_ params: T?, method: String) async throws where T: Codable
```

### StdioDataTransport

This is a concrete implementation of the `DataTransport` protocol, which passes data across stdio. 

### MessageTransport

This gives you a way to frame/delimit messages in the wire protocol. It is optional, in case you don't need/want to use that functionality. It relies on the `MessageProtocol` protocol.

### SeperatedHTTPHeaderMessageProtocol

A concrete `MessageProtocol` that uses HTTP headers. It requires at least `Content-Length`, and by default expects all fields to be separated by `\r\n`.

### Suggestions or Feedback

We'd love to hear from you! Get in touch via [twitter](https://twitter.com/chimehq), an issue, or a pull request.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

[build status]: https://github.com/ChimeHQ/JSONRPC/actions
[build status badge]: https://github.com/ChimeHQ/JSONRPC/workflows/CI/badge.svg
[license]: https://opensource.org/licenses/BSD-3-Clause
[license badge]: https://img.shields.io/github/license/ChimeHQ/JSONRPC
[platforms]: https://swiftpackageindex.com/ChimeHQ/JSONRPC
[platforms badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FChimeHQ%2FJSONRPC%2Fbadge%3Ftype%3Dplatforms
[documentation]: https://swiftpackageindex.com/ChimeHQ/JSONRPC/main/documentation
[documentation badge]: https://img.shields.io/badge/Documentation-DocC-blue
