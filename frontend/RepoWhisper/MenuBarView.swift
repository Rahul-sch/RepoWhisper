//
//  MenuBarView.swift
//  RepoWhisper
//
//  Main menu bar interface with recording controls and mode selection.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var audioCapture = AudioCapture.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var screenshotCapture = ScreenshotCapture.shared
    
    @State private var selectedMode: IndexMode = .guided
    @State private var showingFilePicker = false
    @State private var repoPath: String = ""
    @State private var lastTranscription: String = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var searchLatency: Double = 0
    @State private var isSearching = false
    @State private var showResults = false
    
    // Boss Mode state
    @State private var bossModeEnabled = false
    @State private var latestTalkingPoint: String = ""
    @State private var isGeneratingAdvice = false
    @State private var latestScreenshotBase64: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
        .frame(width: 320)
        .onAppear {
            setupAudioCallback()
            setupBossMode()
            Task {
                await apiClient.checkHealth()
            }
        }
    }
    
    // MARK: - Audio Callback Setup
    
    private func setupAudioCallback() {
        audioCapture.onAudioChunk = { audioData in
            Task {
                await transcribeAndSearch(audioData)
            }
        }
    }
    
    // MARK: - Boss Mode Setup
    
    private func setupBossMode() {
        // Screenshot callback
        screenshotCapture.onScreenshot = { screenshotData in
            Task {
                await processScreenshot(screenshotData)
            }
        }
    }
    
    private func processScreenshot(_ screenshotData: Data) async {
        do {
            // Upload and get base64
            let response = try await apiClient.uploadScreenshot(screenshotData)
            await MainActor.run {
                latestScreenshotBase64 = response.screenshotBase64
            }
            
            // Generate advice if we have transcript
            if !lastTranscription.isEmpty {
                await generateAdvice()
            }
        } catch {
            print("Screenshot processing error: \(error)")
        }
    }
    
    private func generateAdvice() async {
        guard !lastTranscription.isEmpty else { return }
        
        await MainActor.run {
            isGeneratingAdvice = true
        }
        
        do {
            // Extract code snippets from search results
            let codeSnippets = searchResults.prefix(3).map { $0.chunk }
            
            let advice = try await apiClient.getAdvice(
                transcript: lastTranscription,
                screenshotBase64: latestScreenshotBase64,
                codeSnippets: codeSnippets.isEmpty ? nil : Array(codeSnippets),
                meetingContext: "Code review meeting"
            )
            
            await MainActor.run {
                latestTalkingPoint = advice.talkingPoint
                isGeneratingAdvice = false
            }
        } catch {
            await MainActor.run {
                isGeneratingAdvice = false
            }
            print("Advice generation error: \(error)")
        }
    }
    
    private func transcribeAndSearch(_ audioData: Data) async {
        do {
            // Transcribe audio
            let transcription = try await apiClient.transcribe(audioData: audioData)
            
            await MainActor.run {
                lastTranscription = transcription.text
            }
            
            // Search if we have meaningful text
            if !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await MainActor.run {
                    isSearching = true
                    NotificationCenter.default.post(name: NSNotification.Name("SearchStarted"), object: nil)
                }
                
                let searchResponse = try await apiClient.search(query: transcription.text)
                
                await MainActor.run {
                    searchResults = searchResponse.results
                    searchLatency = searchResponse.latencyMs
                    isSearching = false
                    showResults = true
                    
                    // Post notification to show results window
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SearchResults"),
                        object: nil,
                        userInfo: [
                            "results": searchResponse.results,
                            "query": transcription.text,
                            "latency": searchResponse.latencyMs
                        ]
                    )
                }
                
                // Generate Boss Mode advice if enabled
                if bossModeEnabled {
                    await generateAdvice()
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Modern header with gradient
            ZStack {
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("RepoWhisper")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(apiClient.isConnected ? Color.green : Color.red)
                                    .frame(width: 6, height: 6)
                                Text(authManager.currentUser?.email ?? "")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        Task { await authManager.signOut() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Index Mode Selector - Modern card style
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("Index Mode")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Picker("Mode", selection: $selectedMode) {
                    Label("Manual", systemImage: "hand.tap")
                        .tag(IndexMode.manual)
                    Label("Guided", systemImage: "sparkles")
                        .tag(IndexMode.guided)
                    Label("Full Repo", systemImage: "folder")
                        .tag(IndexMode.full)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            
            // Repo Path - Modern card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Repository")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if apiClient.indexCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("\(apiClient.indexCount) chunks")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    TextField("Select a folder...", text: $repoPath)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .fileImporter(
                        isPresented: $showingFilePicker,
                        allowedContentTypes: [.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        if case .success(let urls) = result, let url = urls.first {
                            repoPath = url.path
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            .cornerRadius(10)
            .padding(.horizontal, 16)
            
            Divider()
            
            // Boss Mode Toggle
            bossModeToggle
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            Divider()
            
            // Recording Control - Cluely-style button
            recordingButton
                .padding(.horizontal, 16)
            
            // Status and Transcription
            if audioCapture.isRecording || !lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if audioCapture.isRecording {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                            Text("Listening...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    if !lastTranscription.isEmpty {
                        Text("\"" + lastTranscription + "\"")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .italic()
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Boss Mode Talking Point - Premium card
            if bossModeEnabled && !latestTalkingPoint.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                            
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                        
                        Text("Talking Point")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if isGeneratingAdvice {
                            ProgressView()
                                .scaleEffect(0.6)
                        }
                    }
                    
                    Text(latestTalkingPoint)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(12)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            }
            
            // Search Results Preview
            if showResults && !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Results")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(searchLatency))ms")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Button("View All") {
                            // Open results window
                            if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "results" }) {
                                window.makeKeyAndOrderFront(nil)
                            } else {
                                NSWorkspace.shared.open(URL(string: "repowhisper://results")!)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                    }
                    
                    ForEach(searchResults.prefix(3)) { result in
                        HStack {
                            Image(systemName: "doc.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(URL(fileURLWithPath: result.filePath).lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(result.score * 100))%")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        .padding(6)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(4)
                        .onTapGesture {
                            NSWorkspace.shared.open(URL(fileURLWithPath: result.filePath))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("⌘ + Shift + R to toggle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Settings...") {
                    // Open settings window
                    if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "settings" }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 380)
    }
    
    // MARK: - Boss Mode Toggle
    
    private var bossModeToggle: some View {
        Toggle(isOn: $bossModeEnabled) {
            HStack(spacing: 8) {
                Image(systemName: bossModeEnabled ? "crown.fill" : "crown")
                    .foregroundColor(bossModeEnabled ? .yellow : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Boss Mode")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Meeting intelligence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .toggleStyle(.switch)
        .onChange(of: bossModeEnabled) { oldValue, newValue in
            if newValue {
                Task {
                    // Request permissions and start
                    let screenGranted = await screenshotCapture.requestPermission()
                    if screenGranted {
                        await screenshotCapture.startCapture()
                    }
                }
            } else {
                screenshotCapture.stopCapture()
            }
        }
    }
    
    // MARK: - Recording Button
    
    private var recordingButton: some View {
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
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: audioCapture.isRecording ? [.red.opacity(0.2), .red.opacity(0.1)] : [.purple.opacity(0.2), .blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: audioCapture.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.title)
                        .foregroundStyle(
                            audioCapture.isRecording ?
                            LinearGradient(colors: [.red], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioCapture.isRecording ? "Stop Listening" : "Start Listening")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.caption2)
                        Text("⌘⇧R")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if audioCapture.isRecording {
                    // Modern audio level indicator
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    Float(i) / 5.0 < audioCapture.audioLevel ?
                                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 4, height: CGFloat(6 + i * 4))
                                .animation(.spring(response: 0.3), value: audioCapture.audioLevel)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        audioCapture.isRecording ?
                        LinearGradient(colors: [.red.opacity(0.6), .red.opacity(0.3)], startPoint: .top, endPoint: .bottom) :
                        LinearGradient(colors: [.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Unauthenticated View
    
    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            
            Text("Sign in to RepoWhisper")
                .font(.headline)
            
            Text("Connect your account to start voice-powered code search.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Login") {
                // Open results window
                if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "results" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(height: 200)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AuthManager.shared)
}
