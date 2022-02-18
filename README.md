# JSONRPC

There are already a bunch of packages out there for doing JSON-RPC in Swift. This one is just very simple and makes no assumptions about the transport stream type.

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
public var requestHandler: ((AnyJSONRPCRequest, Data, @escaping (AnyJSONRPCResponse) -> Void) -> Void)?
public var notificationHandler: ((AnyJSONRPCNotification, Data, @escaping (Error?) -> Void) -> Void)?
public var errorHandler: ((Error) -> Void)?

public func sendRequest<T, U>(_ params: T, method: String, responseHandler: @escaping (ResponseResult<U>) -> Void) where T: Codable, U: Decodable
public func sendNotification<T>(_ params: T?, method: String, completionHandler: @escaping (Error?) -> Void = {_ in }) where T: Codable
```

### StdioDataTransport

This is a concrete implemenation of the `DataTransport` protocol, which passes data across stdio. 

### Suggestions or Feedback

We'd love to hear from you! Get in touch via [twitter](https://twitter.com/chimehq), an issue, or a pull request.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.
