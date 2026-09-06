//
//  MainWindowView.swift
//  RepoWhisper
//
//  Main application window with beautiful UI.
//

import SwiftUI
import UniformTypeIdentifiers

struct MainWindowView: View {
    @StateObject private var audioCapture = AudioCapture.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var popupManager = FloatingPopupManager.shared
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @StateObject private var backendManager = BackendProcessManager.shared

    @State private var selectedTab: RWNavigation = .search
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
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    RWBrandMark(size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("RepoWhisper")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(RWTheme.text)
                        Text("Local code intelligence")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(RWTheme.textFaint)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 62)

                List(selection: $selectedTab) {
                    Section("WORKSPACE") {
                        ForEach(RWNavigation.allCases.filter { $0 != .settings }) { item in
                            RWSidebarRow(item: item, isSelected: selectedTab == item)
                                .tag(item)
                        }
                    }
                    Section("APP") {
                        RWSidebarRow(item: .settings, isSelected: selectedTab == .settings)
                            .tag(RWNavigation.settings)
                    }
                }
                .foregroundStyle(RWTheme.textMuted)
                .tint(RWTheme.accent)
                .scrollContentBackground(.hidden)
                .listStyle(.sidebar)

                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                    Text("Local only")
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                    RWKeycap(keys: "⌘⇧R")
                }
                .foregroundStyle(RWTheme.textFaint)
                .padding(14)
            }
            .background(RWTheme.canvasRaised.opacity(0.96))
            .navigationSplitViewColumnWidth(min: 188, ideal: 204, max: 224)
        } detail: {
            ZStack {
                RWAmbientBackground()
                
                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .search:
                        SearchView()
                    case .repositories:
                        RepoManagerView()
                    case .indexing:
                        IndexingView()
                    case .live:
                        BossModeView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
        }
        .navigationTitle(selectedTab.title)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                RWStatusPill(
                    title: backendManager.isHealthy ? "Ready" : backendManager.statusMessage,
                    color: backendManager.isHealthy ? RWTheme.success : RWTheme.warning
                )
                .help(backendManager.isHealthy ? "Local backend is healthy" : backendManager.statusMessage)
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
                RWPageHeader(
                    eyebrow: "Code intelligence",
                    title: "Ask your codebase",
                    subtitle: "Find implementation details, trace behavior, or explain what is on screen."
                ) {
                    HStack(spacing: 8) {
                        Button { popupManager.centerAndShow() } label: {
                            Label("Overlay", systemImage: "macwindow.on.rectangle")
                        }
                        .buttonStyle(RWSecondaryButtonStyle())
                        .help("Open floating display · ⌘⇧Space")

                        Button { Task { await explainCoordinator.explain() } } label: {
                            Label(explainCoordinator.isWorking ? "Explaining" : "Explain", systemImage: "viewfinder")
                        }
                        .buttonStyle(RWSecondaryButtonStyle())
                        .disabled(explainCoordinator.isWorking)
                        .help("Explain visible code · ⌘⇧E")
                    }
                }

                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(RWTheme.accentBright)

                    TextField("Ask anything about your repository…", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(RWTheme.text)
                        .onSubmit { performSearch() }

                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(RWTheme.textFaint)
                        }
                        .buttonStyle(.plain)
                    }

                    Button { showAudioFilePicker = true } label: {
                        Image(systemName: isTranscribing ? "hourglass" : "paperclip")
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(RWTheme.textMuted)
                    .disabled(isTranscribing)
                    .help("Transcribe an audio file")
                    .fileImporter(
                        isPresented: $showAudioFilePicker,
                        allowedContentTypes: [.audio],
                        allowsMultipleSelection: false,
                        onCompletion: handleAudioFileSelection
                    )

                    Button(action: toggleVoiceRecording) {
                        Image(systemName: audioCapture.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(audioCapture.isRecording ? RWTheme.danger : RWTheme.textMuted)
                            .frame(width: 28, height: 28)
                            .background(
                                (audioCapture.isRecording ? RWTheme.danger : RWTheme.surfaceStrong).opacity(0.16),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .help(audioCapture.isRecording ? "Stop recording" : "Start voice search")

                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !searchQuery.isEmpty {
                        Button(action: performSearch) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(RWTheme.accentGradient, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 15)
                .frame(height: 52)
                .rwGlass(radius: 16, emphasized: true)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("search.composer")

                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(RWTheme.accentBright)
                    Text("Scope")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RWTheme.textMuted)
                    Picker("Repository", selection: $selectedRepoPath) {
                        Text("All repositories").tag(nil as String?)
                        ForEach(bookmarkManager.approvedPaths, id: \.self) { path in
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                                .tag(path as String?)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(maxWidth: 220)
                    Spacer()
                    RWKeycap(keys: "↩")
                }
                .padding(.horizontal, 4)

                // Stats row
                if searchLatency > 0 || apiClient.indexCount > 0 {
                    HStack(spacing: 8) {
                        if apiClient.indexCount > 0 {
                            RWMetricChip(symbol: "doc.text", value: "\(apiClient.indexCount)", label: "chunks")
                        }

                        if searchLatency > 0 {
                            RWMetricChip(symbol: "bolt.fill", value: "\(Int(searchLatency))ms", label: "latency")
                        }

                        if !searchResults.isEmpty {
                            RWMetricChip(
                                symbol: "checkmark.circle.fill",
                                value: "\(searchResults.count)",
                                label: "results",
                                tint: RWTheme.success
                            )
                        }

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, RWTheme.pagePadding)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Results or empty state
            if searchResults.isEmpty && !isSearching {
                VStack {
                    Spacer()
                    RWEmptyState(
                        symbol: searchQuery.isEmpty ? "text.magnifyingglass" : "doc.text.magnifyingglass",
                        title: searchQuery.isEmpty ? "Ready when you are" : "Nothing matched",
                        message: searchQuery.isEmpty
                            ? "Ask in plain language, attach audio, or use the microphone to search your indexed repositories."
                            : "Try a broader phrase or switch the repository scope."
                    )
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
                    .padding(.horizontal, RWTheme.pagePadding)
                    .padding(.bottom, RWTheme.pagePadding)
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
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(RWTheme.accentBright)
                        .frame(width: 26, height: 26)
                        .background(RWTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))

                    Text(URL(fileURLWithPath: result.filePath).lastPathComponent)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(OverlayTheme.textPrimary)

                    Text("L\(result.lineStart)–\(result.lineEnd)")
                        .font(.caption)
                        .foregroundStyle(RWTheme.textFaint)
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
                .foregroundStyle(RWTheme.success)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(RWTheme.success.opacity(0.09), in: Capsule())
            }

            // Code snippet
            ScrollView(.horizontal, showsIndicators: false) {
                Text(result.chunk)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(RWTheme.text.opacity(0.84))
                    .padding(12)
                    .background(Color.black.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
        .padding(16)
        .rwGlass(radius: 15)
        .accessibilityIdentifier("search.result.\(index)")
    }

    // MARK: - Actions

    private func toggleVoiceRecording() {
        if audioCapture.isRecording {
            audioCapture.stopRecording()
            return
        }
        Task { @MainActor in
            guard !bookmarkManager.approvedPaths.isEmpty else {
                popupManager.showErrorToast("Add a repository folder first.")
                return
            }
            if !BackendProcessManager.shared.isRunning {
                popupManager.showErrorToast("Starting backend…")
                do { try await BackendProcessManager.shared.start() }
                catch {
                    popupManager.showErrorToast("Backend failed: \(error.localizedDescription)")
                    return
                }
            }
            if await audioCapture.requestPermission() {
                audioCapture.startRecording()
            }
        }
    }

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
                let hasScopedAccess = audioURL.startAccessingSecurityScopedResource()
                defer {
                    if hasScopedAccess { audioURL.stopAccessingSecurityScopedResource() }
                }
                let values = try audioURL.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
                if let fileSize = values.fileSize, fileSize > 50 * 1024 * 1024 {
                    throw APIError.serverError("Audio files must be 50 MB or smaller.")
                }
                // Read audio file data
                let audioData = try Data(contentsOf: audioURL)

                print("🎙️ [AUDIO] Transcribing audio file: \(audioURL.lastPathComponent)")

                // Call transcribe endpoint
                let contentType = values.contentType?.preferredMIMEType ?? "application/octet-stream"
                let result = try await apiClient.transcribeFile(
                    audioData: audioData,
                    contentType: contentType
                )

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
        VStack(spacing: 14) {
            Image(systemName: "person.wave.2.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OverlayTheme.accent)
                .frame(width: 48, height: 48)
                .background(OverlayTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            
            Text("Boss Mode")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(OverlayTheme.textPrimary)
            
            Text("Live meeting intelligence and screen-aware answers")
                .font(.system(size: 13))
                .foregroundStyle(OverlayTheme.textSecondary)
            
            Label("Configure and start from the menu bar", systemImage: "menubar.rectangle")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(OverlayTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(OverlayTheme.elevated, in: RoundedRectangle(cornerRadius: 9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OverlayTheme.canvas)
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
            .foregroundStyle(OverlayTheme.textPrimary)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(OverlayTheme.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(OverlayTheme.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(OverlayTheme.border, lineWidth: 1)
        )
    }
}

#if canImport(PreviewsMacros)
#Preview {
    MainWindowView()
}
#endif
