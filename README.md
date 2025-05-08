<div align="center">

[![Build Status][build status badge]][build status]
[![Platforms][platforms badge]][platforms]
[![Documentation][documentation badge]][documentation]
[![Matrix][matrix badge]][matrix]

</div>

# JSONRPC
A simple Swift library for [JSON-RPC](https://www.jsonrpc.org)

Features:
- type-safety
- flexible data transport support
- concurrency support

## Integration

```swift
dependencies: [
    .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.9.0")
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
    for await event in await session.eventSequence {
        switch event {
        case .request(let request, let handler, let data):
            // inspect request, possibly re-decode with more specific type,
            // and reply using the handler

        case .notification(let notification, let data):
            // inspect notification
        case .error(let error):
            print("Error: \(error)")
        }
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
- WebSocket channel
  - Uses `URLSessionWebSocketTask` as a message transport.
  - Usage: `let channel = DataChannel.webSocket(url: socketURL, terminationHandler: { print("socket closed" })`

## Contributing and Collaboration

I would love to hear from you! Issues or pull requests work great. Both a [Matrix space][matrix] and [Discord][discord] are available for live help, but I have a strong bias towards answering in the form of documentation. You can also find me on [mastodon](https://mastodon.social/@mattiem).

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
[matrix]: https://matrix.to/#/%23chimehq%3Amatrix.org
[matrix badge]: https://img.shields.io/matrix/chimehq%3Amatrix.org?label=Matrix
[discord]: https://discord.gg/esFpX6sErJ
