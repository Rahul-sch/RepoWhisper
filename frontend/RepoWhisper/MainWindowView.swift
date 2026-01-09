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
    
    @State private var selectedTab = 0
    @State private var showingRepoManager = false
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                Label("Search", systemImage: "magnifyingglass")
                    .tag(0)
                Label("Repositories", systemImage: "folder.badge.gearshape")
                    .tag(1)
                Label("Boss Mode", systemImage: "crown.fill")
                    .tag(2)
                Label("Settings", systemImage: "gearshape")
                    .tag(3)
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
                        BossModeView()
                    case 3:
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
                
                // User info
                if let email = authManager.currentUser?.email {
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
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
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text("Voice-Powered Code Search")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Speak or type to search your repositories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Recording control
            VStack(spacing: 20) {
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
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: audioCapture.isRecording ? [.red.opacity(0.2), .red.opacity(0.1)] : [.purple.opacity(0.2), .blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: audioCapture.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(
                                    audioCapture.isRecording ?
                                    LinearGradient(colors: [.red], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(audioCapture.isRecording ? "Listening..." : "Start Voice Search")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Press ⌘⇧R or click to toggle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(24)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                )
                
                // Or divider
                HStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 100)
                
                // Text search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Type to search...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .frame(maxWidth: 500)
            }
            
            Spacer()
            
            // Quick stats
            if apiClient.indexCount > 0 {
                HStack(spacing: 30) {
                    StatBadge(
                        icon: "doc.text.fill",
                        value: "\(apiClient.indexCount)",
                        label: "Chunks Indexed"
                    )
                    
                    if searchLatency > 0 {
                        StatBadge(
                            icon: "bolt.fill",
                            value: "\(Int(searchLatency))ms",
                            label: "Last Search"
                        )
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        
        isSearching = true
        Task {
            do {
                let results = try await apiClient.search(query: searchQuery)
                await MainActor.run {
                    searchResults = results.results
                    searchLatency = results.latencyMs
                    isSearching = false
                    
                    // Show popup with results
                    popupManager.showPopup(
                        results: results.results,
                        query: searchQuery,
                        latency: results.latencyMs,
                        isRecording: audioCapture.isRecording
                    )
                }
            } catch {
                await MainActor.run {
                    isSearching = false
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

