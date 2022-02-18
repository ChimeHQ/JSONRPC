//
//  ProtocolTransportTests.swift
//  JSONRPCTests
//
//  Created by Matthew Massicotte on 2021-07-19.
//

import XCTest
import JSONRPC

class ProtocolTransportTests: XCTestCase {
    typealias TestResponse = JSONRPCResponse<String>
    typealias TestResult = Result<TestResponse, Error>

    func testSendRequest() throws {
        let dataTransport = MockDataTransport()
        let messageTransport = MessageTransport(dataTransport: dataTransport)
        let transport = ProtocolTransport(messageTransport: messageTransport)

        let expectation = XCTestExpectation(description: "Response Message")

        let params = "hello"
        transport.sendRequest(params, method: "mymethod") { (result: TestResult) in
            let value = try? result.get()
            XCTAssertEqual(value?.result, "goodbye")

            expectation.fulfill()
        }

        let response = TestResponse(id: JSONId(1), result: "goodbye")
        let responseData = try MessageTransport.encode(response)

        dataTransport.mockRead(responseData)

        wait(for: [expectation], timeout: 1.0)
    }

    func testManySendRequestsWithResponsesDeliveredOnABackgroundQueueTest() throws {
        let dataTransport = MockDataTransport()
        let messageTransport = MessageTransport(dataTransport: dataTransport)
        let transport = ProtocolTransport(messageTransport: messageTransport)

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
            let responseData = try MessageTransport.encode(response)

            // this must happen asynchronously to match the behavior of NSFileHandle
            queue.async {
                dataTransport.mockRead(responseData)
            }
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSendNotification() throws {
        let dataTransport = MockDataTransport()
        let messageTransport = MessageTransport(dataTransport: dataTransport)
        let transport = ProtocolTransport(messageTransport: messageTransport)

        let expectation = XCTestExpectation(description: "Notification Message")

        let params = "hello"

        transport.sendNotification(params, method: "mynotification") { (error) in
            XCTAssertNil(error)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)

        let result = JSONRPCNotification(method: "mynotification", params: params)
        let resultData = try MessageTransport.encode(result)

        XCTAssertEqual(dataTransport.writtenData, [resultData])
    }

    func testServerToClientNotification() throws {
        let dataTransport = MockDataTransport()
        let messageTransport = MessageTransport(dataTransport: dataTransport)
        let transport = ProtocolTransport(messageTransport: messageTransport)

        let expectation = XCTestExpectation(description: "Notification Message")

        transport.notificationHandler = { notification, data, callback in
            XCTAssertEqual(notification.method, "iamnotification")

            let result = try? JSONDecoder().decode(JSONRPCNotification<String>.self, from: data)

            XCTAssertEqual(result?.params, "iamstring")
            expectation.fulfill()

            callback(nil)
        }

        let response = JSONRPCNotification<String>(method: "iamnotification", params: "iamstring")
        let responseData = try MessageTransport.encode(response)

        dataTransport.mockRead(responseData)

        wait(for: [expectation], timeout: 1.0)
    }

    func testNullResultResponse() throws {
        let dataTransport = MockDataTransport()
        let messageTransport = MessageTransport(dataTransport: dataTransport)
        let transport = ProtocolTransport(messageTransport: messageTransport)

        let expectation = XCTestExpectation(description: "Response Message")

        let params = "hello"
        transport.sendRequest(params, method: "mymethod") { (result: Result<TestResponse, Error>) in
            guard let response = try? result.get() else {
                XCTFail()
                return
            }

            XCTAssertNil(response.result)

            expectation.fulfill()
        }

        let response = TestResponse(id: JSONId(1), result: nil)
        let responseData = try MessageTransport.encode(response)

        dataTransport.mockRead(responseData)

        wait(for: [expectation], timeout: 1.0)
    }

    func testDeallocInvokesAbandondedHandlers() {
        let expectation = XCTestExpectation(description: "Response Message")

        DispatchQueue.global().async {
            let dataTransport = MockDataTransport()
            let messageTransport = MessageTransport(dataTransport: dataTransport)
            let transport = ProtocolTransport(messageTransport: messageTransport)

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
