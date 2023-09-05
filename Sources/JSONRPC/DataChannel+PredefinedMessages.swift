import Foundation

#if compiler(>=5.9)

public enum ScriptedMessage: Hashable, Sendable {
	case afterWrite(Data)
	case immediate(Data)
}

actor ScriptedMessageRelay {
	private var messages: [ScriptedMessage]
	private let continuation: DataChannel.DataSequence.Continuation
	public nonisolated let sequence: DataChannel.DataSequence

	init(messages: [ScriptedMessage]) async {
		self.messages = messages

		(self.sequence, self.continuation) = DataChannel.DataSequence.makeStream()

		deliverNextIfNeeded()
	}

	private func deliverNextIfNeeded() {
		guard let next = messages.first else {
			continuation.finish()
			return
		}

		switch next {
		case .immediate(let data):
			messages.removeFirst()

			continuation.yield(data)
			deliverNextIfNeeded()
		case .afterWrite:
			break
		}

	}

	func onWrite() {
		guard let next = messages.first else {
			continuation.finish()
			return
		}

		switch next {
		case let .afterWrite(data):
			messages.removeFirst()

			continuation.yield(data)

			deliverNextIfNeeded()
		case .immediate:
			fatalError("this should never occur")
		}
	}
}

extension DataChannel {
	/// A channel that delivers a static set of messages.
	///
	/// This will delivery messages in order, after each `write` is performed. Useful for testing.
	public static func predefinedMessagesChannel(with messages: [ScriptedMessage]) async -> DataChannel {
		let relay = await ScriptedMessageRelay(messages: messages)

		return DataChannel(
			writeHandler: { _ in
				// strong-ref here to keep relay alive
				await relay.onWrite()
			},
			dataSequence: relay.sequence)
	}
}

#endif
