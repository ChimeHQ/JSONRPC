import XCTest
import JSONRPC

final class SeperatedHTTPHeaderMessageFramingTests: XCTestCase {
    func testBasicMessageDecode() throws {
        let content = "hello"
        let message = "Content-Length: 5\r\n" + "\r\n" + content
        let data = try XCTUnwrap(message.data(using: .utf8))

        let headerProtocol = SeperatedHTTPHeaderMessageFraming()

        let range = try XCTUnwrap(headerProtocol.nextMessageRange(in: data))
        let start = data.count - 5

        XCTAssertEqual(range, start..<data.count)
    }

    func testMultiHeaderMessage() throws {
        let content = "hello"
        let header1 = "Content-Length: 5\r\n"
        let header2 = "Another-Header: Something\r\n"
        let header3 = "And-Another: third\r\n"
        let message = header1 + header2 + header3 + "\r\n" + content
        let data = try XCTUnwrap(message.data(using: .utf8))

        let headerProtocol = SeperatedHTTPHeaderMessageFraming()

        let range = try XCTUnwrap(headerProtocol.nextMessageRange(in: data))
        let start = data.count - 5

        XCTAssertEqual(range, start..<data.count)
    }

    func testUnfinishedMessage() throws {
        let content = "hell"
        let message = "Content-Length: 5\r\n" + "\r\n" + content
        let data = try XCTUnwrap(message.data(using: .utf8))

        let headerProtocol = SeperatedHTTPHeaderMessageFraming()

        XCTAssertNil(headerProtocol.nextMessageRange(in: data))
    }

    func testEncodeData() throws {
        let content = "hello"
        let data = try XCTUnwrap(content.data(using: .utf8))
        let headerProtocol = SeperatedHTTPHeaderMessageFraming()

        let messageData = headerProtocol.frameData(data)

        let string = try XCTUnwrap(String(data: messageData, encoding: .utf8))

        XCTAssertEqual(string, "Content-Length: 5\r\n\r\nhello")
    }
}
