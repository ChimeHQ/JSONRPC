import XCTest
import JSONRPC

final class ProtocolTransportTests: XCTestCase {
    typealias TestResponse = JSONRPCResponse<String?>
    typealias TestResult = Result<TestResponse, Error>

    func testSendRequest() throws {
        let dataTransport = MockDataTransport()
        let transport = ProtocolTransport(dataTransport: dataTransport)

        let expectation = XCTestExpectation(description: "Response Message")

        let params = "hello"
        transport.sendRequest(params, method: "mymethod") { (result: TestResult) in
            let value = try? result.get()
            XCTAssertEqual(value?.result, "goodbye")

            expectation.fulfill()
        }

        let response = TestResponse(id: JSONId(1), result: "goodbye")
        let responseData = try JSONEncoder().encode(response)

        dataTransport.mockRead(responseData)

        wait(for: [expectation], timeout: 1.0)
    }

    func testManySendRequestsWithResponsesDeliveredOnABackgroundQueueTest() throws {
        let dataTransport = MockDataTransport()
        let transport = ProtocolTransport(dataTransport: dataTransport)

        let iterations = 1000
        let expectation = XCTestExpectation(description: "Response Message")
        expectation.expectedFulfillmentCount = iterations

        let params = "hello"
        let queue = DispatchQueue(label: "SimulatedFileHandleQueue")

        // be sure to start at 1, to match ProtocolTransport's id generation
        for i in 1...iterations {
            let responseParam = "goodbye-\(i)"

            transport.sendRequest(params, method: "mymethod") { (result: TestResult) in
                let value = try? result.get()
                XCTAssertEqual(value?.result, responseParam)

                expectation.fulfill()
            }

            let response = TestResponse(id: JSONId(i), result: responseParam)
            let responseData = try JSONEncoder().encode(response)

            // this must happen asynchronously to match the behavior of NSFileHandle
            queue.async {
                dataTransport.mockRead(responseData)
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSendNotification() throws {
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

        XCTAssertEqual(dataTransport.writtenData, [resultData])
    }

	func testSendNotificationAsync() async throws {
		let dataTransport = MockDataTransport()
		let transport = ProtocolTransport(dataTransport: dataTransport)

		let params = "hello"

		try await transport.sendNotification(params, method: "mynotification")

		let result = JSONRPCNotification(method: "mynotification", params: params)
		let resultData = try JSONEncoder().encode(result)

		XCTAssertEqual(dataTransport.writtenData, [resultData])
	}

    func testServerToClientNotification() throws {
        let dataTransport = MockDataTransport()
        let transport = ProtocolTransport(dataTransport: dataTransport)

        let expectation = XCTestExpectation(description: "Notification Message")

		let notifHandler: ProtocolTransport.Handlers.NotificationHandler = { notification, data, callback in
            XCTAssertEqual(notification.method, "iamnotification")

            let result = try? JSONDecoder().decode(JSONRPCNotification<String>.self, from: data)

            XCTAssertEqual(result?.params, "iamstring")
            expectation.fulfill()

            callback(nil)
        }

		transport.setHandlers(.init(request: nil, notification: notifHandler, error: nil))

        let response = JSONRPCNotification<String>(method: "iamnotification", params: "iamstring")
        let responseData = try JSONEncoder().encode(response)

        dataTransport.mockRead(responseData)

        wait(for: [expectation], timeout: 1.0)
    }

    func testServerToClientResponseThenNotification() throws {
        let dataTransport = MockDataTransport()
        let transport = ProtocolTransport(dataTransport: dataTransport)

        let responseExpectation = XCTestExpectation(description: "Response Message")
        let notificationExpectation = XCTestExpectation(description: "Notification Message")

        let notifHandler: ProtocolTransport.Handlers.NotificationHandler = { notification, data, callback in
            self.wait(for: [responseExpectation], timeout: 1.0)
            notificationExpectation.fulfill()
            callback(nil)
        }

        transport.setHandlers(.init(request: nil, notification: notifHandler, error: nil))

        let params = "foo"
        transport.sendRequest(params, method: "bar") { (result: Result<TestResponse, Error>) in
            responseExpectation.fulfill()
        }

        let response = TestResponse(id: JSONId(1), result: nil)
        let responseData = try JSONEncoder().encode(response)
        dataTransport.mockRead(responseData)

        let notification = JSONRPCNotification<String>(method: "baz")
        let notificationData = try JSONEncoder().encode(notification)
        dataTransport.mockRead(notificationData)

        wait(for: [notificationExpectation], timeout: 1.0)
    }

    func testNullResultResponse() throws {
        let dataTransport = MockDataTransport()
        let transport = ProtocolTransport(dataTransport: dataTransport)

        let expectation = XCTestExpectation(description: "Response Message")

        let params = "hello"
        transport.sendRequest(params, method: "mymethod") { (result: Result<TestResponse, Error>) in
            guard let response = try? result.get() else {
                XCTFail()
                return
            }

            switch response {
            case .result(_, let value):
                XCTAssertNil(value)
            case .failure:
                XCTFail()
            }

            expectation.fulfill()
        }

        let response = TestResponse(id: JSONId(1), result: nil)
        let responseData = try JSONEncoder().encode(response)

        dataTransport.mockRead(responseData)

        wait(for: [expectation], timeout: 1.0)
    }

    func testDeallocInvokesAbandondedHandlers() {
        let expectation = XCTestExpectation(description: "Response Message")

        DispatchQueue.global().async {
            let dataTransport = MockDataTransport()
            let transport = ProtocolTransport(dataTransport: dataTransport)

            let params = "hello"
            transport.sendRequest(params, method: "mymethod") { (result: Result<TestResponse, Error>) in
                switch result {
                case .success:
                    XCTFail()
                case .failure(let error):
                    print("failed with \(error)")

                    expectation.fulfill()
                }
            }

        }

        wait(for: [expectation], timeout: 1.0)
    }
}
