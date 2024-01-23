import Foundation

extension DataChannel {
    /// A channel that facilitates communication over WebSockets.
    public static func webSocket(
        url: URL,
        terminationHandler: @escaping @Sendable () -> Void
    ) throws -> DataChannel {
        let socketSession: URLSession = .init(configuration: .default)
        let socket: URLSessionWebSocketTask = socketSession.webSocketTask(with: url)
        
        socket.resume()
        
        let (stream, continuation) = DataSequence.makeStream()

        Task {
            while socket.state == .running {
                do {
                    let message = try await socket.receive()
                    switch message {
                    case .data(let data):
                        continuation.yield(data)
                    case .string(let string):
                        continuation.yield(Data(string.utf8))
                    @unknown default:
                        fatalError("Unhandled message type")
                    }
                } catch {
                    if socket.state == .canceling {
                        terminationHandler()
                    }
                    continuation.finish()
                    throw error
                }
            }
        }
        
        let writeHandler: DataChannel.WriteHandler = {
            try await socket.send(.data($0))
        }
        
        return DataChannel(writeHandler: writeHandler, dataSequence: stream)
    }
}
