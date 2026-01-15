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

    // MARK: - Paths and Configuration

    /// Path to the Unix Domain Socket
    private var socketPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let repoWhisperDir = appSupport.appendingPathComponent("RepoWhisper")
        return repoWhisperDir.appendingPathComponent("backend.sock").path
    }

    /// Path to the backend main.py
    private var backendScriptPath: String {
        // Look for backend in same directory as app bundle
        if let bundlePath = Bundle.main.bundlePath as NSString? {
            let parentPath = bundlePath.deletingLastPathComponent
            let backendPath = (parentPath as NSString).appendingPathComponent("backend/main.py")
            if FileManager.default.fileExists(atPath: backendPath) {
                return backendPath
            }
        }

        // Fallback to development path (when running from Xcode)
        let devPath = (Bundle.main.bundlePath as NSString).deletingLastPathComponent
        let parentDevPath = (devPath as NSString).deletingLastPathComponent
        return (parentDevPath as NSString).appendingPathComponent("backend/main.py")
    }

    /// Path to Python virtual environment
    private var pythonPath: String {
        // Look for venv in backend directory
        let backendDir = (backendScriptPath as NSString).deletingLastPathComponent
        let venvPython = (backendDir as NSString).appendingPathComponent("venv/bin/python3")
        if FileManager.default.fileExists(atPath: venvPython) {
            return venvPython
        }

        // Fallback to system python
        return "/usr/bin/python3"
    }

    /// Path to allowlist file
    private var allowlistPath: String {
        SecurityScopedBookmarkManager.shared.getAllowlistFilePath()
    }

    /// Per-install auth token (generated once and persisted)
    private var authToken: String {
        let key = "RepoWhisper.BackendAuthToken"
        if let token = UserDefaults.standard.string(forKey: key) {
            return token
        }

        // Generate new token
        let newToken = UUID().uuidString
        UserDefaults.standard.set(newToken, forKey: key)
        print("🔑 [BACKEND] Generated new auth token")
        return newToken
    }

    // MARK: - Process Management

    private var process: Process?

    private init() {
        print("🏗️ [BACKEND] BackendProcessManager initialized")
        print("📍 [BACKEND] Socket path: \(socketPath)")
        print("📍 [BACKEND] Backend script: \(backendScriptPath)")
        print("📍 [BACKEND] Python path: \(pythonPath)")
        print("📍 [BACKEND] Allowlist: \(allowlistPath)")
    }

    // Note: stop() should be called manually on app termination
    // Cannot call @MainActor method from deinit

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
