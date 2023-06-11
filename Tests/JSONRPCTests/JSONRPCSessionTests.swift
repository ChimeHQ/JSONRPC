import XCTest
import JSONRPC

#if compiler(>=5.9)

final class JSONRPCSessionTests: XCTestCase {
	typealias TestResponse = JSONRPCResponse<String?>
	typealias TestResult = Result<TestResponse, Error>

	func testThing() async throws {
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
}

#endif
