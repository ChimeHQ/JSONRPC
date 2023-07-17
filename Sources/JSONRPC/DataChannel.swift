import Foundation

/// Provides reading and writing facilities.
public struct DataChannel: Sendable {
	public typealias WriteHandler = @Sendable (Data) async throws -> Void
	public typealias DataSequence = AsyncStream<Data>

	public let writeHandler: WriteHandler
	public let dataSequence: DataSequence

	public init(writeHandler: @escaping WriteHandler, dataSequence: DataSequence) {
		self.writeHandler = writeHandler
		self.dataSequence = dataSequence
	}
}

extension DataChannel {
	/// Create a passthrough `DataChannel` that invokes a closure on read and write.
	public static func tap(
		channel: DataChannel,
		onRead: @Sendable @escaping (Data) async -> Void,
		onWrite: @Sendable @escaping (Data) async -> Void
	) -> DataChannel {

		let writeHandler: DataChannel.WriteHandler = {
			await onWrite($0)

			try await channel.writeHandler($0)
		}

		var iterator = channel.dataSequence.makeAsyncIterator()
		let dataStream = AsyncStream<Data> {
			let data = await iterator.next()

			if let data = data {
				await onRead(data)
			}

			return data
		}

		return DataChannel(writeHandler: writeHandler,
						   dataSequence: dataStream)
	}
}
