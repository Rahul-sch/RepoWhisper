//
//  APIClient.swift
//  RepoWhisper
//
//  HTTP client for the local Python backend.
//  Talks over the Unix Domain Socket spawned by BackendProcessManager,
//  authenticated with the per-install X-Auth-Token.
//

import Foundation

/// API client for the RepoWhisper backend
@MainActor
class APIClient: ObservableObject {
    /// Shared singleton instance
    static let shared = APIClient()

    /// Backend is reachable
    @Published var isConnected: Bool = false

    /// Faster-Whisper is installed on the backend (transcription possible)
    @Published var whisperAvailable: Bool = false

    /// Models (whisper + embedding) are warmed up — first transcribe/search
    /// won't stall for 30-60s downloading.
    @Published var modelsReady: Bool = false

    /// A warmup is currently in flight.
    @Published var modelsLoading: Bool = false

    /// Number of indexed chunks
    @Published var indexCount: Int = 0

    /// Last error message
    @Published var errorMessage: String?

    /// Per-request socket timeout (seconds). Indexing and transcription
    /// may take longer than search, so callers can override.
    private let defaultTimeout: TimeInterval = 30.0

    private init() {}

    // MARK: - Transport

    /// Run a synchronous UDS request off the main actor.
    private func send(
        method: String,
        path: String,
        body: Data? = nil,
        contentType: String? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> HTTPResponse {
        let socketPath = BackendProcessManager.shared.socketPath
        let token = try BackendProcessManager.shared.currentAuthToken()
        let resolvedTimeout = timeout ?? defaultTimeout

        return try await Task.detached(priority: .userInitiated) {
            let client = UnixSocketHTTPClient(socketPath: socketPath, timeout: resolvedTimeout)
            var headers: [String: String] = ["X-Auth-Token": token]
            if let contentType {
                headers["Content-Type"] = contentType
            }
            switch method {
            case "GET":
                return try client.get(path: path, headers: headers)
            case "POST":
                return try client.post(path: path, headers: headers, body: body)
            default:
                throw APIError.requestFailed
            }
        }.value
    }

    /// Decode a JSON body or throw a meaningful error.
    private func decode<T: Decodable>(_ type: T.Type, from response: HTTPResponse) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: response.body)
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Map non-200 responses to the appropriate APIError.
    private func mapError(_ response: HTTPResponse) -> APIError {
        switch response.statusCode {
        case 401: return .notAuthenticated
        case 503:
            // /transcribe returns 503 when faster-whisper is missing.
            if let detail = response.bodyString, detail.contains("faster-whisper") {
                return .whisperUnavailable
            }
            return .requestFailed
        default: return .requestFailed
        }
    }

    // MARK: - Health Check

    /// Check if backend is reachable
    func checkHealth() async {
        do {
            // /health is unauthenticated server-side, but we still send the
            // header so it works either way.
            let response = try await send(method: "GET", path: "/health", timeout: 5.0)
            guard response.statusCode == 200 else {
                isConnected = false
                whisperAvailable = false
                errorMessage = "Backend returned status \(response.statusCode)"
                return
            }
            let decoded = try decode(HealthResponse.self, from: response)
            isConnected = decoded.status == "healthy"
            whisperAvailable = decoded.whisperAvailable ?? false
            indexCount = decoded.indexCount
            errorMessage = nil
        } catch {
            isConnected = false
            whisperAvailable = false
            errorMessage = "Backend not reachable"
        }
    }

    // MARK: - Warmup

