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
                RWPageHeader(
                    eyebrow: "Workspace",
                    title: "Repositories",
                    subtitle: "Control exactly which folders RepoWhisper can read."
                ) {
                    Button(action: addRepository) {
                        Label("Add repository", systemImage: "plus")
                    }
                    .buttonStyle(RWPrimaryButtonStyle())
                    .accessibilityIdentifier("repositories.add")
                }

                // Backend status pill
                HStack(spacing: 8) {
                    RWStatusPill(title: backendManager.statusMessage, color: statusColor)
                    if backendManager.isHealthy && backendManager.indexCount > 0 {
                        RWMetricChip(symbol: "doc.text", value: "\(backendManager.indexCount)", label: "chunks")
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, RWTheme.pagePadding)
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Approved repositories list
                    if bookmarkManager.approvedPaths.isEmpty {
                        RWEmptyState(
                            symbol: "folder.badge.plus",
                            title: "No repositories yet",
                            message: "Add a project folder to make its code available for local indexing and search."
                        )
                        .frame(maxWidth: .infinity)
                        .rwGlass()
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Approved access", systemImage: "checkmark.shield.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(RWTheme.text)
                                Spacer()
                                Text("\(bookmarkManager.approvedPaths.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(RWTheme.textFaint)
                            }

                            ForEach(bookmarkManager.approvedPaths, id: \.self) { path in
                                repositoryRow(path: path)
                            }
                        }
                        .padding(18)
                        .rwGlass()
                    }
                }
                .padding(RWTheme.pagePadding)
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
