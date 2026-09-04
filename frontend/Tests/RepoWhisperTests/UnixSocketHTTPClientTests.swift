import XCTest
@testable import RepoWhisper

final class UnixSocketHTTPClientTests: XCTestCase {
    private let client = UnixSocketHTTPClient(socketPath: "/tmp/test.sock")

    func testParsesContentLengthAndPreservesBinaryBody() throws {
        var response = Data("HTTP/1.1 200 OK\r\nContent-Length: 3\r\nX-Test: yes\r\n\r\n".utf8)
        response.append(contentsOf: [0xff, 0x00, 0x7f])

        let parsed = try client.parseHTTPResponse(response)

        XCTAssertEqual(parsed.statusCode, 200)
        XCTAssertEqual(parsed.headers["x-test"], "yes")
        XCTAssertEqual(parsed.body, Data([0xff, 0x00, 0x7f]))
    }

    func testParsesChunkedResponse() throws {
        let response = Data(
            "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n4\r\nWiki\r\n5\r\npedia\r\n0\r\n\r\n".utf8
        )

        let parsed = try client.parseHTTPResponse(response)

        XCTAssertEqual(parsed.bodyString, "Wikipedia")
    }

    func testRejectsTruncatedContentLength() {
        let response = Data("HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nabc".utf8)
        XCTAssertThrowsError(try client.parseHTTPResponse(response)) { error in
            guard case HTTPError.incompleteResponse = error else {
                return XCTFail("Expected incompleteResponse, got \(error)")
            }
        }
    }

    func testRejectsMalformedStatusLine() {
        let response = Data("not-http\r\n\r\n".utf8)
        XCTAssertThrowsError(try client.parseHTTPResponse(response))
    }
}
