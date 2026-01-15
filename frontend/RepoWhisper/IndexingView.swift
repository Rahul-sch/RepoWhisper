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
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Index Repository")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                }

                // Backend status indicator
                if !backendManager.isHealthy {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Backend not ready. Please wait...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Repository Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Select Repository", systemImage: "folder")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if bookmarkManager.approvedPaths.isEmpty {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.questionmark")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)

                                Text("No repositories approved")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("Go to the Repositories tab to add a folder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            Picker("Repository", selection: $selectedRepoPath) {
                                Text("Choose a repository...").tag("")
                                ForEach(bookmarkManager.approvedPaths, id: \.self) { path in
                                    HStack {
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                        Text("•").foregroundColor(.secondary)
                                        Text(path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(path)
                                }
                            }
                            .pickerStyle(.menu)

                            if !selectedRepoPath.isEmpty {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.blue)
                                    Text(selectedRepoPath)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                .padding(10)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

                    // Index Mode Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Indexing Mode", systemImage: "slider.horizontal.3")
                            .font(.headline)

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
                                .foregroundColor(.blue)
                            Text(selectedIndexMode.detailedDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

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
                        .padding()
                        .background(
                            LinearGradient(
                                colors: canStartIndexing ? [.green, .blue] : [.gray, .gray],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStartIndexing)
                    .opacity(canStartIndexing ? 1.0 : 0.5)

                    // Progress section
                    if isIndexing {
                        VStack(spacing: 12) {
                            ProgressView(value: indexProgress, total: 1.0)
                                .progressViewStyle(.linear)

                            HStack {
                                Image(systemName: "gearshape.2.fill")
                                    .foregroundColor(.blue)
                                Text(statusMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }

                    // Completion stats
                    if lastIndexedCount > 0 && !isIndexing {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Indexing Complete", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundColor(.green)

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
                        .background(Color.green.opacity(0.05))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
                try await apiClient.indexRepository(
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
                lastIndexedCount = backendManager.indexCount

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

#Preview {
    IndexingView()
}
