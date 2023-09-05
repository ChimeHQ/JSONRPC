import XCTest
import JSONRPC

#if compiler(>=5.9)

final class JSONRPCSessionTests: XCTestCase {
	typealias TestResponse = JSONRPCResponse<String?>
	typealias TestNotification = JSONRPCNotification<String>

	func testResultResponse() async throws {
		let expectedResponse = TestResponse(id: JSONId(1), result: "goodbye")

		let messages: [ScriptedMessage] = [
			.afterWrite(try JSONEncoder().encode(expectedResponse)),
		]

		let channel = await DataChannel.predefinedMessagesChannel(with: messages)
		let session = JSONRPCSession(channel: channel)

		let response: TestResponse = try await session.sendRequest("hello", method: "mymethod")

		XCTAssertEqual(response, expectedResponse)
	}

	func testManySendRequestsWithResponses() async throws {
		let iterations = 1000

		// be sure to start at 1, to match id generation
		let messages = try (1...iterations).map { i in
			let responseParam = "goodbye-\(i)"

			let response = TestResponse(id: JSONId(i), result: responseParam)
			let data = try JSONEncoder().encode(response)

			return ScriptedMessage.afterWrite(data)
		}

		let channel = await DataChannel.predefinedMessagesChannel(with: messages)
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

	func testServerToClientNotification() async throws {
		let pair = DataChannel.DataSequence.makeStream()

		let channel = DataChannel(writeHandler: { _ in },
								  dataSequence: pair.stream)

		let session = JSONRPCSession(channel: channel)

		let params = "hello"
		let method = "mynotification"

		let result = TestNotification(method: method, params: params)

		let expectation = XCTestExpectation(description: "Notification Message")

		Task {
			for await notePair in await session.notificationSequence {
				let notification = try JSONDecoder().decode(TestNotification.self, from: notePair.1)
				XCTAssertEqual(notification, result)

				expectation.fulfill()
			}
		}

		let data = try JSONEncoder().encode(result)
		pair.continuation.yield(data)

		await fulfillment(of: [expectation], timeout: 1.0)
	}

	func testServerToClientResponseThenNotification() async throws {
		let expectedResponse = TestResponse(id: JSONId(1), result: nil)
		let expectedNotification = TestNotification(method: "note")

		let messages: [ScriptedMessage] = [
			.afterWrite(try JSONEncoder().encode(expectedResponse)),
			.immediate(try JSONEncoder().encode(expectedNotification))
		]

		let channel = await DataChannel.predefinedMessagesChannel(with: messages)
		let session = JSONRPCSession(channel: channel)

		let notificationExpectation = XCTestExpectation(description: "Notification Message")

		Task {
			for await notePair in await session.notificationSequence {
				let notification = try JSONDecoder().decode(TestNotification.self, from: notePair.1)
				XCTAssertEqual(notification, expectedNotification)

				notificationExpectation.fulfill()
			}
		}

		let response: TestResponse = try await session.sendRequest("hello", method: "myrequest")
		XCTAssertEqual(response, expectedResponse)

		await fulfillment(of: [notificationExpectation], timeout: 1.0)
	}

	func testNullResultResponse() async throws {
		let expectedResponse = TestResponse(id: 1, result: nil)

		let messages: [ScriptedMessage] = [
			.afterWrite(try JSONEncoder().encode(expectedResponse)),
		]

		let channel = await DataChannel.predefinedMessagesChannel(with: messages)
		let session = JSONRPCSession(channel: channel)

		let response: TestResponse = try await session.sendRequest("hello", method: "myrequest")

		XCTAssertNil(try response.content.get())
	}
}

#endif
