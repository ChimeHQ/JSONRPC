import Foundation

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
	public static func transportChannel<Transport: DataTransport>(with transport: Transport) -> DataChannel where Transport: Sendable {
		let framing = SeperatedHTTPHeaderMessageFraming()
		let messageTransport = MessageTransport(dataTransport: transport, messageProtocol: framing)

		let stream = DataSequence { continuation in
			messageTransport.setReaderHandler { data in
				continuation.yield(data)
			}
		}

		return DataChannel(writeHandler: { data in
			messageTransport.write(data)
		}, dataSequence: stream)
	}
}
