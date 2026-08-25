//
//  MainWindowView.swift
//  RepoWhisper
//
//  Main application window with beautiful UI.
//

import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var audioCapture = AudioCapture.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var popupManager = FloatingPopupManager.shared
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @StateObject private var backendManager = BackendProcessManager.shared

    @State private var selectedTab = 0
    @State private var showingRepoManager = false
    @State private var showingOnboarding = false

    var body: some View {
        // Show onboarding if no repositories approved
        if bookmarkManager.approvedPaths.isEmpty && !showingOnboarding {
            OnboardingView {
                showingOnboarding = false
            }
            .onAppear {
                showingOnboarding = true
            }
        } else {
            mainContent
        }
    }

    var mainContent: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                Label("Search", systemImage: "magnifyingglass")
                    .tag(0)
                Label("Repositories", systemImage: "folder.badge.gearshape")
                    .tag(1)
                Label("Indexing", systemImage: "arrow.triangle.2.circlepath")
                    .tag(2)
                Label("Boss Mode", systemImage: "crown.fill")
                    .tag(3)
                Label("Settings", systemImage: "gearshape")
                    .tag(4)
            }
            .foregroundStyle(OverlayTheme.textSecondary)
            .tint(OverlayTheme.accent)
            .scrollContentBackground(.hidden)
            .background(OverlayTheme.canvas)
            .navigationSplitViewColumnWidth(min: 176, ideal: 192, max: 220)
            .listStyle(.sidebar)
        } detail: {
            // Main content area
            ZStack {
                OverlayTheme.canvas.ignoresSafeArea()
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case 0:
                        SearchView()
                    case 1:
                        RepoManagerView()
                    case 2:
                        IndexingView()
                    case 3:
                        BossModeView()
                    case 4:
                        SettingsView()
                    default:
                        SearchView()
                    }
                }
                .environmentObject(authManager)
            }
        }
        .navigationTitle("RepoWhisper")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Connection status
                HStack(spacing: 6) {
                    Circle()
                        .fill(backendManager.isHealthy ? OverlayTheme.success : OverlayTheme.danger)
                        .frame(width: 8, height: 8)
                    Text(backendManager.isHealthy ? "Connected" : backendManager.statusMessage)
                        .font(.caption)
                        .foregroundStyle(OverlayTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Divider()
                
                // User info - local mode
                Text("Local User")
                    .font(.caption)
                    .foregroundStyle(OverlayTheme.textSecondary)
                
                // Sign out button
                Button(action: {
                    Task { await authManager.signOut() }
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
                .help("Sign Out")
            }
        }
    }
}

// MARK: - Search View

struct SearchView: View {
    @StateObject private var audioCapture = AudioCapture.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var popupManager = FloatingPopupManager.shared
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @StateObject private var explainCoordinator = ExplainVisibleCoordinator.shared

    @State private var searchQuery = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching = false
    @State private var searchLatency: Double = 0
    @State private var copiedResultId: String?
    @State private var showAudioFilePicker = false
    @State private var isTranscribing = false
    @State private var selectedRepoPath: String?
    @State private var searchError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header with search bar
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(OverlayTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ask RepoWhisper")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(OverlayTheme.textPrimary)
                        Text("Search code, explain context, or listen live")
                            .font(.system(size: 11))
                            .foregroundStyle(OverlayTheme.textSecondary)
                    }
                    Spacer()

