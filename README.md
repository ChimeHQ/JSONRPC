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

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/JSONRPC")
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

### Suggestions or Feedback

We'd love to hear from you! Get in touch via an issue or pull request.

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

[build status]: https://github.com/ChimeHQ/JSONRPC/actions
[build status badge]: https://github.com/ChimeHQ/JSONRPC/workflows/CI/badge.svg
[license]: https://opensource.org/licenses/BSD-3-Clause
[license badge]: https://img.shields.io/github/license/ChimeHQ/JSONRPC
[platforms]: https://swiftpackageindex.com/ChimeHQ/JSONRPC
[platforms badge]: https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FChimeHQ%2FJSONRPC%2Fbadge%3Ftype%3Dplatforms
[documentation]: https://swiftpackageindex.com/ChimeHQ/JSONRPC/main/documentation
[documentation badge]: https://img.shields.io/badge/Documentation-DocC-blue
