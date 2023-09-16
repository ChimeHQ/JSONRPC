import Foundation

extension FileHandle {
	public var dataStream: AsyncStream<Data> {
		let (stream, continuation) = AsyncStream<Data>.makeStream()

		readabilityHandler = { handle in
			let data = handle.availableData

			if data.isEmpty {
				handle.readabilityHandler = nil
				continuation.finish()
				return
			}

			continuation.yield(data)
		}

		return stream
	}
}

extension DataChannel {
	public static func stdioPipe() -> DataChannel {

		let writeHandler: DataChannel.WriteHandler = {
			FileHandle.standardOutput.write($0)
		}

		return DataChannel(writeHandler: writeHandler, dataSequence: FileHandle.standardInput.dataStream)
	}
}
