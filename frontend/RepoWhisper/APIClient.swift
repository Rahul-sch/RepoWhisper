//
//  APIClient.swift
//  RepoWhisper
//
//  HTTP client for communicating with the Python backend.
//  Handles transcription, search, and indexing requests.
//

import Foundation

/// API client for the RepoWhisper backend
@MainActor
class APIClient: ObservableObject {
    /// Shared singleton instance
    static let shared = APIClient()
    
    /// Backend is reachable
    @Published var isConnected: Bool = false
    
    /// Number of indexed chunks
    @Published var indexCount: Int = 0
    
    /// Last error message
    @Published var errorMessage: String?
    
    private let baseURL: URL
    private let session: URLSession
    
    private init() {
        self.baseURL = SupabaseConfig.backendURL
        
        // Configure session for low latency with short timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5  // Reduced from 30 to prevent hanging
        config.timeoutIntervalForResource = 10  // Reduced from 60
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Health Check
    
    /// Check if backend is reachable
    func checkHealth() async {
        do {
            let url = baseURL.appendingPathComponent("health")
            // Add timeout to prevent hanging
            let (data, _) = try await session.data(from: url)
            
            let response = try JSONDecoder().decode(HealthResponse.self, from: data)
            await MainActor.run {
                isConnected = response.status == "healthy"
                indexCount = response.indexCount
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                isConnected = false
                errorMessage = "Backend not reachable"
            }
        }
    }
    
    // MARK: - Transcription
    
    /// Transcribe raw PCM audio data
    /// - Parameter audioData: Raw PCM audio (16kHz, mono, 16-bit)
    /// - Returns: Transcription result
    func transcribe(audioData: Data) async throws -> TranscriptionResult {
        let url = baseURL.appendingPathComponent("transcribe")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        // Add auth token (skip in dev mode)
        if !AuthManager.shared.devMode {
            guard let token = AuthManager.shared.accessToken else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = audioData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(TranscriptionResult.self, from: data)
    }
    
    // MARK: - Search
    
    /// Search indexed code
    /// - Parameters:
    ///   - query: Search query text
    ///   - topK: Number of results to return
    /// - Returns: Search results
    func search(query: String, topK: Int = 5) async throws -> SearchResponse {
        let url = baseURL.appendingPathComponent("search")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token (skip in dev mode)
        if !AuthManager.shared.devMode {
            guard let token = AuthManager.shared.accessToken else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = SearchRequest(query: query, topK: topK)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }
    
    // MARK: - Indexing
    
    /// Index a repository
    /// - Parameters:
    ///   - repoPath: Path to the repository
    ///   - mode: Indexing mode
    ///   - filePaths: Specific files (manual mode)
    ///   - patterns: Glob patterns (smart mode)
    /// - Returns: Index result
    func indexRepository(
        repoPath: String,
        mode: IndexMode,
        filePaths: [String]? = nil,
        patterns: [String]? = nil
    ) async throws -> IndexResponse {
        let url = baseURL.appendingPathComponent("index")
        
        print("🔍 [INDEX] Starting index request...")
        print("🔍 [INDEX] URL: \(url)")
        print("🔍 [INDEX] Repo Path: \(repoPath)")
        print("🔍 [INDEX] Mode: \(mode)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token (skip in dev mode)
        if !AuthManager.shared.devMode {
            guard let token = AuthManager.shared.accessToken else {
                print("❌ [INDEX] No auth token available")
                throw APIError.notAuthenticated
            }
            print("✅ [INDEX] Auth token found")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            print("🧪 [INDEX] Dev mode - skipping auth token")
        }
        
        let body = IndexRequest(
            mode: mode,
            repoPath: repoPath,
            filePaths: filePaths,
            patterns: patterns
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        print("📤 [INDEX] Sending request...")
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [INDEX] Invalid response type")
            throw APIError.requestFailed
        }
        
        print("📥 [INDEX] Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ [INDEX] Request failed with status \(httpResponse.statusCode)")
            print("❌ [INDEX] Error body: \(errorBody)")
            throw APIError.requestFailed
        }
        
        let indexResponse = try JSONDecoder().decode(IndexResponse.self, from: data)
        print("✅ [INDEX] Success! Files: \(indexResponse.filesIndexed), Chunks: \(indexResponse.chunksCreated)")
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
        let url = baseURL.appendingPathComponent("advise")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add auth token (skip in dev mode)
        if !AuthManager.shared.devMode {
            guard let token = AuthManager.shared.accessToken else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = AdviseRequest(
            transcript: transcript,
            screenshotBase64: screenshotBase64,
            codeSnippets: codeSnippets,
            meetingContext: meetingContext
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(AdviseResponse.self, from: data)
    }
    
    /// Upload screenshot for processing
    func uploadScreenshot(_ screenshotData: Data) async throws -> ScreenshotResponse {
        let url = baseURL.appendingPathComponent("screenshot")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        
        // Add auth token (skip in dev mode)
        if !AuthManager.shared.devMode {
            guard let token = AuthManager.shared.accessToken else {
                throw APIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = screenshotData
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        return try JSONDecoder().decode(ScreenshotResponse.self, from: data)
    }
}

// MARK: - API Models

struct HealthResponse: Codable {
    let status: String
    let modelLoaded: Bool
    let indexCount: Int
    let version: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case modelLoaded = "model_loaded"
        case indexCount = "index_count"
        case version
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
    
    enum CodingKeys: String, CodingKey {
        case query
        case topK = "top_k"
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
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .requestFailed:
            return "Request to backend failed"
        case .decodingFailed:
            return "Failed to parse response"
        }
    }
}

