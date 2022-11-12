import XCTest
import JSONRPC

final class JSONValueTests: XCTestCase {
	func testNullEncoding() throws {
		let obj = JSONValue.null

		let data = try JSONEncoder().encode(obj)
		let string = try XCTUnwrap(String(data: data, encoding: .utf8))

		XCTAssertEqual(string, "null")
	}

	func testBoolEncoding() throws {
		let obj = JSONValue.bool(true)

		let data = try JSONEncoder().encode(obj)
		let string = try XCTUnwrap(String(data: data, encoding: .utf8))

		XCTAssertEqual(string, "true")
	}

	func testIntEncoding() throws {
		let obj = JSONValue.number(45)

		let data = try JSONEncoder().encode(obj)
		let string = try XCTUnwrap(String(data: data, encoding: .utf8))

		XCTAssertEqual(string, "45")
	}

	func testArrayEncoding() throws {
		let obj = JSONValue.array([1,2,3])

		let data = try JSONEncoder().encode(obj)
		let string = try XCTUnwrap(String(data: data, encoding: .utf8))

		XCTAssertEqual(string, "[1,2,3]")
	}

	func testNullInDictionary() throws {
		let obj = JSONValue.hash(["abc": nil])

		let data = try JSONEncoder().encode(obj)
		let string = try XCTUnwrap(String(data: data, encoding: .utf8))

		XCTAssertEqual(string, "{\"abc\":null}")
	}

	func testDecoding() throws {
		let string = """
{
	"string": "abc",
	"bool": true,
	"null": null,
	"int": 145,
	"double": 145.0,
	"array": [1,2,3]
}
"""
		let value = try JSONDecoder().decode(JSONValue.self, from: string.data(using: .utf8)!)

		let expected: JSONValue = [
			"string": "abc",
			"bool": true,
			"null": nil,
			"int": 145,
			"double": 145.0,
			"array": [1,2,3]
		]
		XCTAssertEqual(value, expected)
	}
}