                    Button {
                        popupManager.centerAndShow()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "macwindow.on.rectangle")
                            Text("Floating Display")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(OverlayTheme.textSecondary)
                        .background(OverlayTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Open and center the floating display (⌘⇧Space)")

                    Button {
                        Task { await explainCoordinator.explain() }
                    } label: {
                        HStack(spacing: 6) {
                            if explainCoordinator.isWorking {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(explainCoordinator.isWorking ? "Explaining" : "Explain Visible")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(OverlayTheme.accent)
                        .background(OverlayTheme.accent.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(explainCoordinator.isWorking)
                    .help("Capture and explain the visible function (⌘⇧E)")

                    // Audio file upload button
                    Button {
                        showAudioFilePicker = true
                    } label: {
                        HStack(spacing: 6) {
                            if isTranscribing {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "waveform.circle.fill")
                                    .foregroundStyle(
                                        LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }
                            Text(isTranscribing ? "Transcribing" : "Upload")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(OverlayTheme.textSecondary)
                        .background(OverlayTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTranscribing)
                    .fileImporter(
                        isPresented: $showAudioFilePicker,
                        allowedContentTypes: [.audio],
                        allowsMultipleSelection: false
                    ) { result in
                        handleAudioFileSelection(result)
                    }

                    // Voice button (compact)
                    Button {
                        if audioCapture.isRecording {
                            audioCapture.stopRecording()
                        } else {
                            Task { @MainActor in
                                if SecurityScopedBookmarkManager.shared.approvedPaths.isEmpty {
                                    FloatingPopupManager.shared.showErrorToast("Add a repository folder first.")
                                    return
                                }
                                if !BackendProcessManager.shared.isRunning {
                                    FloatingPopupManager.shared.showErrorToast("Starting backend…")
                                    do { try await BackendProcessManager.shared.start() }
                                    catch {
                                        FloatingPopupManager.shared.showErrorToast(
                                            "Backend failed: \(error.localizedDescription)"
                                        )
                                        return
                                    }
                                }
                                let granted = await audioCapture.requestPermission()
                                if granted {
                                    audioCapture.startRecording()
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: audioCapture.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundStyle(
                                    audioCapture.isRecording ?
                                    LinearGradient(colors: [OverlayTheme.danger], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [OverlayTheme.accent], startPoint: .top, endPoint: .bottom)
                                )
                            Text(audioCapture.isRecording ? "Stop" : "Voice")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(audioCapture.isRecording ? OverlayTheme.danger : OverlayTheme.textSecondary)
                        .background(audioCapture.isRecording ? OverlayTheme.danger.opacity(0.12) : OverlayTheme.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(OverlayTheme.accent)

                    TextField("Ask anything about your repository…", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundStyle(OverlayTheme.textPrimary)
                        .onSubmit { performSearch() }

                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(OverlayTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !searchQuery.isEmpty {
                        Button(action: performSearch) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(OverlayTheme.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(OverlayTheme.elevated)
                .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: OverlayTheme.controlRadius, style: .continuous)
                        .stroke(OverlayTheme.border, lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                    Text("Search in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Repository", selection: $selectedRepoPath) {
                        Text("All repositories").tag(nil as String?)
                        ForEach(bookmarkManager.approvedPaths, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .tag(path as String?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240)
                    Spacer()
                }

                // Stats row
                if searchLatency > 0 || apiClient.indexCount > 0 {
                    HStack(spacing: 20) {
                        if apiClient.indexCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption2)
                                Text("\(apiClient.indexCount) chunks")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }

                        if searchLatency > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption2)
                                Text("\(Int(searchLatency))ms")
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }

                        if !searchResults.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                Text("\(searchResults.count) results")
                                    .font(.caption)
                            }
                            .foregroundColor(.green)
                        }

                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(OverlayTheme.canvas)

            // Results or empty state
            if searchResults.isEmpty && !isSearching {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: searchQuery.isEmpty ? "magnifyingglass" : "doc.text.magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text(searchQuery.isEmpty ? "Search Your Code" : "No Results Found")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)

                    Text(searchQuery.isEmpty ?
                         "Type a query or use voice search to find code" :
                         "Try a different search query"
                    )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()
                }
            } else {
                // Results list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(searchResults.enumerated()), id: \.element.id) { index, result in
                            searchResultRow(result: result, index: index)
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("Search Failed", isPresented: Binding(
            get: { searchError != nil },
            set: { if !$0 { searchError = nil } }
        )) {
            Button("OK", role: .cancel) { searchError = nil }
        } message: {
            Text(searchError ?? "The backend could not complete the search.")
        }
    }

    // MARK: - Search Result Row

    @ViewBuilder
    private func searchResultRow(result: SearchResultItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: file path + line numbers
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundStyle(OverlayTheme.accent)

                    Text(URL(fileURLWithPath: result.filePath).lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(OverlayTheme.textPrimary)

                    Text("•")
                        .foregroundStyle(OverlayTheme.textSecondary)

                    Text("Lines \(result.lineStart)-\(result.lineEnd)")
                        .font(.caption)
                        .foregroundStyle(OverlayTheme.textSecondary)
                }

                Spacer()

                // Score badge
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    Text(String(format: "%.0f%%", result.score * 100))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(OverlayTheme.success)
            }

            // Code snippet
            ScrollView(.horizontal, showsIndicators: false) {
                Text(result.chunk)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(OverlayTheme.textPrimary.opacity(0.86))
                    .padding(10)
                    .background(OverlayTheme.canvas.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // File path
            Text(result.filePath)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(OverlayTheme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // Action buttons
            HStack(spacing: 12) {
                // Copy
                Button(action: { copyToClipboard(result) }) {
                    HStack(spacing: 4) {
                        Image(systemName: copiedResultId == result.id ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(copiedResultId == result.id ? "Copied" : "Copy")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(copiedResultId == result.id ? OverlayTheme.success : OverlayTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OverlayTheme.hover)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await explainCoordinator.explain(selectedText: result.chunk) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.caption)
                        Text("Explain").font(.caption).fontWeight(.medium)
                    }
                    .foregroundStyle(OverlayTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OverlayTheme.accent.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                // Open in Finder
                Button(action: { openInFinder(result) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption)
                        Text("Finder")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(OverlayTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OverlayTheme.hover)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                // Open in editor
                Button(action: { openInEditor(result) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                        Text("Editor")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(OverlayTheme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(OverlayTheme.hover)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding()
        .background(OverlayTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(OverlayTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        print("🔍 [SEARCH] Starting search for: '\(searchQuery)'")
        isSearching = true
        searchResults = []
        searchError = nil

        Task {
            do {
                print("📡 [SEARCH] Calling API...")
                let results = try await apiClient.search(
                    query: searchQuery,
                    repoPath: selectedRepoPath
                )
                print("✅ [SEARCH] Got \(results.results.count) results")

                await MainActor.run {
                    searchResults = results.results
                    searchLatency = results.latencyMs
                    isSearching = false
                }
            } catch {
                print("❌ [SEARCH] Search error: \(error)")
                await MainActor.run {
                    isSearching = false
                    searchError = error.localizedDescription
                }
            }
        }
    }

    private func copyToClipboard(_ result: SearchResultItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.chunk, forType: .string)

        copiedResultId = result.id

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedResultId == result.id {
                copiedResultId = nil
            }
        }
    }

    private func openInFinder(_ result: SearchResultItem) {
        let url = URL(fileURLWithPath: result.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func openInEditor(_ result: SearchResultItem) {
        let url = URL(fileURLWithPath: result.filePath)
        NSWorkspace.shared.open(url)
    }

    private func handleAudioFileSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let audioURL = urls.first else {
            return
        }

        isTranscribing = true

        Task {
            do {
                // Read audio file data
                let audioData = try Data(contentsOf: audioURL)

                print("🎙️ [AUDIO] Transcribing audio file: \(audioURL.lastPathComponent)")

                // Call transcribe endpoint
                let result = try await apiClient.transcribe(audioData: audioData)

                print("✅ [AUDIO] Transcription complete: \(result.text)")

                // Fill search query and trigger search
                await MainActor.run {
                    searchQuery = result.text
                    isTranscribing = false

                    // Auto-trigger search
                    performSearch()
                }
            } catch {
                print("❌ [AUDIO] Transcription error: \(error)")
                await MainActor.run {
                    isTranscribing = false
                }
            }
        }
    }
}

// MARK: - Boss Mode View

struct BossModeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("Boss Mode")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Meeting intelligence and screen awareness")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Coming soon...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

#Preview {
    MainWindowView()
        .environmentObject(AuthManager.shared)
}
