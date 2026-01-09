//
//  RepoManagerView.swift
//  RepoWhisper
//
//  Repository selection and management view with file picker.
//

import SwiftUI
import AppKit

struct RepoManagerView: View {
    @State private var selectedRepoPath: String = ""
    @State private var indexedRepos: [IndexedRepo] = []
    @State private var isIndexing = false
    @State private var indexProgress: Double = 0
    @State private var statusMessage: String = ""
    @State private var selectedIndexMode: IndexMode = .smart
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "folder.badge.gearshape")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("Repository Manager")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // File Selection Card
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Select Repository", systemImage: "folder")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Selected path display
                        if !selectedRepoPath.isEmpty {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text(selectedRepoPath)
                                    .font(.system(.body, design: .monospaced))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Choose folder button
                        Button(action: selectFolder) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                Text(selectedRepoPath.isEmpty ? "Choose Folder..." : "Change Folder")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
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
                                VStack(alignment: .leading) {
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
                                Text("Index Repository")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isIndexing ? Color.gray :
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedRepoPath.isEmpty || isIndexing)
                    .opacity(selectedRepoPath.isEmpty ? 0.5 : 1.0)
                    
                    // Progress bar
                    if isIndexing {
                        VStack(spacing: 8) {
                            ProgressView(value: indexProgress, total: 1.0)
                                .progressViewStyle(.linear)
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Indexed Repositories List
                    if !indexedRepos.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Indexed Repositories", systemImage: "list.bullet.rectangle")
                                .font(.headline)
                            
                            ForEach(indexedRepos) { repo in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(repo.name)
                                            .fontWeight(.medium)
                                        Text(repo.path)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Text("\(repo.fileCount) files • Indexed \(repo.lastIndexed.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: { deleteRepo(repo) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            loadIndexedRepos()
        }
    }
    
    // MARK: - Actions
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a repository folder to index"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedRepoPath = url.path
        }
    }
    
    private func startIndexing() {
        guard !selectedRepoPath.isEmpty else { return }
        
        isIndexing = true
        indexProgress = 0
        statusMessage = "Starting indexing..."
        
        Task {
            do {
                // Call backend to index the repository
                let apiClient = APIClient.shared
                statusMessage = "Scanning files..."
                indexProgress = 0.3
                
                try await apiClient.indexRepository(
                    path: selectedRepoPath,
                    mode: selectedIndexMode
                )
                
                statusMessage = "Indexing complete!"
                indexProgress = 1.0
                
                // Add to indexed repos
                let newRepo = IndexedRepo(
                    name: URL(fileURLWithPath: selectedRepoPath).lastPathComponent,
                    path: selectedRepoPath,
                    fileCount: 0, // TODO: Get actual count from backend
                    lastIndexed: Date()
                )
                indexedRepos.insert(newRepo, at: 0)
                saveIndexedRepos()
                
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isIndexing = false
                    statusMessage = ""
                }
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                isIndexing = false
            }
        }
    }
    
    private func deleteRepo(_ repo: IndexedRepo) {
        indexedRepos.removeAll { $0.id == repo.id }
        saveIndexedRepos()
    }
    
    private func loadIndexedRepos() {
        // TODO: Load from UserDefaults or backend
    }
    
    private func saveIndexedRepos() {
        // TODO: Save to UserDefaults or backend
    }
}

// MARK: - Models

struct IndexedRepo: Identifiable, Codable {
    var id = UUID()
    let name: String
    let path: String
    let fileCount: Int
    let lastIndexed: Date
}

#Preview {
    RepoManagerView()
}

