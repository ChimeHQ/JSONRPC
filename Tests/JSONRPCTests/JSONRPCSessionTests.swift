import XCTest
import JSONRPC

#if compiler(>=5.9)

final class JSONRPCSessionTests: XCTestCase {
	typealias TestResponse = JSONRPCResponse<String?>
	typealias TestNotification = JSONRPCNotification<String>

	func testResultResponse() async throws {
		let pair = DataChannel.DataSequence.makeStream()

		let channel = DataChannel(writeHandler: { _ in },
								  dataSequence: pair.stream)

		let session = JSONRPCSession(channel: channel)

		let task = Task<TestResponse, Error> {
			let params = "hello"
			return try await session.sendRequest(params, method: "mymethod")
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

	func testSendNotification() async throws {
		let pair = DataChannel.DataSequence.makeStream()

		let params = "hello"
		let method = "mynotification"

		let result = TestNotification(method: method, params: params)

		let expectation = XCTestExpectation(description: "Notification Message")

		let channel = DataChannel(
			writeHandler: { data in
				// have to decode this here to make sure json key ordering does not matter
				let notification = try JSONDecoder().decode(TestNotification.self, from: data)
				XCTAssertEqual(notification, result)

				expectation.fulfill()
			},
			dataSequence: pair.stream
		)

		let session = JSONRPCSession(channel: channel)

		try await session.sendNotification(params, method: method)

		await fulfillment(of: [expectation], timeout: 1.0)
	}
}

#endif
