//
//  ResultsWindow.swift
//  RepoWhisper
//
//  Premium glassmorphism floating panel with ultra-minimalist design.
//  Inspired by Cluely, Linear, and Raycast.
//

import SwiftUI

/// Premium floating results panel with glassmorphism
struct ResultsWindow: View {
    let results: [SearchResultItem]
    let query: String
    let latencyMs: Double
    let isLoading: Bool
    let isRecording: Bool
    let isStealthMode: Bool

    @State private var selectedResult: SearchResultItem?
    @State private var hoveredResult: SearchResultItem?
    @State private var isDragging = false

    init(results: [SearchResultItem], query: String, latencyMs: Double,
         isLoading: Bool, isRecording: Bool, isStealthMode: Bool = false) {
        self.results = results
        self.query = query
        self.latencyMs = latencyMs
        self.isLoading = isLoading
        self.isRecording = isRecording
        self.isStealthMode = isStealthMode
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag area (top 44px)
            dragArea
            
            // Header with query
            headerView
            
            // Content
            if isLoading {
                loadingView
            } else if results.isEmpty {
                emptyStateView
            } else {
                resultsListView
            }
        }
        .frame(width: 580, height: isStealthMode ? 420 : 520)
        .background(
            // Premium glassmorphism background (more subtle in stealth)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isStealthMode ? .regularMaterial.opacity(0.6) : .ultraThinMaterial)
        )
        .overlay(
            // Hairline border (0.5px, 20% opacity white)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    Color.white.opacity(0.2),
                    lineWidth: 0.5
                )
        )
        .overlay(
            // Pulsating border when recording
            Group {
                if isRecording {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.6),
                                    Color.blue.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .opacity(pulsatingOpacity)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: pulsatingOpacity
                        )
                }
            }
        )
        .shadow(
            color: .black.opacity(isStealthMode ? 0 : 0.4),
            radius: isStealthMode ? 0 : 50,
            x: 0,
            y: isStealthMode ? 0 : 25
        )
        .onAppear {
            if isRecording {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulsatingOpacity = 1.0
                }
            }
        }
    }
    
    // MARK: - Drag Area
    
    private var dragArea: some View {
        HStack {
            Spacer()
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture { }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Search icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)
                
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary.opacity(0.7))
            }
            
            // Query text
            if query.isEmpty {
                Text("Listening...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            } else {
                Text(query)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Latency badge
            if latencyMs > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(Int(latencyMs))ms")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(Color.green.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.1)
                .tint(.primary.opacity(0.6))
            
            Text("Searching...")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State with Waveform
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated waveform
            WaveformAnimation(isActive: true)
                .frame(height: 60)
            
            VStack(spacing: 8) {
                Text("No results found")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                if !query.isEmpty {
                    Text("Try rephrasing your query")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results List
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    PremiumResultCard(
                        result: result,
                        rank: index + 1,
                        isSelected: selectedResult?.id == result.id,
                        isHovered: hoveredResult?.id == result.id
                    )
                    .onTapGesture {
                        selectedResult = result
                        openInEditor(result)
                    }
                    .onHover { hovering in
                        hoveredResult = hovering ? result : nil
                    }
                }
            }
            .padding(20)
        }
    }
    
    // MARK: - Pulsating Animation
    
    @State private var pulsatingOpacity: Double = 0.3
    
    // MARK: - Actions
    
    private func openInEditor(_ result: SearchResultItem) {
        let url = URL(fileURLWithPath: result.filePath)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Premium Result Card

struct PremiumResultCard: View {
    let result: SearchResultItem
    let rank: Int
    let isSelected: Bool
    let isHovered: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(spacing: 10) {
                // Rank badge
                Text("#\(rank)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(rankBadgeColor)
                    .clipShape(Capsule())
                
                // File info
                HStack(spacing: 6) {
                    Image(systemName: iconForFile(result.filePath))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(fileTypeColor)
                    
                    Text(fileName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Metadata
                HStack(spacing: 12) {
                    Text("L\(result.lineStart)-\(result.lineEnd)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    // Score badge
                    Text("\(Int(result.score * 100))%")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(scoreTextColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(scoreBackgroundColor)
                        .clipShape(Capsule())
                }
            }
            
            // Code preview (Linear dark theme)
            CodePreview(text: result.chunk)
            
            // File path
            Text(result.filePath)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.6))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected || isHovered ?
                    Color.white.opacity(0.08) :
                    Color.white.opacity(0.03)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ?
                    Color.white.opacity(0.15) :
                    Color.clear,
                    lineWidth: 0.5
                )
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
    
    private var fileName: String {
        URL(fileURLWithPath: result.filePath).lastPathComponent
    }
    
    private var rankBadgeColor: Color {
        switch rank {
        case 1: return Color(red: 0.98, green: 0.80, blue: 0.36) // Gold
        case 2: return Color(red: 0.70, green: 0.70, blue: 0.70) // Silver
        case 3: return Color(red: 0.96, green: 0.65, blue: 0.38) // Bronze
        default: return Color.secondary.opacity(0.6)
        }
    }
    
    private var fileTypeColor: Color {
        let ext = URL(fileURLWithPath: result.filePath).pathExtension.lowercased()
        switch ext {
        case "swift": return Color(red: 0.96, green: 0.26, blue: 0.21) // Orange-red
        case "py": return Color(red: 0.95, green: 0.78, blue: 0.18) // Yellow
        case "js", "jsx": return Color(red: 0.95, green: 0.78, blue: 0.18) // Yellow
        case "ts", "tsx": return Color(red: 0.20, green: 0.60, blue: 0.86) // Blue
        case "go": return Color(red: 0.00, green: 0.82, blue: 0.80) // Cyan
        case "rs": return Color(red: 0.96, green: 0.26, blue: 0.21) // Orange-red
        default: return .secondary
        }
    }
    
    private var scoreTextColor: Color {
        if result.score >= 0.8 { return Color(red: 0.20, green: 0.78, blue: 0.35) } // Green
        if result.score >= 0.6 { return Color(red: 0.95, green: 0.78, blue: 0.18) } // Yellow
        return Color(red: 0.96, green: 0.26, blue: 0.21) // Red
    }
    
    private var scoreBackgroundColor: Color {
        if result.score >= 0.8 { return Color(red: 0.20, green: 0.78, blue: 0.35).opacity(0.15) }
        if result.score >= 0.6 { return Color(red: 0.95, green: 0.78, blue: 0.18).opacity(0.15) }
        return Color(red: 0.96, green: 0.26, blue: 0.21).opacity(0.15)
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
}

// MARK: - Code Preview (Linear Dark Theme)

struct CodePreview: View {
    let text: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(Color(red: 0.85, green: 0.85, blue: 0.85)) // Light gray
                .lineLimit(4)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.10, blue: 0.12)) // Deep gray
                )
        }
    }
}

// MARK: - Waveform Animation

struct WaveformAnimation: View {
    let isActive: Bool
    @State private var animationPhase: Double = 0
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.7),
                                Color.blue.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .frame(height: heightForBar(index))
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.05),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            if isActive {
                animationPhase = 1.0
            }
        }
    }
    
    private func heightForBar(_ index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 50
        let variation = sin(Double(index) * 0.5 + animationPhase * 2 * .pi) * 0.5 + 0.5
        return baseHeight + (maxHeight - baseHeight) * variation
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
            )
        ],
        query: "user authentication",
        latencyMs: 45.2,
        isLoading: false,
        isRecording: false
    )
    .preferredColorScheme(.dark)
    .frame(width: 600, height: 500)
}
