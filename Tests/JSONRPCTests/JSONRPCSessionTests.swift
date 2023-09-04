import XCTest
import JSONRPC

#if compiler(>=5.9)

final class JSONRPCSessionTests: XCTestCase {
	typealias TestResponse = JSONRPCResponse<String?>

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
		let dataTransport = MockDataTransport()
		let transport = ProtocolTransport(dataTransport: dataTransport)

		let expectation = XCTestExpectation(description: "Notification Message")

		let params = "hello"

		transport.sendNotification(params, method: "mynotification") { (error) in
			XCTAssertNil(error)
			expectation.fulfill()
		}

		wait(for: [expectation], timeout: 1.0)

		let result = JSONRPCNotification(method: "mynotification", params: params)
		let resultData = try JSONEncoder().encode(result)

		assertDataArraysEquals(dataTransport.writtenData, [resultData])
	}
}

#endif
