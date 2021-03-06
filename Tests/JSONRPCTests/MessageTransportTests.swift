import XCTest
import JSONRPC

final class MessageTransportTests: XCTestCase {
    func writeMessageAndReadResult(_ message: String) -> Data? {
        let results = writeMessagesAndReadResult([message])

        guard results.count == 1 else {
            return nil
        }

        return results[0]
    }

    func writeMessagesAndReadResult(_ messages: [String], resultCount: Int = 1) -> [Data] {
        let dataTransport = MockDataTransport()

        let transport = MessageTransport(dataTransport: dataTransport,
                                         messageProtocol: SeperatedHTTPHeaderMessageFraming())

        var receivedData: [Data] = []

        let exp = XCTestExpectation(description: "Message Content")
        exp.expectedFulfillmentCount = resultCount

        transport.dataHandler = { (data) in
            receivedData.append(data)

            exp.fulfill()
        }

        for message in messages {
            dataTransport.mockRead(message)
        }

        wait(for: [exp], timeout: 1.0)

        return receivedData
    }

    func testBasicMessageDecode() {
        let content = "{\"jsonrpc\":\"2.0\",\"params\":\"Something\"}"
        let message = "Content-Length: 38\r\n\r\n\(content)"

        let data = writeMessageAndReadResult(message)

        XCTAssertEqual(data, content.data(using: .utf8)!)
    }

    func testMultiHeaderMessage() {
        let content = "{\"jsonrpc\":\"2.0\",\"params\":\"Something\"}"
        let header1 = "Content-Length: 38\r\n"
        let header2 = "Another-Header: Something\r\n"
        let header3 = "And-Another: third\r\n"
        let message = header1 + header2 + header3 + "\r\n" + content

        let data = writeMessageAndReadResult(message)

        XCTAssertEqual(data, content.data(using: .utf8)!)
    }

    func testMultiReadMessage() {
        let messages = [
            "Content-Le",
            "ngth: 30\r\n",
            "Header2: h",
            "llo\r\n\r\n",
            "abcdefghij",
            "klmnopqurs",
            "tuvwxyz123"
        ]

        let content = "abcdefghijklmnopqurstuvwxyz123"

        let results = writeMessagesAndReadResult(messages)

        if results.count != 1 {
            XCTFail()
            return
        }

        XCTAssertEqual(results[0], content.data(using: .utf8)!)
    }

    func testMultiReadMessageWithSecondMessageInARead() {
        let messages = [
            "Content-Length: 6\r\n",
            "Another-Header: hello\r\n\r\n",
            "abcdefContent-Length: 10\r\n",
            "\r\nabcdefghij",
        ]

        let results = writeMessagesAndReadResult(messages, resultCount: 2)

        if results.count != 2 {
            XCTFail()
            return
        }

        XCTAssertEqual(results[0], "abcdef".data(using: .utf8)!)
        XCTAssertEqual(results[1], "abcdefghij".data(using: .utf8)!)
    }

    func testDecodeMessagePerformance() {
        let dataTransport = MockDataTransport()

        let transport = MessageTransport(dataTransport: dataTransport,
                                         messageProtocol: SeperatedHTTPHeaderMessageFraming())

        var receiveCount: Int = 0

        transport.dataHandler = { (data) in
            receiveCount += 1
        }

        let content = "{\"jsonrpc\":\"2.0\",\"params\":\"Something\"}"
        let message = "Content-Length: 38\r\n\r\n\(content)"

        measure {
            for _ in 0..<1000 {
                dataTransport.mockRead(message)
            }
        }

        XCTAssert(receiveCount >= 1000)
    }

    func testTwoFullMessagesInOneRead() {
        let messages = [
            "Content-Length: 6\r\n\r\nabcdefContent-Length: 10\r\n\r\nabcdefghij"
        ]

        let results = writeMessagesAndReadResult(messages, resultCount: 2)

        if results.count != 2 {
            XCTFail()
            return
        }

        XCTAssertEqual(results[0], "abcdef".data(using: .utf8)!)
        XCTAssertEqual(results[1], "abcdefghij".data(using: .utf8)!)
    }
}
