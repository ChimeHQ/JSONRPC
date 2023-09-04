import Foundation

#if compiler(>=5.9)

actor PredefinedMessageRelay {
	private var messages: [Data]
	private let continuation: DataChannel.DataSequence.Continuation
	public nonisolated let sequence: DataChannel.DataSequence

	init(messages: [Data]) {
		self.messages = messages

		(self.sequence, self.continuation) = DataChannel.DataSequence.makeStream()
	}

	init<T: Encodable>(content: [T]) throws {
		let messages = try content.map { try JSONEncoder().encode($0) }

		self.init(messages: messages)
	}

	func write() {
		continuation.yield(messages.removeFirst())
	}
}

extension DataChannel {
	/// A channel that delivers a static set of messages.
	///
	/// This will delivery messages in order, after each `write` is performed. Useful for testing.
	public static func predefinedMessagesChannel<T: Encodable & Sendable>(_ content: [T]) throws -> DataChannel {
		let relay = try PredefinedMessageRelay(content: content)

		return DataChannel(
			writeHandler: { _ in
				// strong-ref here to keep relay alive
				await relay.write()
			},
			dataSequence: relay.sequence)
	}
}

#endif
