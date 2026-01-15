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

    // MARK: - Lifecycle (Stubs for B2)

    func start() {
        // TODO: B2 - Implement process start
        print("⏳ [BACKEND] start() called - not implemented yet")
    }

    func stop() {
        // TODO: B2 - Implement process stop
        print("⏳ [BACKEND] stop() called - not implemented yet")
    }

    func restart() {
        stop()
        start()
    }

    // MARK: - Health Monitoring (Stub for B3)

    func startHealthMonitoring() {
        // TODO: B3 - Implement health polling
        print("⏳ [BACKEND] startHealthMonitoring() called - not implemented yet")
    }
}
