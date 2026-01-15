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
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .listStyle(.sidebar)
        } detail: {
            // Main content area
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.05),
                        Color.blue.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
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
                        .fill(apiClient.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(apiClient.isConnected ? "Connected" : "Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // User info - local mode
                Text("Local User")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
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

    @State private var searchQuery = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var isSearching = false
    @State private var searchLatency: Double = 0
    @State private var copiedResultId: String?
    @State private var showAudioFilePicker = false
    @State private var isTranscribing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with search bar
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Search")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()

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
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
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
                            Task {
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
                                    LinearGradient(colors: [.red], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            Text(audioCapture.isRecording ? "Stop" : "Voice")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search your code...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit { performSearch() }

                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !searchQuery.isEmpty {
                        Button(action: performSearch) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(10)

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
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

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
                        .foregroundColor(.blue)

                    Text(URL(fileURLWithPath: result.filePath).lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("Lines \(result.lineStart)-\(result.lineEnd)")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                .foregroundColor(.orange)
            }

            // Code snippet
            ScrollView(.horizontal, showsIndicators: false) {
                Text(result.chunk)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(6)
            }

            // File path
            Text(result.filePath)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
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
                    .foregroundColor(copiedResultId == result.id ? .green : .blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
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
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
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
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }

    // MARK: - Actions

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        print("🔍 [SEARCH] Starting search for: '\(searchQuery)'")
        isSearching = true
        searchResults = []

        Task {
            do {
                print("📡 [SEARCH] Calling API...")
                let results = try await apiClient.search(query: searchQuery)
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

