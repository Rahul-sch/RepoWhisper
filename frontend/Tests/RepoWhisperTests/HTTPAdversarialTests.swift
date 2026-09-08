import XCTest
@testable import RepoWhisper

final class HTTPAdversarialTests: XCTestCase {
    private let client = UnixSocketHTTPClient(socketPath: "/unused")

    func testRejectsNegativeLength() {
        XCTAssertThrowsError(try client.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nContent-Length: -1\r\n\r\nx".utf8)))
    }

    func testRejectsAmbiguousFraming() {
        XCTAssertThrowsError(try client.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n0\r\n\r\n".utf8)))
    }

    func testRejectsDuplicateLength() {
        XCTAssertThrowsError(try client.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Length: 1\r\n\r\nx".utf8)))
    }

    func testRejectsInvalidProtocol() {
        XCTAssertThrowsError(try client.parseHTTPResponse(Data("BOGUS 200 OK\r\n\r\n".utf8)))
    }

    func testRejectsSignedChunk() {
        XCTAssertThrowsError(try client.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n-1\r\nx\r\n".utf8)))
    }

    func testRejectsOverflowingChunk() {
        XCTAssertThrowsError(try client.parseHTTPResponse(Data("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n7fffffffffffffff\r\nx\r\n".utf8)))
    }
}
