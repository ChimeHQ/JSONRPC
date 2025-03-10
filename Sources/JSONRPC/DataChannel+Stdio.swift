import Foundation
#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

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

	public static func stdio(flushWrites: Bool = true) -> DataChannel {

		let writeHandler: DataChannel.WriteHandler = { data in
			FileHandle.standardOutput.write(data)
			if flushWrites {
				fflush(stdout)
			}
		}

		return DataChannel(writeHandler: writeHandler, dataSequence: FileHandle.standardInput.dataStream)
	}
}
