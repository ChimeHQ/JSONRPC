import XCTest
import JSONRPC

final class ProtocolTests: XCTestCase {
    func testResultResponse() throws {
        let string = """
{"jsonrpc":"2.0", "id": 1, "result": "hello"}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

        let expected = JSONRPCResponse<String>.result(1, "hello")

        XCTAssertEqual(response, expected)
    }

    func testErrorWithNoDataResponse() throws {
        let string = """
{"jsonrpc":"2.0", "id": 1, "error": {"code": 1, "message": "hello"}}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

        let error = AnyJSONRPCResponseError(code: 1, message: "hello", data: nil)
        let expected = JSONRPCResponse<String>.failure(1, error)
        
        XCTAssertEqual(response, expected)
    }

    func testErrorAndResultResponse() throws {
        let string = """
{"jsonrpc":"2.0", "id": 1, "result": "hello", "error": {"code": 1, "message": "hello"}}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))

        do {
            _ = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

            XCTFail()
        } catch {
        }
    }

    func testErrorAndNullResultResponse() throws {
        // against spec

        let string = """
{"jsonrpc":"2.0", "id": 1, "result": null, "error": {"code": 1, "message": "hello"}}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

        let error = AnyJSONRPCResponseError(code: 1, message: "hello", data: nil)
        let expected = JSONRPCResponse<String>.failure(1, error)

        XCTAssertEqual(response, expected)
    }

    func testResultAndNullErrorResponse() throws {
        // against spec
        let string = """
{"jsonrpc":"2.0", "id": 1, "result": "hello", "error": null}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

        let expected = JSONRPCResponse<String>.result(1, "hello")

        XCTAssertEqual(response, expected)
    }

    func testNullIdErrorResponse() throws {
        let string = """
{"jsonrpc":"2.0", "id": null, "error": {"code": 1, "message": "hello"}}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))

        do {
            _ = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

            XCTFail()
        } catch {
        }
    }

    func testResultNullAndNullErrorResponse() throws {
        // against spec
        let string = """
{"jsonrpc":"2.0", "id": 1, "result": null, "error": null}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))

        do {
            _ = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

            XCTFail()
        } catch {
        }
    }

    func testOptionalResultNullAndNullErrorResponse() throws {
        // against spec
        let string = """
{"jsonrpc":"2.0", "id": 1, "result": null, "error": null}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))
        let response = try JSONDecoder().decode(JSONRPCResponse<String?>.self, from: data)

        let expected = JSONRPCResponse<String?>.result(1, nil)

        XCTAssertEqual(response, expected)
    }

    func testNullIdAndResultResponse() throws {
        let string = """
{"jsonrpc":"2.0", "id": null, "result": "hello", "error": {"code": 1, "message": "hello"}}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))

        do {
            _ = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

            XCTFail()
        } catch {
        }
    }

    func testUnsupportedVersionResponse() throws {
        let string = """
{"jsonrpc":"1.0", "id": 1, "result": "hello"}
"""
        let data = try XCTUnwrap(string.data(using: .utf8))

        do {
            _ = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

            XCTFail()
        } catch {
        }
    }

    func testEncodeResponse() throws {
        let response = JSONRPCResponse<String>.result(1, "hello")

        let data = try JSONEncoder().encode(response)

        let decodedResponse = try JSONDecoder().decode(JSONRPCResponse<String>.self, from: data)

        XCTAssertEqual(decodedResponse, response)
    }
}
