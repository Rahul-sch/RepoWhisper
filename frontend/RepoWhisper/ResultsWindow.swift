//
//  ResultsWindow.swift
//  RepoWhisper
//
//  Premium glassmorphism floating panel with ultra-minimalist design.
//  Inspired by Cluely, Linear, and Raycast.
//

import SwiftUI
import AppKit

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
    @State private var searchMode: SearchMode = .fullRepo
    @State private var toastMessage: String?
    @State private var showToast = false
    @ObservedObject private var audioCapture = AudioCapture.shared

    enum SearchMode: String, CaseIterable {
        case fullRepo = "Full Repo"
        case activeFile = "Active File"
    }

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

            // Bottom control bar
            controlBar
        }
        .frame(width: 580, height: isStealthMode ? 460 : 560)
        .background(
            // Premium glassmorphism background (more subtle in stealth)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(isStealthMode ? 0.6 : 1.0)
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
        .overlay(alignment: .top) {
            // Toast notification overlay
            if showToast, let message = toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            }
        }
    }

    // MARK: - Toast Helper

    func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showToast = false
            }
        }
    }
    
    // MARK: - Drag Area

    @State private var isHoveringCloseButton = false
    @State private var isHoveringDragArea = false

    private var dragArea: some View {
        HStack {
            Spacer()

            // Hover-reveal close button
            if isHoveringDragArea || isHoveringCloseButton {
                Button(action: {
                    FloatingPopupManager.shared.hidePopup()
                }) {
                    ZStack {
                        Circle()
                            .fill(isHoveringCloseButton ? Color.red.opacity(0.8) : Color.white.opacity(0.15))
                            .frame(width: 20, height: 20)

                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isHoveringCloseButton ? .white : .primary.opacity(0.6))
                    }
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringCloseButton = hovering
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .padding(.trailing, 16)
            }
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringDragArea = hovering
            }
        }
        .onTapGesture { }
    }

    // MARK: - Control Bar (Bottom Toolbar)

    @State private var isHoveringRecordBtn = false
    @State private var isHoveringStealthBtn = false
    @State private var isHoveringCenterBtn = false
    @State private var isHoveringClearBtn = false

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Filter toggle (left side)
            FilterToggle(mode: $searchMode)

            Spacer()

            // Record button with voice pulse
            VoicePulseButton(
                isRecording: isRecording,
                audioLevel: audioCapture.audioLevel,
                isHovering: isHoveringRecordBtn
            ) {
                if AudioCapture.shared.isRecording {
                    AudioCapture.shared.stopRecording()
                } else {
                    Task {
                        let granted = await AudioCapture.shared.requestPermission()
                        if granted {
                            AudioCapture.shared.startRecording()
                        }
                    }
                }
            }
            .onHover { isHoveringRecordBtn = $0 }

            // Stealth button
            ControlBarButton(
                icon: "eye.slash",
                label: "Stealth",
                isActive: isStealthMode,
                activeColor: .purple,
                isHovering: isHoveringStealthBtn
            ) {
                FloatingPopupManager.shared.toggleStealthMode()
            }
            .onHover { isHoveringStealthBtn = $0 }

            // Center button
            ControlBarButton(
                icon: "arrow.up.and.down.and.arrow.left.and.right",
                label: "Center",
                isActive: false,
                activeColor: .blue,
                isHovering: isHoveringCenterBtn
            ) {
                FloatingPopupManager.shared.centerAndShow()
            }
            .onHover { isHoveringCenterBtn = $0 }

            // Clear/Hide button
            ControlBarButton(
                icon: "xmark.circle",
                label: "Hide",
                isActive: false,
                activeColor: .gray,
                isHovering: isHoveringClearBtn
            ) {
                FloatingPopupManager.shared.hidePopup()
            }
            .onHover { isHoveringClearBtn = $0 }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            // Glassmorphism separator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
                Spacer()
            }
        )
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
            
            // Stealth mode indicator
            if isStealthMode {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("STEALTH")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(Color.purple.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.purple.opacity(0.15))
                )
            }

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

            // Clear All button (shows when results > 3)
            if results.count > 3 {
                Button(action: {
                    FloatingPopupManager.shared.hidePopup()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
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
    var onCopy: (() -> Void)?

    @State private var isHovering = false
    @State private var isHoveringCopy = false
    @State private var showCopied = false

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

                // Copy button (appears on hover)
                if isHovered || isHoveringCopy {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                            Text(showCopied ? "Copied!" : "Copy")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(showCopied ? .green : (isHoveringCopy ? .primary : .secondary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(showCopied ? Color.green.opacity(0.15) : Color.white.opacity(isHoveringCopy ? 0.15 : 0.08))
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { isHoveringCopy = $0 }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

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

    // MARK: - Clipboard

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(result.chunk, forType: .string)

        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            showCopied = true
        }
        onCopy?()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopied = false }
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

// MARK: - Control Bar Button (Glassmorphism Style)

struct ControlBarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let isHovering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Glassmorphism circle background
                    Circle()
                        .fill(
                            isActive
                                ? activeColor.opacity(0.25)
                                : (isHovering ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                        )
                        .frame(width: 40, height: 40)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(
                            isActive
                                ? activeColor
                                : (isHovering ? .primary : .primary.opacity(0.6))
                        )
                }

                // Label
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(
                        isActive
                            ? activeColor
                            : .secondary.opacity(0.8)
                    )
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Filter Toggle (Full Repo / Active File)

struct FilterToggle: View {
    @Binding var mode: ResultsWindow.SearchMode

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ResultsWindow.SearchMode.allCases, id: \.self) { option in
                Button(action: { mode = option }) {
                    Text(option == .fullRepo ? "Repo" : "File")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(mode == option ? .white : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(mode == option ? Color.blue.opacity(0.7) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Voice Pulse Button (Record with Audio Level)

struct VoicePulseButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let isHovering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    // Outer pulse ring (based on audio level)
                    if isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.4), lineWidth: 2)
                            .frame(width: 40 + CGFloat(audioLevel) * 20, height: 40 + CGFloat(audioLevel) * 20)
                            .animation(.easeOut(duration: 0.1), value: audioLevel)

                        Circle()
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            .frame(width: 48 + CGFloat(audioLevel) * 25, height: 48 + CGFloat(audioLevel) * 25)
                            .animation(.easeOut(duration: 0.15), value: audioLevel)
                    }

                    // Base circle
                    Circle()
                        .fill(
                            isRecording
                                ? Color.red.opacity(0.25 + Double(audioLevel) * 0.3)
                                : (isHovering ? Color.white.opacity(0.15) : Color.white.opacity(0.08))
                        )
                        .frame(width: 40, height: 40)
                        .animation(.easeOut(duration: 0.1), value: audioLevel)

                    // Icon
                    Image(systemName: isRecording ? "waveform" : "record.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isRecording ? .red : (isHovering ? .primary : .primary.opacity(0.6)))
                        .scaleEffect(isRecording ? 1.0 + CGFloat(audioLevel) * 0.2 : 1.0)
                        .animation(.easeOut(duration: 0.1), value: audioLevel)
                }

                // Label
                Text("Record")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(isRecording ? .red : .secondary.opacity(0.8))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String
    @State private var isError: Bool = false

    init(message: String) {
        self.message = message
        self._isError = State(initialValue: message.lowercased().contains("error") || message.lowercased().contains("fail"))
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isError ? .orange : .green)

            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
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
    .frame(width: 600, height: 580)
}
