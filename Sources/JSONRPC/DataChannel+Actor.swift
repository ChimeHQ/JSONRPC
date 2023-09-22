import Foundation

public protocol ReceiveQueue : Collection where Element == Data {
	mutating func append(_ newElement: Element)
	mutating func popFirst() -> Element?
}

extension Array : ReceiveQueue where Element == Data {
	public mutating func popFirst() -> Data? {
		if isEmpty == true {
			return nil
		}

		return self.removeFirst()
	}
}

actor DataActor<Queue> where Queue : ReceiveQueue {
	private var queue: Queue
	private var continuation: CheckedContinuation<Data, Never>?
	private(set) var numSent: Int
	public var numReceived: Int { numSent - queue.count }
	private(set) var numBlocked: Int
	public var queueCount: Int { queue.count }

	public init(queueProvider: @Sendable () -> Queue) {
		self.queue = queueProvider()
		self.numSent = 0
		self.numBlocked = 0
	}

	public func send(_ data: Data) -> Void {
		numSent += 1
		if let c = continuation {
			assert(queue.isEmpty)
			continuation = nil
			c.resume(returning: data)
		}
		else {
			queue.append(data)
		}
	}

	public func recv() async -> Data {
		if let data = queue.popFirst() {
			return data
		}

		numBlocked += 1

		return await withCheckedContinuation {
			continuation = $0
		}
	}
}

extension DataActor where Queue : Sendable {
	init(queue: Queue) {
		self.init(queueProvider: { queue })
	}
}

extension DataChannel {
	/// Create a pair of `DataActor` channels.
	///
	/// The actor data channel conist of two directional actor data channels with crossover send/receive members.
	public static func withDataActor<Queue>(
		queueProvider: @Sendable () -> Queue
	) -> (clientChannel: DataChannel, serverChannel: DataChannel) where Queue : ReceiveQueue {
		let clientActor = DataActor<Queue>(queueProvider: queueProvider)
		let serverActor = DataActor<Queue>(queueProvider: queueProvider)

		let clientChannel = makeChannel(sender: clientActor, reciever: serverActor)
		let serverChannel = makeChannel(sender: serverActor, reciever: clientActor)

		return (clientChannel, serverChannel)
	}

	// Default actor channel with Array queue storage
	public static func withDataActor() -> (clientChannel: DataChannel, serverChannel: DataChannel) {
		return withDataActor(queueProvider: { Array<Data>() })
	}

	private static func makeChannel<Queue>(
		sender: DataActor<Queue>,
		reciever: DataActor<Queue>,
		onCancel: (@Sendable () -> Void)? = nil
	) -> DataChannel {
		let writeHandler = { @Sendable data in
			await sender.send(data)
		}

		let dataSequence = DataChannel.DataSequence {
				await reciever.recv()
		} onCancel: { onCancel?() }

		return DataChannel(writeHandler: writeHandler, dataSequence: dataSequence)
	}
}
