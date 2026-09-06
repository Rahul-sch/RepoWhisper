//
//  IndexingView.swift
//  RepoWhisper
//
//  Indexing UI with progress tracking - Phase C.3
//

import SwiftUI

struct IndexingView: View {
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var backendManager = BackendProcessManager.shared

    @State private var selectedRepoPath: String = ""
    @State private var selectedIndexMode: IndexMode = .smart
    @State private var isIndexing = false
    @State private var indexProgress: Double = 0
    @State private var statusMessage: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var lastIndexedCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                RWPageHeader(
                    eyebrow: "Knowledge",
                    title: "Build the index",
                    subtitle: "Choose a repository and decide how much context to include."
                ) {
                    RWStatusPill(
                        title: backendManager.isHealthy ? "Ready" : "Backend unavailable",
                        color: backendManager.isHealthy ? RWTheme.success : RWTheme.warning
                    )
                }

                // Backend status indicator
                if !backendManager.isHealthy {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Backend not ready. Please wait...")
                            .font(.caption)
                            .foregroundStyle(OverlayTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, RWTheme.pagePadding)
            .padding(.top, 24)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Repository Selection
                    RWSectionCard(
                        title: "Repository",
                        subtitle: "Pick one approved source folder",
                        symbol: "folder"
                    ) {
                        if bookmarkManager.approvedPaths.isEmpty {
                            RWEmptyState(
                                symbol: "folder.badge.questionmark",
                                title: "No approved repository",
                                message: "Add a folder from the Repositories view before indexing."
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            Picker("Repository", selection: $selectedRepoPath) {
                                Text("Choose a repository...").tag("")
                                ForEach(bookmarkManager.approvedPaths, id: \.self) { path in
                                    HStack {
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                        Text("•").foregroundStyle(OverlayTheme.textSecondary)
                                        Text(path)
                                            .font(.caption)
                                            .foregroundStyle(OverlayTheme.textSecondary)
                                    }
                                    .tag(path)
                                }
                            }
                            .pickerStyle(.menu)

                            if !selectedRepoPath.isEmpty {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundStyle(OverlayTheme.accent)
                                    Text(selectedRepoPath)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(OverlayTheme.textSecondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(10)
                                .background(OverlayTheme.canvas.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }

                    // Index Mode Selection
                    RWSectionCard(
                        title: "Indexing mode",
                        subtitle: "Balance speed and control",
                        symbol: "slider.horizontal.3"
                    ) {
                        Picker("Mode", selection: $selectedIndexMode) {
                            ForEach(IndexMode.allCases, id: \.self) { mode in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayName)
                                        .fontWeight(.medium)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)

                        // Mode info
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(OverlayTheme.accent)
                            Text(selectedIndexMode.detailedDescription)
                                .font(.caption)
                                .foregroundStyle(OverlayTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(OverlayTheme.accent.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }

                    // Index Button
                    Button(action: startIndexing) {
                        HStack {
                            if isIndexing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(.circular)
                                Text("Indexing...")
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Start Indexing")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RWPrimaryButtonStyle())
                    .disabled(!canStartIndexing)
                    .opacity(canStartIndexing ? 1.0 : 0.38)
                    .accessibilityIdentifier("indexing.start")

                    // Progress section
                    if isIndexing {
                        VStack(spacing: 12) {
                            ProgressView(value: indexProgress, total: 1.0)
                                .progressViewStyle(.linear)

                            HStack {
                                Image(systemName: "gearshape.2.fill")
                                    .foregroundStyle(OverlayTheme.accent)
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundStyle(OverlayTheme.textSecondary)
                            }
                        }
                        .padding(18)
                        .rwGlass()
                    }

                    // Completion stats
                    if lastIndexedCount > 0 && !isIndexing {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Indexing Complete", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(OverlayTheme.success)

                            HStack(spacing: 20) {
                                StatBadge(
                                    icon: "doc.text.fill",
                                    value: "\(lastIndexedCount)",
                                    label: "Chunks Indexed"
                                )

                                StatBadge(
                                    icon: "checkmark.circle.fill",
                                    value: "Ready",
                                    label: "Status"
                                )
                            }
                        }
                        .padding()
                        .background(OverlayTheme.success.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(OverlayTheme.success.opacity(0.22)))
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
    }

    // MARK: - Computed Properties

    private var canStartIndexing: Bool {
        return !selectedRepoPath.isEmpty &&
               !isIndexing &&
               backendManager.isHealthy
    }

    // MARK: - Actions

    private func startIndexing() {
        guard !selectedRepoPath.isEmpty else { return }

        print("🚀 [INDEXING] Starting indexing for: \(selectedRepoPath)")
        isIndexing = true
        indexProgress = 0
        statusMessage = "Starting indexing..."
        lastIndexedCount = 0

        Task {
            do {
                // Simulate progress stages
                statusMessage = "Scanning repository..."
                indexProgress = 0.2

                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                statusMessage = "Analyzing files..."
                indexProgress = 0.4

                print("📡 [INDEXING] Calling API client...")
                let response = try await apiClient.indexRepository(
                    repoPath: selectedRepoPath,
                    mode: selectedIndexMode
                )

                statusMessage = "Generating embeddings..."
                indexProgress = 0.7

                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

                print("✅ [INDEXING] Indexing completed successfully")
                statusMessage = "Indexing complete!"
                indexProgress = 1.0

                // Get updated count from backend
                lastIndexedCount = response.chunksCreated

                // Reset after delay
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2s

                await MainActor.run {
                    isIndexing = false
                    statusMessage = ""
                }
            } catch {
                print("❌ [INDEXING] Error: \(error)")
                await MainActor.run {
                    statusMessage = "Error: \(error.localizedDescription)"
                    errorMessage = error.localizedDescription
                    showError = true
                    isIndexing = false
                }
            }
        }
    }
}

#if canImport(PreviewsMacros)
#Preview {
    IndexingView()
}
#endif
