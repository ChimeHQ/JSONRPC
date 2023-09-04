import XCTest
import JSONRPC

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
	static func predefinedMessagesChannel<T: Encodable>(_ content: [T]) throws -> DataChannel {
		let relay = try PredefinedMessageRelay(content: content)

		return DataChannel(
			writeHandler: { _ in
				// strong-ref here to keep relay alive
				await relay.write()
			},
			dataSequence: relay.sequence)
	}
}

final class JSONRPCSessionTests: XCTestCase {
	typealias TestResponse = JSONRPCResponse<String?>

	func testResultResponse() async throws {
		let pair = DataChannel.DataSequence.makeStream()

		let channel = DataChannel(writeHandler: { _ in },
								  dataSequence: pair.stream)

		let transport = JSONRPCSession(channel: channel)

		let task = Task<TestResponse, Error> {
			let params = "hello"
			return try await transport.sendRequest(params, method: "mymethod")
		}

		let data = try JSONEncoder().encode(TestResponse(id: JSONId(1), result: "goodbye"))
		pair.continuation.yield(data)

		let response = try await task.value

		XCTAssertEqual(response.result, "goodbye")
	}

	func testManySendRequestsWithResponses() async throws {
		let iterations = 1000

		// be sure to start at 1, to match id generation
		let responses = (1...iterations).map { i in
			let responseParam = "goodbye-\(i)"

			return TestResponse(id: JSONId(i), result: responseParam)
		}

		let channel = try DataChannel.predefinedMessagesChannel(responses)
		let session = JSONRPCSession(channel: channel)

		let params = "hello"
		
		for i in 1...iterations {
			let expectedResponse = "goodbye-\(i)"

			let response: TestResponse = try await session.sendRequest(params, method: "mymethod")

			XCTAssertEqual(try! response.content.get(), expectedResponse)
		}
	}
}

#endif
