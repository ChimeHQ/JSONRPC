import XCTest
@testable import JSONRPC

class JSONIdTests: XCTestCase {
    func testNumericEncode() throws {
        let obj = JSONId(1)

        let data = try JSONEncoder().encode(obj)

        XCTAssertEqual(data, "1".data(using: .utf8)!)
    }

    func testStringEncode() throws {
        let obj = JSONId("1")

        let data = try JSONEncoder().encode(obj)

        XCTAssertEqual(data, "\"1\"".data(using: .utf8)!)
    }
}
