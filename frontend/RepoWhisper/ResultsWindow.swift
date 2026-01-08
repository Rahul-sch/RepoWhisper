//
//  ResultsWindow.swift
//  RepoWhisper
//
//  Semi-transparent floating window displaying search results.
//  Shows code snippets with syntax highlighting and file paths.
//

import SwiftUI

/// Floating results panel showing search results
struct ResultsWindow: View {
    let results: [SearchResultItem]
    let query: String
    let latencyMs: Double
    let isLoading: Bool
    
    @State private var selectedResult: SearchResultItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with query and latency
            headerView
            
            Divider()
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            // Results list
            if isLoading {
                loadingView
            } else if results.isEmpty {
                emptyView
            } else {
                resultsListView
            }
        }
        .frame(width: 520, height: 450)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.05),
                                Color.blue.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .shadow(color: .black.opacity(0.25), radius: 25, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.2), Color.blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            if query.isEmpty {
                Text("Say something to search...")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                Text(query)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if latencyMs > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                    Text("\(Int(latencyMs))ms")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                }
                .foregroundColor(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.2), Color.green.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.primary.opacity(0.03), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No results found")
                .foregroundColor(.secondary)
            
            if !query.isEmpty {
                Text("Try a different search query")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    ResultCard(
                        result: result,
                        rank: index + 1,
                        isSelected: selectedResult?.id == result.id
                    )
                    .onTapGesture {
                        selectedResult = result
                        openInEditor(result)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func openInEditor(_ result: SearchResultItem) {
        // Open file in default editor (VS Code, Cursor, etc.)
        let url = URL(fileURLWithPath: result.filePath)
        NSWorkspace.shared.open(url)
    }
}

/// Individual result card
struct ResultCard: View {
    let result: SearchResultItem
    let rank: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // File path and score
            HStack {
                // Rank badge
                Text("#\(rank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(rankColor)
                    .cornerRadius(4)
                
                // File path
                HStack(spacing: 4) {
                    Image(systemName: iconForFile(result.filePath))
                        .font(.caption)
                        .foregroundColor(colorForFile(result.filePath))
                    
                    Text(fileName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Line numbers
                Text("L\(result.lineStart)-\(result.lineEnd)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Score
                Text("\(Int(result.score * 100))%")
                    .font(.caption)
                    .foregroundColor(scoreColor)
            }
            
            // Code preview
            ScrollView(.horizontal, showsIndicators: false) {
                Text(result.chunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
                    .lineLimit(5)
                    .padding(8)
                    .background(Color.black.opacity(0.2))
                    .cornerRadius(6)
            }
            
            // Full path (truncated)
            Text(result.filePath)
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private var fileName: String {
        URL(fileURLWithPath: result.filePath).lastPathComponent
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
    
    private var scoreColor: Color {
        if result.score >= 0.8 { return .green }
        if result.score >= 0.6 { return .yellow }
        return .orange
    }
    
    private func iconForFile(_ path: String) -> String {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "js", "ts", "tsx", "jsx": return "j.square"
        case "go": return "g.square"
        case "rs": return "r.square"
        case "md": return "doc.text"
        case "json", "yaml", "yml": return "curlybraces"
        default: return "doc"
        }
    }
    
    private func colorForFile(_ path: String) -> Color {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "py": return .yellow
        case "js", "jsx": return .yellow
        case "ts", "tsx": return .blue
        case "go": return .cyan
        case "rs": return .orange
        default: return .secondary
        }
    }
}

#Preview {
    ResultsWindow(
        results: [
            SearchResultItem(
                filePath: "/Users/test/project/src/auth.py",
                chunk: "def authenticate_user(email, password):\n    user = db.get_user(email)\n    if user and verify_password(password, user.hashed_pw):\n        return create_token(user)",
                score: 0.92,
                lineStart: 45,
                lineEnd: 52
            ),
            SearchResultItem(
                filePath: "/Users/test/project/src/models/user.swift",
                chunk: "struct User: Codable {\n    let id: UUID\n    let email: String\n    let createdAt: Date\n}",
                score: 0.78,
                lineStart: 10,
                lineEnd: 15
            )
        ],
        query: "user authentication",
        latencyMs: 45.2,
        isLoading: false
    )
    .preferredColorScheme(.dark)
}

