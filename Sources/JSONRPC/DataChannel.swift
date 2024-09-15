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
