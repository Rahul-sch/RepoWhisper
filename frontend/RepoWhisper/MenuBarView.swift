//
//  MenuBarView.swift
//  RepoWhisper
//
//  Premium menu bar interface with ultra-minimalist glassmorphism design.
//  VC-backed quality: Cluely, Linear, Raycast aesthetic.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var audioCapture = AudioCapture.shared
    @StateObject private var apiClient = APIClient.shared
    @StateObject private var screenshotCapture = ScreenshotCapture.shared
    @StateObject private var popupManager = FloatingPopupManager.shared
    
    @State private var selectedMode: IndexMode = .smart
    @State private var showingRepoManager = false
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
        .frame(width: 360)
        .onAppear {
            setupAudioCallback()
            setupBossMode()
            Task { @MainActor in
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
        screenshotCapture.onScreenshot = { screenshotData in
            Task {
                await processScreenshot(screenshotData)
            }
        }
    }
    
    private func processScreenshot(_ screenshotData: Data) async {
        do {
            let response = try await apiClient.uploadScreenshot(screenshotData)
            await MainActor.run {
                latestScreenshotBase64 = response.screenshotBase64
            }
            
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
            let transcription = try await apiClient.transcribe(audioData: audioData)
            
            await MainActor.run {
                lastTranscription = transcription.text
            }
            
            if !transcription.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await MainActor.run {
                    isSearching = true
                    popupManager.showLoadingPopup(query: transcription.text, isRecording: audioCapture.isRecording)
                    NotificationCenter.default.post(name: NSNotification.Name("SearchStarted"), object: nil)
                }
                
                let searchResponse = try await apiClient.search(query: transcription.text)
                
                await MainActor.run {
                    searchResults = searchResponse.results
                    searchLatency = searchResponse.latencyMs
                    isSearching = false
                    showResults = true
                    
                    popupManager.showPopup(
                        results: searchResponse.results,
                        query: transcription.text,
                        latency: searchResponse.latencyMs,
                        isRecording: audioCapture.isRecording
                    )
                    
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
                
                if bossModeEnabled {
                    await generateAdvice()
                }
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - Authenticated View (Premium)
    
    private var authenticatedView: some View {
        VStack(spacing: 0) {
            // Premium header
            premiumHeader
            
            Divider()
                .background(Color.white.opacity(0.1))
                .padding(.horizontal, 20)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Recording control (premium)
                    premiumRecordingButton
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    
                    // Status section
                    if audioCapture.isRecording || !lastTranscription.isEmpty {
                        statusSection
                            .padding(.horizontal, 20)
                    }
                    
                    // Repository section
                    repositorySection
                        .padding(.horizontal, 20)
                    
                    // Boss Mode
                    bossModeSection
                        .padding(.horizontal, 20)
                    
                    // Talking point (if available)
                    if bossModeEnabled && !latestTalkingPoint.isEmpty {
                        talkingPointCard
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(
            // Premium glassmorphism background
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial)
        )
    }
    
    // MARK: - Premium Header
    
    private var premiumHeader: some View {
        HStack(spacing: 12) {
            // Logo
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.2),
                                Color.blue.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("RepoWhisper")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(apiClient.isConnected ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(authManager.currentUser?.email ?? "")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button {
                Task { await authManager.signOut() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Premium Recording Button
    
    private var premiumRecordingButton: some View {
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
                            audioCapture.isRecording ?
                            LinearGradient(
                                colors: [Color.red.opacity(0.2), Color.red.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: audioCapture.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(
                            audioCapture.isRecording ?
                            LinearGradient(colors: [.red], startPoint: .top, endPoint: .bottom) :
                            LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioCapture.isRecording ? "Stop Listening" : "Start Listening")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 10))
                        Text("⌘⇧R")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if audioCapture.isRecording {
                    // Premium audio level indicator
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(
                                    Float(i) / 5.0 < audioCapture.audioLevel ?
                                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(width: 3, height: CGFloat(6 + i * 3))
                                .animation(.spring(response: 0.2), value: audioCapture.audioLevel)
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        audioCapture.isRecording ?
                        LinearGradient(
                            colors: [Color.red.opacity(0.3), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if audioCapture.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: .red.opacity(0.5), radius: 4)
                    
                    Text("Listening...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            if !lastTranscription.isEmpty {
                Text("\"" + lastTranscription + "\"")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.primary)
                    .italic()
                    .lineLimit(2)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
            }
        }
    }
    
    // MARK: - Repository Section
    
    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Repository", systemImage: "folder.fill")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if apiClient.indexCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text("\(apiClient.indexCount)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
            }
            
            Button {
                showingRepoManager = true
            } label: {
                HStack {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.system(size: 13, weight: .medium))
                    Text("Manage Repositories")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .foregroundColor(.white)
                .padding(14)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingRepoManager) {
                RepoManagerView()
            }
        }
    }
    
    // MARK: - Boss Mode Section
    
    private var bossModeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $bossModeEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: bossModeEnabled ? "crown.fill" : "crown")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(bossModeEnabled ? Color(red: 0.98, green: 0.80, blue: 0.36) : .secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Boss Mode")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Text("Meeting intelligence")
                            .font(.system(size: 11, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(.switch)
            .onChange(of: bossModeEnabled) { oldValue, newValue in
                if newValue {
                    Task {
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
    
    // MARK: - Talking Point Card
    
    private var talkingPointCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.80, blue: 0.36).opacity(0.3),
                                    Color(red: 0.96, green: 0.65, blue: 0.38).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(red: 0.98, green: 0.80, blue: 0.36))
                }
                
                Text("Talking Point")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                
                Spacer()
                
                if isGeneratingAdvice {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            
            Text(latestTalkingPoint)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.98, green: 0.80, blue: 0.36).opacity(0.12),
                                    Color(red: 0.96, green: 0.65, blue: 0.38).opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(red: 0.98, green: 0.80, blue: 0.36).opacity(0.2), lineWidth: 0.5)
                )
        }
    }
    
    // MARK: - Unauthenticated View (Premium)
    
    private var unauthenticatedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
            Text("Sign in to RepoWhisper")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            
            Text("Connect your account to start voice-powered code search.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            }
            
            Button("Open Login") {
                if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "login" }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(32)
        .frame(height: 280)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AuthManager.shared)
}
