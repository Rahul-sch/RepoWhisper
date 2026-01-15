//
//  UnixSocketHTTPClient.swift
//  RepoWhisper
//
//  HTTP/1.1 client over Unix Domain Socket for backend communication.
//

import Foundation

/// Simple HTTP client that communicates over Unix Domain Socket
class UnixSocketHTTPClient {
    private let socketPath: String
    private let timeout: TimeInterval

    init(socketPath: String, timeout: TimeInterval = 10.0) {
        self.socketPath = socketPath
        self.timeout = timeout
    }

    /// Perform a GET request over Unix socket
    func get(path: String, headers: [String: String] = [:]) throws -> HTTPResponse {
        return try request(method: "GET", path: path, headers: headers, body: nil)
    }

    /// Perform a POST request over Unix socket
    func post(path: String, headers: [String: String] = [:], body: Data? = nil) throws -> HTTPResponse {
        return try request(method: "POST", path: path, headers: headers, body: body)
    }

    /// Perform an HTTP request over Unix socket
    private func request(method: String, path: String, headers: [String: String], body: Data?) throws -> HTTPResponse {
        // Create Unix domain socket
        let sock = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sock >= 0 else {
            throw HTTPError.socketCreationFailed
        }
        defer { close(sock) }

        // Set timeout
        var tv = timeval()
        tv.tv_sec = Int(timeout)
        tv.tv_usec = Int32((timeout.truncatingRemainder(dividingBy: 1)) * 1_000_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Connect to socket
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let pathCString = socketPath.utf8CString
        guard pathCString.count <= MemoryLayout.size(ofValue: addr.sun_path) else {
            throw HTTPError.socketPathTooLong
        }

        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            for (index, char) in pathCString.enumerated() {
                ptr[index] = Int8(char)
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                Darwin.connect(sock, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult >= 0 else {
            throw HTTPError.connectionFailed
        }

        // Build HTTP request
        var request = "\(method) \(path) HTTP/1.1\r\n"
        request += "Host: localhost\r\n"
        request += "Connection: close\r\n"

        // Add custom headers
        for (key, value) in headers {
            request += "\(key): \(value)\r\n"
        }

        // Add body if present
        if let body = body {
            request += "Content-Length: \(body.count)\r\n"
        }

        request += "\r\n"

        // Send request
        var requestData = request.data(using: .utf8)!
        if let body = body {
            requestData.append(body)
        }

        let sentBytes = requestData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in
            return send(sock, ptr.baseAddress, requestData.count, 0)
        }

        guard sentBytes > 0 else {
            throw HTTPError.sendFailed
        }

        // Read response
        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)

        while true {
            let bytesRead = recv(sock, &buffer, buffer.count, 0)
            if bytesRead <= 0 {
                break
            }
            responseData.append(contentsOf: buffer[0..<bytesRead])
        }

        guard !responseData.isEmpty else {
            throw HTTPError.emptyResponse
        }

        // Parse HTTP response
        return try parseHTTPResponse(responseData)
    }

    /// Parse HTTP/1.1 response
    private func parseHTTPResponse(_ data: Data) throws -> HTTPResponse {
        guard let responseString = String(data: data, encoding: .utf8) else {
            throw HTTPError.invalidResponse
        }

        // Split headers and body
        let parts = responseString.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 1 else {
            throw HTTPError.invalidResponse
        }

        let headerSection = parts[0]
        let bodySection = parts.count > 1 ? parts[1...].joined(separator: "\r\n\r\n") : ""

        // Parse status line
        let lines = headerSection.components(separatedBy: "\r\n")
        guard let statusLine = lines.first else {
            throw HTTPError.invalidResponse
        }

        let statusParts = statusLine.components(separatedBy: " ")
        guard statusParts.count >= 2,
              let statusCode = Int(statusParts[1]) else {
            throw HTTPError.invalidResponse
        }

        // Parse headers
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let headerParts = line.components(separatedBy: ": ")
            if headerParts.count >= 2 {
                let key = headerParts[0]
                let value = headerParts[1...].joined(separator: ": ")
                headers[key] = value
            }
        }

        // Body as Data
        let bodyData = bodySection.data(using: .utf8) ?? Data()

        return HTTPResponse(statusCode: statusCode, headers: headers, body: bodyData)
    }
}

// MARK: - Models

struct HTTPResponse {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    var bodyString: String? {
        return String(data: body, encoding: .utf8)
    }
}

enum HTTPError: Error, LocalizedError {
    case socketCreationFailed
    case socketPathTooLong
    case connectionFailed
    case sendFailed
    case emptyResponse
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .socketCreationFailed:
            return "Failed to create socket"
        case .socketPathTooLong:
            return "Socket path too long"
        case .connectionFailed:
            return "Failed to connect to socket"
        case .sendFailed:
            return "Failed to send request"
        case .emptyResponse:
            return "Received empty response"
        case .invalidResponse:
            return "Invalid HTTP response"
        }
    }
}
