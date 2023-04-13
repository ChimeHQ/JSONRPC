import XCTest
import JSONRPC

final class JSONValueDecoderTests: XCTestCase {
    struct SimpleStruct: Decodable, Equatable {
        var bool: Bool?
        var string: String?
        var double: Double?
        var float: Float?
        var int: Int?
        var int8: Int8?
        var int16: Int16?
        var int32: Int32?
        var int64: Int64?
        var uint: UInt?
        var uint8: UInt8?
        var uint16: UInt16?
        var uint32: UInt32?
        var uint64: UInt64?

        var any: JSONValue?
        var intArray: [Int]?

        var nested: [SimpleStruct]?
    }

    func testDecode() throws {
        XCTAssertEqual(
            try JSONValueDecoder().decode(
                SimpleStruct.self,
                from: [
                    "bool": true,
                    "string": "foo",
                    "double": 101,
                    "float": 102,
                    "int": 103,
                    "int8": 104,
                    "int16": 105,
                    "int32": 106,
                    "int64": 107,
                    "uint": 108,
                    "uint8": 109,
                    "uint16": 110,
                    "uint32": 111,
                    "uint64": 112,

                    "any": "bar",
                    "intArray": [11, 22, 33],

                    "nested": [["int": 11], ["int": 22]]
                ]
            ),
            SimpleStruct(
                bool: true,
                string: "foo",
                double: 101,
                float: 102,
                int: 103,
                int8: 104,
                int16: 105,
                int32: 106,
                int64: 107,
                uint: 108,
                uint8: 109,
                uint16: 110,
                uint32: 111,
                uint64: 112,

                any: JSONValue.string("bar"),
                intArray: [11, 22, 33],
                nested: [SimpleStruct(int: 11), SimpleStruct(int: 22)]
            )
        )
    }

    func testDecodeUnkeyedErrorPath() throws {
        XCTAssertThrowsError(
            try JSONValueDecoder().decode(
                SimpleStruct.self,
                from: JSONValue.hash(["intArray": .array([.number(0),
                                                          .number(1),
                                                          .bool(false)])])
            )
        ) { error in
            guard case let DecodingError.typeMismatch(_, context) = error else {
                XCTFail("Expected typeError")
                return
            }
            XCTAssertEqual(
                context.codingPath.count,
                2
            )
            XCTAssertEqual(
                context.codingPath[0].stringValue,
                "intArray"
            )
            XCTAssertEqual(
                context.codingPath[1].intValue,
                2
            )
        }
    }

    func testDecodeNotDouble() throws {
        XCTAssertThrowsError(
            try JSONValueDecoder().decode(
                SimpleStruct.self,
                from: JSONValue.hash(["double": "string"])
            )
        ) { error in
        	#if os(Linux)
                        XCTAssertEqual(
		            error.localizedDescription,
		            "The operation could not be completed. The data isn’t in the correct format."
		        )
        	#else
		        XCTAssertEqual(
		            error.localizedDescription,
		            "The data couldn’t be read because it isn’t in the correct format."
		        )
            #endif
        }
    }

    func testDecodeOverflow() throws {
        XCTAssertThrowsError(
            try JSONValueDecoder().decode(
                SimpleStruct.self,
                from: JSONValue.hash(["int8": 300])
            )
        ) { error in
        	#if os(Linux)
                        XCTAssertEqual(
		            error.localizedDescription,
		            "The operation could not be completed. The data isn’t in the correct format."
		        )
        	#else
		        XCTAssertEqual(
		            error.localizedDescription,
		            "The data couldn’t be read because it isn’t in the correct format."
		        )
            #endif
        }
    }

    func testDecodeFloatOverflow() throws {
        XCTAssertThrowsError(
            try JSONValueDecoder().decode(
                SimpleStruct.self,
                from: JSONValue.hash(["float": 1e300])
            )
        ) { error in
        	#if os(Linux)
                        XCTAssertEqual(
		            error.localizedDescription,
		            "The operation could not be completed. The data isn’t in the correct format."
		        )
        	#else
		        XCTAssertEqual(
		            error.localizedDescription,
		            "The data couldn’t be read because it isn’t in the correct format."
		        )
            #endif
        }
    }
}