    /// Eagerly load the backend's Whisper + embedding models. Safe to call
    /// repeatedly — backend lru_caches both. The first call after launch
    /// can take 30-60s if models are downloading from HuggingFace.
    func warmup() async {
        guard !modelsReady, !modelsLoading else { return }
        modelsLoading = true
        defer { modelsLoading = false }

        do {
            // Generous timeout: model download from HuggingFace can take a while
            // on a slow connection, especially the first time.
            let response = try await send(method: "POST", path: "/warmup", timeout: 180.0)
            guard response.statusCode == 200 else { return }
            let decoded = try decode(WarmupResponse.self, from: response)
            // Embedding model is required for search to work at all.
            // Whisper model is required for transcription, but optional overall.
            modelsReady = decoded.embeddingLoaded
        } catch {
            print("⚠️ [API] Warmup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Transcription

    /// Transcribe raw PCM audio data
    /// - Parameter audioData: Raw PCM audio (16kHz, mono, 16-bit)
    /// - Returns: Transcription result
    func transcribe(audioData: Data) async throws -> TranscriptionResult {
        let response = try await send(
            method: "POST",
            path: "/transcribe",
            body: audioData,
            contentType: "application/octet-stream",
            timeout: 60.0
        )
        guard response.statusCode == 200 else {
            throw mapError(response)
        }
        return try decode(TranscriptionResult.self, from: response)
    }

    // MARK: - Search

    /// Search indexed code
    /// - Parameters:
    ///   - query: Search query text
    ///   - topK: Number of results to return
    ///   - repoId: Optional repository UUID to scope the search
    /// - Returns: Search results
    func search(query: String, topK: Int = 5, repoId: String? = nil) async throws -> SearchResponse {
        let body = try JSONEncoder().encode(SearchRequest(query: query, topK: topK, repoId: repoId))
        let response = try await send(
            method: "POST",
            path: "/search",
            body: body,
            contentType: "application/json",
            timeout: 10.0
        )
        guard response.statusCode == 200 else {
            throw mapError(response)
        }
        return try decode(SearchResponse.self, from: response)
    }

    // MARK: - Indexing

    /// Index a repository
    func indexRepository(
        repoPath: String,
        mode: IndexMode,
        filePaths: [String]? = nil,
        patterns: [String]? = nil
    ) async throws -> IndexResponse {
        let body = try JSONEncoder().encode(
            IndexRequest(mode: mode, repoPath: repoPath, filePaths: filePaths, patterns: patterns)
        )
        // Indexing a large repo can take a while — give it room.
        let response = try await send(
            method: "POST",
            path: "/index",
            body: body,
            contentType: "application/json",
            timeout: 600.0
        )
        guard response.statusCode == 200 else {
            throw mapError(response)
        }
        let indexResponse = try decode(IndexResponse.self, from: response)
        indexCount = indexResponse.chunksCreated
        return indexResponse
    }

    // MARK: - Boss Mode

    /// Get advice/talking point from transcript, screenshot, and code
    func getAdvice(
        transcript: String,
        screenshotBase64: String? = nil,
        codeSnippets: [String]? = nil,
        meetingContext: String? = nil
    ) async throws -> AdviseResponse {
        let body = try JSONEncoder().encode(
            AdviseRequest(
                transcript: transcript,
                screenshotBase64: screenshotBase64,
                codeSnippets: codeSnippets,
                meetingContext: meetingContext
            )
        )
        let response = try await send(
            method: "POST",
            path: "/advise",
            body: body,
            contentType: "application/json",
            timeout: 30.0
        )
        guard response.statusCode == 200 else {
            throw mapError(response)
        }
        return try decode(AdviseResponse.self, from: response)
    }

    /// Upload screenshot for processing
    func uploadScreenshot(_ screenshotData: Data) async throws -> ScreenshotResponse {
        let response = try await send(
            method: "POST",
            path: "/screenshot",
            body: screenshotData,
            contentType: "image/jpeg",
            timeout: 30.0
        )
        guard response.statusCode == 200 else {
            throw mapError(response)
        }
        return try decode(ScreenshotResponse.self, from: response)
    }
}

// MARK: - API Models

struct HealthResponse: Codable {
    let status: String
    let modelLoaded: Bool
    let whisperAvailable: Bool?
    let indexCount: Int
    let version: String

    enum CodingKeys: String, CodingKey {
        case status
        case modelLoaded = "model_loaded"
        case whisperAvailable = "whisper_available"
        case indexCount = "index_count"
        case version
    }
}

struct WarmupResponse: Codable {
    let whisperLoaded: Bool
    let embeddingLoaded: Bool
    let elapsedMs: Double

    enum CodingKeys: String, CodingKey {
        case whisperLoaded = "whisper_loaded"
        case embeddingLoaded = "embedding_loaded"
        case elapsedMs = "elapsed_ms"
    }
}

struct TranscriptionResult: Codable {
    let text: String
    let confidence: Double
    let latencyMs: Double

    enum CodingKeys: String, CodingKey {
        case text
        case confidence
        case latencyMs = "latency_ms"
    }
}

struct SearchRequest: Codable {
    let query: String
    let topK: Int
    let repoId: String?

    enum CodingKeys: String, CodingKey {
        case query
        case topK = "top_k"
        case repoId = "repo_id"
    }
}

struct SearchResponse: Codable {
    let results: [SearchResultItem]
    let query: String
    let latencyMs: Double

    enum CodingKeys: String, CodingKey {
        case results
        case query
        case latencyMs = "latency_ms"
    }
}

struct SearchResultItem: Codable, Identifiable {
    let filePath: String
    let chunk: String
    let score: Double
    let lineStart: Int
    let lineEnd: Int

    var id: String { "\(filePath):\(lineStart)" }

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case chunk
        case score
        case lineStart = "line_start"
        case lineEnd = "line_end"
    }
}

struct IndexRequest: Codable {
    let mode: IndexMode
    let repoPath: String
    let filePaths: [String]?
    let patterns: [String]?

    enum CodingKeys: String, CodingKey {
        case mode
        case repoPath = "repo_path"
        case filePaths = "file_paths"
        case patterns
    }
}

struct IndexResponse: Codable {
    let success: Bool
    let filesIndexed: Int
    let chunksCreated: Int
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case filesIndexed = "files_indexed"
        case chunksCreated = "chunks_created"
        case message
    }
}

enum IndexMode: String, Codable, CaseIterable {
    case manual = "manual"
    case smart = "smart"
    case full = "full"

