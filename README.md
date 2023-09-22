[![Build Status][build status badge]][build status]
[![License][license badge]][license]
[![Platforms][platforms badge]][platforms]
[![Documentation][documentation badge]][documentation]

# JSONRPC
A simple Swift library for JSON-RPC

Features:
- type-safety
- flexible data transport support
- concurrency support

## Integration

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.8.0)
]
```

## Usage

The core type you'll use is `JSONRPCSession`. It requires you set up a `DataChannel` object that handles reading and writing raw data.

```swift
let channel = DataChannel(...)
let session = JSONRPCSession(channel: channel)

let params = "hello" // any Encodable
let response: Decodable = try await session.sendRequest(params, method: "my_method")

Task {
    for await (request, handler, data) in session.requestSequence {
        // inspect request, possibly re-decode with more specific type,
        // and reply using the handler
    }
}

Task {
    for await (notification, data) in session.notificationSequence {
        // inspect notification
    }
}
```


### DataChannel

The closures on the `DataChannel` allow different transport mechanisms to be used. The `JSONRPC` package provides a few basic variants:

- Predefined messages channel
  - A channel that delivers a static set of messages
  - Usage: `let channel = await DataChannel.predefinedMessagesChannel(with: messages)`
- Stdio channel
  - Using stdout + stdin as message transport.
  - Note: When using this transport, make sure no non-protocol messages are sent to `stdout`, eg using `print`
  - Usage: `let channel = DataChannel.stdioPipe()`
- Actor channel
  - Using swift actors to pass messages.
  - Can eg be useful for testing, where both client and server are implemented in swift and running in the same process.
  - Usage: `let (clientChannel, serverChannel) = DataChannel.withDataActor()`

## Contributing and Collaboration

I'd love to hear from you! Get in touch via an issue or pull request.

I prefer collaboration, and would love to find ways to work together if you have a similar project.

I prefer indentation with tabs for improved accessibility. But, I'd rather you use the system you want and make a PR than hesitate because of whitespace.

By participating in this project you agree to abide by the [Contributor Code of Conduct](CODE_OF_CONDUCT.md).

[build status]: https://github.com/ChimeHQ/JSONRPC/actions
[build status badge]: https://github.com/ChimeHQ/JSONRPC/workflows/CI/badge.svg
[license]: https://opensource.org/licenses/BSD-3-Clause
[license badge]: https://img.shields.io/github/license/ChimeHQ/JSONRPC
[platforms]: https://swiftpackageindex.com/ChimeHQ/JSONRPC
[platforms badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FChimeHQ%2FJSONRPC%2Fbadge%3Ftype%3Dplatforms
[documentation]: https://swiftpackageindex.com/ChimeHQ/JSONRPC/main/documentation
[documentation badge]: https://img.shields.io/badge/Documentation-DocC-blue
