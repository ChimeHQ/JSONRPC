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
	@available(*, deprecated, renamed: "stdio", message: "Use stdio instead")
	public static func stdioPipe() -> DataChannel {
		stdio()
	}

	public static func stdio() -> DataChannel {

		let writeHandler: DataChannel.WriteHandler = { data in
			// Add a line break to flush the stdout buffer.
			var data = data
			data.append(contentsOf: lineBreak)

			FileHandle.standardOutput.write(data)
		}

		return DataChannel(writeHandler: writeHandler, dataSequence: FileHandle.standardInput.dataStream)
	}

	private static let lineBreak = [UInt8(ascii: "\n")]
}
