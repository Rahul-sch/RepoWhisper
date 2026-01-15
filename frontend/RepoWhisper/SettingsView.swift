//
//  SettingsView.swift
//  RepoWhisper
//
//  Settings window for configuring the app.
//  Includes index mode selection, file patterns, and account settings.
//

import SwiftUI
import UniformTypeIdentifiers

/// Settings window view
struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var apiClient = APIClient.shared
    
    @AppStorage("indexMode") private var indexMode: String = "smart"
    @AppStorage("repoPath") private var repoPath: String = ""
    @AppStorage("smartPatterns") private var smartPatterns: String = "*.py, *.swift, *.ts"
    @AppStorage("manualFiles") private var manualFiles: String = ""
    
    @State private var isIndexing = false
    @State private var indexMessage = ""
    @State private var showFilePicker = false
    @State private var showFolderPicker = false
    
    var body: some View {
        TabView {
            // Index Settings Tab
            indexSettingsTab
                .tabItem {
                    Label("Indexing", systemImage: "doc.text.magnifyingglass")
                }
            
            // Account Tab
            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
            
            // About Tab
            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 500, height: 400)
    }
    
    // MARK: - Index Settings Tab
    
    private var indexSettingsTab: some View {
        Form {
            // Repository Path
            Section("Repository") {
                HStack {
                    TextField("Repository Path", text: $repoPath)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Browse") {
                        showFolderPicker = true
                    }
                }
                .fileImporter(
                    isPresented: $showFolderPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        repoPath = url.path
                    }
                }
            }
            
            // Index Mode Selection
            Section("Index Mode") {
                Picker("Mode", selection: $indexMode) {
                    Label("Manual - Select specific files", systemImage: "hand.tap")
                        .tag("manual")
                    Label("Smart - File patterns", systemImage: "sparkles")
                        .tag("smart")
                    Label("Full - Entire repository", systemImage: "folder")
                        .tag("full")
                }
                .pickerStyle(.radioGroup)
                
                // Mode-specific options
                switch indexMode {
                case "manual":
                    manualModeOptions
                case "smart":
                    smartModeOptions
                case "full":
                    fullModeOptions
                default:
                    EmptyView()
                }
            }
            
            // Index Action
            Section {
                HStack {
                    Button(action: startIndexing) {
                        HStack {
                            if isIndexing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            Text(isIndexing ? "Indexing..." : "Start Indexing")
                        }
                    }
                    .disabled(repoPath.isEmpty || isIndexing)
                    
                    Spacer()
                    
                    if !indexMessage.isEmpty {
                        Text(indexMessage)
                            .font(.caption)
                            .foregroundColor(indexMessage.contains("Error") ? .red : .green)
                    }
                    
                    Text("\(apiClient.indexCount) chunks indexed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private var manualModeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Selected Files:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $manualFiles)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 60)
                .border(Color.secondary.opacity(0.3))
            
            HStack {
                Button("Add Files...") {
                    showFilePicker = true
                }
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.sourceCode, .plainText],
                    allowsMultipleSelection: true
                ) { result in
                    if case .success(let urls) = result {
                        let paths = urls.map { $0.path }
                        manualFiles = (manualFiles.isEmpty ? "" : manualFiles + "\n") + paths.joined(separator: "\n")
                    }
                }
                
                Button("Clear") {
                    manualFiles = ""
                }
            }
            
            Text("One file path per line")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var smartModeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File Patterns (comma-separated):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("*.py, *.swift, *.ts", text: $smartPatterns)
                .textFieldStyle(.roundedBorder)
            
            Text("Examples: *.py, src/**/*.ts, tests/*.swift")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var fullModeOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Will index all supported file types:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(".py, .swift, .js, .ts, .tsx, .jsx, .go, .rs, .java, .kt, .cpp, .c, .h, .md")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
            
            Text("⚠️ Large repositories may take longer to index")
                .font(.caption2)
                .foregroundColor(.orange)
        }
    }
    
    // MARK: - Account Tab
    
    private var accountTab: some View {
        Form {
            if authManager.isAuthenticated {
                Section("Signed In") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text("Local User")
                                .fontWeight(.medium)
                            Text("No authentication required")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Button("Sign Out", role: .destructive) {
                        Task {
                            await authManager.signOut()
                        }
                    }
                }
            } else {
                Section("Not Signed In") {
                    Text("Sign in to sync your settings and indexed repositories.")
                        .foregroundColor(.secondary)
                    
                    Button("Open Login Window") {
                        // Open login window via window group
                        if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "login" }) {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                }
            }
            
            Section("Backend Status") {
                HStack {
                    Circle()
                        .fill(apiClient.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(apiClient.isConnected ? "Connected" : "Disconnected")
                    
                    Spacer()
                    
                    Button("Check") {
                        Task {
                            await apiClient.checkHealth()
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    // MARK: - About Tab
    
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("RepoWhisper")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Voice-powered code search")
                .foregroundColor(.secondary)
            
            Text("Version 0.1.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("FastAPI + Faster-Whisper backend", systemImage: "server.rack")
                Label("LanceDB vector search", systemImage: "magnifyingglass")
                Label("MiniLM embeddings", systemImage: "brain")
                Label("< 500ms latency target", systemImage: "bolt.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
            
            Link("View on GitHub", destination: URL(string: "https://github.com/Rahul-sch/RepoWhisper")!)
                .font(.caption)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func startIndexing() {
        guard !repoPath.isEmpty else { return }
        
        isIndexing = true
        indexMessage = ""
        
        Task {
            do {
                let mode: IndexMode
                var filePaths: [String]? = nil
                var patterns: [String]? = nil
                
                switch indexMode {
                case "manual":
                    mode = .manual
                    filePaths = manualFiles.split(separator: "\n").map(String.init)
                case "smart":
                    mode = .smart
                    patterns = smartPatterns.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                default:
                    mode = .full
                }
                
                let response = try await apiClient.indexRepository(
                    repoPath: repoPath,
                    mode: mode,
                    filePaths: filePaths,
                    patterns: patterns
                )
                
                indexMessage = "✓ \(response.filesIndexed) files, \(response.chunksCreated) chunks"
            } catch {
                indexMessage = "Error: \(error.localizedDescription)"
            }
            
            isIndexing = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}

