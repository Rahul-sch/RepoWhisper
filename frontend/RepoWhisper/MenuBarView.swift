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
    
    @State private var selectedMode: IndexMode = .guided
    @State private var showingFilePicker = false
    @State private var repoPath: String = ""
    @State private var lastTranscription: String = ""
    @State private var searchResults: [SearchResultItem] = []
    @State private var searchLatency: Double = 0
    @State private var isSearching = false
    @State private var showResults = false
    
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
            }
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RepoWhisper")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(apiClient.isConnected ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(authManager.currentUser?.email ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button {
                    Task { await authManager.signOut() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
            
            // Index Mode Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Index Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Mode", selection: $selectedMode) {
                    Label("Manual", systemImage: "hand.tap")
                        .tag(IndexMode.manual)
                    Label("Guided", systemImage: "sparkles")
                        .tag(IndexMode.guided)
                    Label("Full Repo", systemImage: "folder")
                        .tag(IndexMode.full)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            
            // Repo Path
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Repository")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(apiClient.indexCount) chunks")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                
                HStack {
                    TextField("Select a folder...", text: $repoPath)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                    
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
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
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 380)
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
            HStack(spacing: 12) {
                Image(systemName: audioCapture.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(audioCapture.isRecording ? .red : .purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioCapture.isRecording ? "Stop Listening" : "Start Listening")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Click or use ⌘⇧R")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if audioCapture.isRecording {
                    // Audio level indicator
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Float(i) / 5.0 < audioCapture.audioLevel ? Color.purple : Color.gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat(4 + i * 3))
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(audioCapture.isRecording ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
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
                NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
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