    var displayName: String {
        switch self {
        case .manual: return "Manual Selection"
        case .smart: return "Smart Index"
        case .full: return "Full Repository"
        }
    }

    var description: String {
        switch self {
        case .manual: return "Choose specific files"
        case .smart: return "Index commonly used files"
        case .full: return "Index entire repository"
        }
    }

    var detailedDescription: String {
        switch self {
        case .manual:
            return "⚡️ Fastest • You manually select which files to index. Best for large repos when you only need specific files."
        case .smart:
            return "🎯 Optimal • Automatically indexes commonly used files (source code, docs). Ignores node_modules, build artifacts, etc."
        case .full:
            return "🔍 Complete • Indexes everything in the repository. Slowest but most comprehensive."
        }
    }
}

// MARK: - Boss Mode Models

struct AdviseRequest: Codable {
    let transcript: String
    let screenshotBase64: String?
    let codeSnippets: [String]?
    let meetingContext: String?
}

struct AdviseResponse: Codable {
    let talkingPoint: String
    let confidence: Double
    let context: String

    enum CodingKeys: String, CodingKey {
        case talkingPoint = "talking_point"
        case confidence
        case context
    }
}

struct ScreenshotResponse: Codable {
    let success: Bool
    let screenshotBase64: String
    let sizeBytes: Int

    enum CodingKeys: String, CodingKey {
        case success
        case screenshotBase64 = "screenshot_base64"
        case sizeBytes = "size_bytes"
    }
}

enum APIError: Error, LocalizedError {
    case notAuthenticated
    case requestFailed
    case decodingFailed
    case whisperUnavailable

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Backend rejected the auth token. Try restarting the app."
        case .requestFailed:
            return "Request to backend failed"
        case .decodingFailed:
            return "Failed to parse backend response"
        case .whisperUnavailable:
            return "Speech-to-text isn't available — install faster-whisper on the backend (pip install faster-whisper) and restart."
        }
    }
}
