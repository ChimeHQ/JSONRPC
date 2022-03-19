import XCTest
@testable import JSONRPC

final class JSONIdTests: XCTestCase {
    func testNumericEncode() throws {
        let obj = JSONId(1)

        let data = try JSONEncoder().encode(obj)

        XCTAssertEqual(data, "1".data(using: .utf8)!)
    }

    func testIntegerLiteral() throws {
        let obj: JSONId = 1

        XCTAssertEqual(obj, JSONId.numericId(1))
    }

    func testStringEncode() throws {
        let obj = JSONId("1")

        let data = try JSONEncoder().encode(obj)

        XCTAssertEqual(data, "\"1\"".data(using: .utf8)!)
    }

    func testStringLiteral() throws {
        let obj: JSONId = "1"

        XCTAssertEqual(obj, JSONId.stringId("1"))
    }
}
