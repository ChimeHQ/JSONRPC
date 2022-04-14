import XCTest
import JSONRPC

final class LengthPrefixMessageFramingTests: XCTestCase {
    func testBasicMessageDecode() throws {
        let content = "hello"
        let message = "00000005\n" + content + "\n"
        let data = try XCTUnwrap(message.data(using: .utf8))

        let headerProtocol = LengthPrefixMessageFraming()

        let range = try XCTUnwrap(headerProtocol.nextMessageRange(in: data))
        let start = data.count - 6

        XCTAssertEqual(range, start..<data.count)
    }

    func testUnfinishedMessage() throws {
        let content = "hell"
        let message = "00000005\n" + content
        let data = try XCTUnwrap(message.data(using: .utf8))

        let headerProtocol = LengthPrefixMessageFraming()

        XCTAssertNil(headerProtocol.nextMessageRange(in: data))
    }

    func testEncodeData() throws {
        let content = "hello"
        let data = try XCTUnwrap(content.data(using: .utf8))
        let headerProtocol = LengthPrefixMessageFraming()

        let messageData = headerProtocol.frameData(data)

        let string = try XCTUnwrap(String(data: messageData, encoding: .utf8))

        XCTAssertEqual(string, "00000005\nhello\n")
    }

}
