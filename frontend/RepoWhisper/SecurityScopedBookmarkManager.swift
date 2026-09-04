//
//  SecurityScopedBookmarkManager.swift
//  RepoWhisper
//
//  Manages security-scoped bookmarks for approved repository folders.
//  Persists approvals across app restarts and writes allowlist.json.
//

import Foundation
import AppKit

/// Manages security-scoped bookmarks for approved repository folders
@MainActor
class SecurityScopedBookmarkManager: ObservableObject {
    static let shared = SecurityScopedBookmarkManager()

    /// Currently approved repository paths
    @Published var approvedPaths: [String] = []

    private let bookmarksKey = "RepoWhisper.SecurityScopedBookmarks"
    private var activeBookmarks: [String: URL] = [:]

    private init() {
        startAccessingAll()
    }

    // Note: stopAccessingAll() should be called manually on app termination
    // Cannot call @MainActor method from deinit

    // MARK: - Bookmark Management

    /// Add a folder with security-scoped bookmark
    func addFolder() throws -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a repository folder to approve for indexing"
        panel.prompt = "Approve"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        let path = url.path

        // Don't add duplicates
        if approvedPaths.contains(path) {
            return path
        }

        // Create security-scoped bookmark
        guard let bookmarkData = try? url.bookmarkData(
            options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            throw BookmarkError.failedToCreateBookmark(path: path)
        }

        // Store bookmark
        var bookmarks = loadBookmarksData()
        bookmarks[path] = bookmarkData
        saveBookmarksData(bookmarks)

        // Start accessing
        if url.startAccessingSecurityScopedResource() {
            activeBookmarks[path] = url
            approvedPaths.append(path)
            print("✅ [BOOKMARK] Added and accessing: \(path)")
        } else {
            throw BookmarkError.failedToStartAccessing(path: path)
        }

        return path
    }

    /// Remove a folder and its bookmark
    func removeFolder(path: String) {
        // Stop accessing
        if let url = activeBookmarks[path] {
            url.stopAccessingSecurityScopedResource()
            activeBookmarks.removeValue(forKey: path)
        }

        // Remove from storage
        var bookmarks = loadBookmarksData()
        bookmarks.removeValue(forKey: path)
        saveBookmarksData(bookmarks)

        // Remove from list
        approvedPaths.removeAll { $0 == path }

        print("🗑️ [BOOKMARK] Removed: \(path)")
    }

    // MARK: - Lifecycle

    /// Load and start accessing all saved bookmarks. This is intentionally
    /// idempotent so launch-time callers can retry after SwiftUI and
    /// cfprefsd have finished restoring application state.
    func startAccessingAll() {
        let bookmarks = loadBookmarksData()
        var stalePaths: [String] = []

        for (path, bookmarkData) in bookmarks {
            guard activeBookmarks[path] == nil else { continue }

            do {
                var isStale = false
                let url = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                if isStale {
                    print("⚠️ [BOOKMARK] Stale bookmark for: \(path)")
                    stalePaths.append(path)
                    continue
                }

                if url.startAccessingSecurityScopedResource() {
                    activeBookmarks[path] = url
                    if !approvedPaths.contains(path) {
                        approvedPaths.append(path)
                    }
                    print("✅ [BOOKMARK] Restored access: \(path)")
                } else {
                    print("❌ [BOOKMARK] Failed to access: \(path)")
                }
            } catch {
                print("❌ [BOOKMARK] Failed to resolve bookmark for \(path): \(error)")
            }
        }

        if !stalePaths.isEmpty {
            var mutableBookmarks = bookmarks
            stalePaths.forEach { mutableBookmarks.removeValue(forKey: $0) }
            saveBookmarksData(mutableBookmarks)
        }

        print("📂 [BOOKMARK] Accessing \(activeBookmarks.count) folders")
    }

    /// Stop accessing all bookmarks
    func stopAccessingAll() {
        for (path, url) in activeBookmarks {
            url.stopAccessingSecurityScopedResource()
            print("🛑 [BOOKMARK] Stopped accessing: \(path)")
        }
        activeBookmarks.removeAll()
    }

    // MARK: - Allowlist File

    /// Write allowlist.json to Application Support. An empty array is a valid
    /// revocation state and causes the running backend to deny every path.
    func writeAllowlistFile() throws {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let repoWhisperDir = appSupport.appendingPathComponent("RepoWhisper")
        let allowlistFile = repoWhisperDir.appendingPathComponent("allowlist.json")

        // Create directory if needed
        try FileManager.default.createDirectory(
            at: repoWhisperDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        // Write JSON
        let jsonData = try JSONEncoder().encode(approvedPaths)
        try jsonData.write(to: allowlistFile, options: .atomic)

        // Set permissions
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: allowlistFile.path
        )

        print("✅ [ALLOWLIST] Written to: \(allowlistFile.path)")
        print("📝 [ALLOWLIST] Approved paths: \(approvedPaths)")
    }

    /// Get the allowlist file path (for passing to backend)
    func getAllowlistFilePath() -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let repoWhisperDir = appSupport.appendingPathComponent("RepoWhisper")
        let allowlistFile = repoWhisperDir.appendingPathComponent("allowlist.json")

        return allowlistFile.path
    }

    // MARK: - Persistence

    private func loadBookmarksData() -> [String: Data] {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else {
            return [:]
        }

        do {
            return try JSONDecoder().decode([String: Data].self, from: data)
        } catch {
            print("❌ [BOOKMARK] Failed to decode bookmarks: \(error)")
            return [:]
        }
    }

    private func saveBookmarksData(_ bookmarks: [String: Data]) {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(data, forKey: bookmarksKey)
            print("💾 [BOOKMARK] Saved \(bookmarks.count) bookmarks")
        } catch {
            print("❌ [BOOKMARK] Failed to encode bookmarks: \(error)")
        }
    }
}

// MARK: - Errors

enum BookmarkError: LocalizedError {
    case failedToCreateBookmark(path: String)
    case failedToStartAccessing(path: String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateBookmark(let path):
            return "Failed to create security bookmark for: \(path)"
        case .failedToStartAccessing(let path):
            return "Failed to access folder: \(path)"
        }
    }
}
