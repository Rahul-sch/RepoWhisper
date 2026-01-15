//
//  BackendProcessManager.swift
//  RepoWhisper
//
//  Manages the Python backend process lifecycle via Unix Domain Socket.
//

import Foundation
import AppKit

/// Manages the backend Python process lifecycle
@MainActor
class BackendProcessManager: ObservableObject {
    static let shared = BackendProcessManager()

    /// Backend process status
    enum BackendStatus: Equatable {
        case stopped
        case starting
        case healthy
        case error(String)
    }

    @Published var status: BackendStatus = .stopped
    @Published var indexCount: Int = 0
    @Published var isRunning: Bool = false
    @Published var isHealthy: Bool = false
    @Published var statusMessage: String = "Backend stopped"

    // MARK: - Paths and Configuration

    /// Application Support directory (0700)
    private var supportDirectory: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("RepoWhisper")
    }

    /// Logs directory (0700)
    private var logsDirectory: URL {
        return supportDirectory.appendingPathComponent("logs")
    }

    /// Path to the Unix Domain Socket
    private var socketPath: String {
        return supportDirectory.appendingPathComponent("backend.sock").path
    }

    /// Path to backend binary (architecture-specific)
    private var backendBinaryPath: String? {
        // Detect current architecture
        #if arch(arm64)
        let binaryName = "repowhisper-backend-arm64"
        #elseif arch(x86_64)
        let binaryName = "repowhisper-backend-x86_64"
        #else
        return nil
        #endif

        // Look for binary in app bundle Resources
        if let resourcePath = Bundle.main.resourcePath {
            let binaryPath = (resourcePath as NSString).appendingPathComponent(binaryName)
            if FileManager.default.fileExists(atPath: binaryPath) {
                return binaryPath
            }
        }

        // Development fallback: use Python script
        let devPath = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        let parentDevPath = (devPath as NSString).deletingLastPathComponent
        let backendMainPy = (parentDevPath as NSString).appendingPathComponent("backend/main.py")
        if FileManager.default.fileExists(atPath: backendMainPy) {
            return backendMainPy
        }

        return nil
    }

    /// Path to Python virtual environment (for dev mode only)
    private var pythonPath: String? {
        guard let binaryPath = backendBinaryPath,
              binaryPath.hasSuffix(".py") else {
            return nil // Not needed for compiled binaries
        }

        let backendDir = (binaryPath as NSString).deletingLastPathComponent
        let venvPython = (backendDir as NSString).appendingPathComponent("venv/bin/python3")
        if FileManager.default.fileExists(atPath: venvPython) {
            return venvPython
        }

        return "/usr/bin/python3"
    }

    /// Path to allowlist file
    private var allowlistPath: URL {
        return URL(fileURLWithPath: SecurityScopedBookmarkManager.shared.getAllowlistFilePath())
    }

    /// Path to auth token file
    private var authTokenPath: URL {
        return supportDirectory.appendingPathComponent("auth_token.txt")
    }

    /// Path to models directory (if present in Resources)
    private var modelsDirectory: String {
        if let resourcePath = Bundle.main.resourcePath {
            let modelsPath = (resourcePath as NSString).appendingPathComponent("models")
            if FileManager.default.fileExists(atPath: modelsPath) {
                return modelsPath
            }
        }
        return ""
    }

    /// Per-install auth token (read from file or generate)
    private var authToken: String {
        get throws {
            // Try to read existing token
            if FileManager.default.fileExists(atPath: authTokenPath.path) {
                if let token = try? String(contentsOf: authTokenPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
                   !token.isEmpty {
                    return token
                }
            }

            // Generate new token
            let newToken = UUID().uuidString
            try newToken.write(to: authTokenPath, atomically: true, encoding: .utf8)

            // Set permissions to 0600
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: authTokenPath.path
            )

            print("🔑 [BACKEND] Generated new auth token at \(authTokenPath.path)")
            return newToken
        }
    }

    /// Environment variables for backend process
    private var backendEnvironment: [String: String] {
        get throws {
            var env = ProcessInfo.processInfo.environment
            let token = try authToken

            env["REPOWHISPER_SOCKET_PATH"] = socketPath
            env["REPOWHISPER_AUTH_TOKEN"] = token
            env["REPOWHISPER_ALLOWLIST_FILE"] = allowlistPath.path
            env["REPOWHISPER_DATA_DIR"] = supportDirectory.path
            env["REPOWHISPER_MODELS_DIR"] = modelsDirectory
            env["DEBUG"] = "false"

            return env
        }
    }

    // MARK: - Process Management

    private var process: Process?

    private init() {
        print("🏗️ [BACKEND] BackendProcessManager initialized")
        print("📍 [BACKEND] Socket path: \(socketPath)")
        print("📍 [BACKEND] Binary path: \(backendBinaryPath ?? "NOT FOUND")")
        print("📍 [BACKEND] Support dir: \(supportDirectory.path)")
        print("📍 [BACKEND] Logs dir: \(logsDirectory.path)")
        print("📍 [BACKEND] Allowlist: \(allowlistPath.path)")
    }

    // Note: stop() should be called manually on app termination
    // Cannot call @MainActor method from deinit

    // MARK: - Directory Setup

    /// Create required directories with proper permissions
    private func setupDirectories() throws {
        let fm = FileManager.default

        // Create Application Support directory (0700)
        if !fm.fileExists(atPath: supportDirectory.path) {
            try fm.createDirectory(
                at: supportDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            print("📁 [BACKEND] Created support directory: \(supportDirectory.path)")
        }

        // Ensure correct permissions on existing directory
        try fm.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: supportDirectory.path
        )

        // Create logs directory (0700)
        if !fm.fileExists(atPath: logsDirectory.path) {
            try fm.createDirectory(
                at: logsDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            print("📁 [BACKEND] Created logs directory: \(logsDirectory.path)")
        }

        // Ensure correct permissions on logs directory
        try fm.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: logsDirectory.path
        )
    }

    // MARK: - Lifecycle

    /// Start the backend process
    func start() throws {
        guard process == nil else {
            print("⚠️ [BACKEND] Process already running")
            return
        }

        print("🚀 [BACKEND] Starting backend process...")
        status = .starting
        statusMessage = "Starting backend..."

        // Step 1: Setup directories
        try setupDirectories()

        // Step 2: Delete stale socket
        let fm = FileManager.default
        if fm.fileExists(atPath: socketPath) {
            try fm.removeItem(atPath: socketPath)
            print("🗑️ [BACKEND] Removed stale socket")
        }

        // Step 3: Write allowlist (FAIL-CLOSED)
        do {
            try SecurityScopedBookmarkManager.shared.writeAllowlistFile()
            print("✅ [BACKEND] Allowlist written")
        } catch {
            let errorMsg = "No repositories approved. Please add a repository folder first."
            print("❌ [BACKEND] \(errorMsg)")
            status = .error(errorMsg)
            statusMessage = errorMsg
            throw NSError(
                domain: "BackendProcessManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }

        // Step 4: Get backend binary path
        guard let binaryPath = backendBinaryPath else {
            let errorMsg = "Backend binary not found"
            print("❌ [BACKEND] \(errorMsg)")
            status = .error(errorMsg)
            statusMessage = errorMsg
            throw NSError(
                domain: "BackendProcessManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }

        // Step 5: Setup process
        let proc = Process()
        proc.currentDirectoryURL = supportDirectory

        // Determine executable and arguments
        if binaryPath.hasSuffix(".py") {
            // Development mode: run Python script
            guard let python = pythonPath else {
                let errorMsg = "Python interpreter not found"
                print("❌ [BACKEND] \(errorMsg)")
                status = .error(errorMsg)
                statusMessage = errorMsg
                throw NSError(
                    domain: "BackendProcessManager",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: errorMsg]
                )
            }
            proc.executableURL = URL(fileURLWithPath: python)
            proc.arguments = [binaryPath]
            print("🐍 [BACKEND] Running Python mode: \(python) \(binaryPath)")
        } else {
            // Production mode: run compiled binary
            proc.executableURL = URL(fileURLWithPath: binaryPath)
            proc.arguments = []
            print("📦 [BACKEND] Running binary mode: \(binaryPath)")
        }

        // Set environment
        proc.environment = try backendEnvironment

        // Setup logging
        let stdoutLog = logsDirectory.appendingPathComponent("backend.log")
        let stderrLog = logsDirectory.appendingPathComponent("backend.err.log")

        // Create log files if needed
        if !fm.fileExists(atPath: stdoutLog.path) {
            fm.createFile(atPath: stdoutLog.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        if !fm.fileExists(atPath: stderrLog.path) {
            fm.createFile(atPath: stderrLog.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }

        let stdoutHandle = try FileHandle(forWritingTo: stdoutLog)
        let stderrHandle = try FileHandle(forWritingTo: stderrLog)

        proc.standardOutput = stdoutHandle
        proc.standardError = stderrHandle

        // Launch process
        try proc.run()
        process = proc
        print("✅ [BACKEND] Process launched (PID: \(proc.processIdentifier))")

        // Step 6: Wait for socket to appear (poll for up to 30s)
        let startTime = Date()
        let timeout: TimeInterval = 30.0
        var socketAppeared = false

        while Date().timeIntervalSince(startTime) < timeout {
            if fm.fileExists(atPath: socketPath) {
                socketAppeared = true
                print("✅ [BACKEND] Socket appeared at \(socketPath)")
                break
            }

            if !proc.isRunning {
                let errorMsg = "Backend process exited prematurely"
                print("❌ [BACKEND] \(errorMsg)")
                process = nil
                status = .error(errorMsg)
                statusMessage = errorMsg
                throw NSError(
                    domain: "BackendProcessManager",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: errorMsg]
                )
            }

            Thread.sleep(forTimeInterval: 0.1)
        }

        guard socketAppeared else {
            let errorMsg = "Socket did not appear within timeout"
            print("❌ [BACKEND] \(errorMsg)")
            stop()
            status = .error(errorMsg)
            statusMessage = errorMsg
            throw NSError(
                domain: "BackendProcessManager",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }

        // Step 7: Perform health check
        do {
            let healthResponse = try performHealthCheck()
            isHealthy = true
            status = .healthy
            statusMessage = "Backend running"
            indexCount = healthResponse.indexCount
            print("✅ [BACKEND] Health check passed, index_count=\(healthResponse.indexCount)")
        } catch {
            let errorMsg = "Health check failed: \(error.localizedDescription)"
            print("❌ [BACKEND] \(errorMsg)")
            stop()
            status = .error(errorMsg)
            statusMessage = errorMsg
            throw NSError(
                domain: "BackendProcessManager",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }

        print("✅ [BACKEND] Backend process started successfully")
    }

    /// Stop the backend process
    func stop() {
        guard let proc = process else {
            print("ℹ️ [BACKEND] No process to stop")
            isRunning = false
            isHealthy = false
            status = .stopped
            statusMessage = "Backend stopped"
            return
        }

        print("🛑 [BACKEND] Stopping backend process (PID: \(proc.processIdentifier))...")

        // Send SIGTERM first
        if proc.isRunning {
            proc.terminate()
            print("📤 [BACKEND] Sent SIGTERM")

            // Wait up to 3 seconds for graceful shutdown
            let startTime = Date()
            while proc.isRunning && Date().timeIntervalSince(startTime) < 3.0 {
                Thread.sleep(forTimeInterval: 0.1)
            }

            // Force kill if still running
            if proc.isRunning {
                print("⚠️ [BACKEND] Process still running, sending SIGKILL")
                kill(proc.processIdentifier, SIGKILL)
                Thread.sleep(forTimeInterval: 0.5)
            }
        }

        process = nil

        // Clean up socket
        let fm = FileManager.default
        if fm.fileExists(atPath: socketPath) {
            try? fm.removeItem(atPath: socketPath)
            print("🗑️ [BACKEND] Removed socket file")
        }

        // Update state
        isRunning = false
        isHealthy = false
        status = .stopped
        statusMessage = "Backend stopped"
        print("✅ [BACKEND] Backend process stopped")
    }

    func restart() {
        stop()
        try? start()
    }

    // MARK: - Health Monitoring

    /// Response from /health endpoint
    struct HealthCheckResponse: Codable {
        let status: String
        let model_loaded: Bool
        let index_count: Int
        let version: String

        var indexCount: Int { return index_count }
    }

    /// Perform a health check via Unix socket
    func performHealthCheck() throws -> HealthCheckResponse {
        let client = UnixSocketHTTPClient(socketPath: socketPath, timeout: 5.0)

        // Get auth token
        let token = try authToken

        // Make request with X-Auth-Token header
        let response = try client.get(path: "/health", headers: ["X-Auth-Token": token])

        guard response.statusCode == 200 else {
            throw NSError(
                domain: "BackendProcessManager",
                code: 100,
                userInfo: [NSLocalizedDescriptionKey: "Health check returned status \(response.statusCode)"]
            )
        }

        // Parse JSON response
        guard let bodyString = response.bodyString,
              let bodyData = bodyString.data(using: .utf8) else {
            throw NSError(
                domain: "BackendProcessManager",
                code: 101,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response body"]
            )
        }

        let decoder = JSONDecoder()
        let healthResponse = try decoder.decode(HealthCheckResponse.self, from: bodyData)

        guard healthResponse.status == "healthy" else {
            throw NSError(
                domain: "BackendProcessManager",
                code: 102,
                userInfo: [NSLocalizedDescriptionKey: "Backend reported unhealthy status"]
            )
        }

        return healthResponse
    }

    func startHealthMonitoring() {
        // TODO: B3 - Implement health polling
        print("⏳ [BACKEND] startHealthMonitoring() called - not implemented yet")
    }
}
