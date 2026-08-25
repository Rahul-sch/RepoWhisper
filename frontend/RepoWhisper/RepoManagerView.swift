//
//  RepoManagerView.swift
//  RepoWhisper
//
//  Repository management view - Phase C.2
//  Lists approved repositories with add/remove functionality.
//

import SwiftUI
import AppKit

struct RepoManagerView: View {
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @StateObject private var backendManager = BackendProcessManager.shared

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pathToRemove: String?
    @State private var showRemoveConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with backend status
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OverlayTheme.accent)
                    Text("Repositories")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OverlayTheme.textPrimary)
                    Spacer()
                }

                // Backend status pill
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(backendManager.statusMessage)
                            .font(.caption)
                            .foregroundStyle(OverlayTheme.textSecondary)
                    }

                    if backendManager.isHealthy && backendManager.indexCount > 0 {
                        Divider()
                            .frame(height: 12)

                        HStack(spacing: 4) {
                            Image(systemName: "doc.text.fill")
                                .font(.caption2)
                            Text("\(backendManager.indexCount) chunks")
                                .font(.caption)
                        }
                        .foregroundStyle(OverlayTheme.textSecondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(OverlayTheme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .padding(20)
            .background(OverlayTheme.canvas)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Add repository button
                    Button(action: addRepository) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text("Add Repository")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(OverlayTheme.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius))
                    }
                    .buttonStyle(.plain)

                    // Approved repositories list
                    if bookmarkManager.approvedPaths.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 50))
                                .foregroundStyle(OverlayTheme.textSecondary)

                            Text("No Repositories Added")
                                .font(.headline)
                                .foregroundStyle(OverlayTheme.textSecondary)

                            Text("Add a repository to start indexing and searching your code")
                                .font(.caption)
                                .foregroundStyle(OverlayTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Approved Repositories", systemImage: "checkmark.shield.fill")
                                .font(.headline)
                                .foregroundStyle(OverlayTheme.textPrimary)

                            ForEach(bookmarkManager.approvedPaths, id: \.self) { path in
                                repositoryRow(path: path)
                            }
                        }
                        .padding()
                        .background(OverlayTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(OverlayTheme.border))
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "Remove Repository",
            isPresented: $showRemoveConfirmation,
            presenting: pathToRemove
        ) { path in
            Button("Remove", role: .destructive) {
                removeRepository(path: path)
            }
            Button("Cancel", role: .cancel) {}
        } message: { path in
            Text("Remove '\(URL(fileURLWithPath: path).lastPathComponent)' from approved repositories?\n\nThis will not delete any files, but RepoWhisper will no longer be able to access this folder.")
        }
    }

    // MARK: - Repository Row

    @ViewBuilder
    private func repositoryRow(path: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(OverlayTheme.accent)
                    .font(.title3)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .fontWeight(.medium)
                        .font(.body)
                        .foregroundStyle(OverlayTheme.textPrimary)

                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(OverlayTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                Button(action: { confirmRemove(path: path) }) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(OverlayTheme.danger)
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Remove repository")
            }
            .padding()
            .background(OverlayTheme.canvas.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            // Warning for overly broad paths
            if isOverlyBroadPath(path) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Overly Broad Access")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)

                        Text("This grants access to your entire system. Consider selecting a specific project folder instead.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Backend Status Color

    private var statusColor: Color {
        switch backendManager.status {
        case .healthy:
            return OverlayTheme.success
        case .starting:
            return .yellow
        case .stopped:
            return .gray
        case .error:
            return OverlayTheme.danger
        }
    }

    // MARK: - Path Validation

    private func isOverlyBroadPath(_ path: String) -> Bool {
        let nsPath = path as NSString
        let expandedPath = nsPath.expandingTildeInPath

        // Check for root or home directory
        return expandedPath == "/" ||
               expandedPath == NSHomeDirectory() ||
               expandedPath == "/Users" ||
               expandedPath == "/Applications" ||
               expandedPath == "/System"
    }

    // MARK: - Actions

    private func addRepository() {
        Task { @MainActor in
            do {
                if let path = try bookmarkManager.addFolder() {
                    // Write allowlist to disk
                    try bookmarkManager.writeAllowlistFile()

                    // Show warning if overly broad
                    if isOverlyBroadPath(path) {
                        errorMessage = "Warning: You've granted access to '\(path)'. This is a very broad path. Consider selecting a specific project folder instead."
                        showError = true
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func confirmRemove(path: String) {
        pathToRemove = path
        showRemoveConfirmation = true
    }

    private func removeRepository(path: String) {
        Task { @MainActor in
            do {
                bookmarkManager.removeFolder(path: path)
                try bookmarkManager.writeAllowlistFile()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    RepoManagerView()
}
#endif
