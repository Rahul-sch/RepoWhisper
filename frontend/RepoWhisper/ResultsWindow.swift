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
    let explainStage: ExplainVisibleStage?
    let explainResponse: ExplainVisibleResponse?
    let explainError: String?

    @State private var selectedResult: SearchResultItem?
    @State private var hoveredResult: SearchResultItem?
    @State private var isDragging = false
    @State private var searchMode: SearchMode = .fullRepo
    @State private var toastMessage: String?
    @State private var showToast = false
    @State private var typedQuery: String = ""
    @ObservedObject private var audioCapture = AudioCapture.shared
    @ObservedObject private var popupManager = FloatingPopupManager.shared

    enum SearchMode: String, CaseIterable {
        case fullRepo = "Full Repo"
        case activeFile = "Active File"
    }

    init(results: [SearchResultItem], query: String, latencyMs: Double,
         isLoading: Bool, isRecording: Bool, isStealthMode: Bool = false,
         explainStage: ExplainVisibleStage? = nil,
         explainResponse: ExplainVisibleResponse? = nil,
         explainError: String? = nil) {
        self.results = results
        self.query = query
        self.latencyMs = latencyMs
        self.isLoading = isLoading
        self.isRecording = isRecording
        self.isStealthMode = isStealthMode
        self.explainStage = explainStage
        self.explainResponse = explainResponse
        self.explainError = explainError
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag area (top 44px)
            dragArea

            // Ask Bar (typed search input)
            AskBar(
                query: $typedQuery,
                isRecording: isRecording,
                audioLevel: audioCapture.audioLevel,
                onSubmit: { query in
                    popupManager.triggerTypedSearch(query: query)
                },
                onToggleRecording: {
                    if AudioCapture.shared.isRecording {
                        AudioCapture.shared.stopRecording()
                    } else {
                        Task {
                            let granted = await AudioCapture.shared.requestPermission()
                            if granted {
                                AudioCapture.shared.startRecording()
                            } else {
                                popupManager.showErrorToast("Microphone access denied")
                            }
                        }
                    }
                }
            )

            // Header with query/status
            headerView

            // Search history (collapsible)
            if !popupManager.searchHistory.isEmpty {
                SearchHistoryView(
                    history: $popupManager.searchHistory,
                    isExpanded: $popupManager.isHistoryExpanded,
                    onSelect: { item in
                        popupManager.triggerTypedSearch(query: item.query)
                    },
                    onClear: {
                        popupManager.clearSearchHistory()
                    }
                )
            }

            // Content
            if let explainStage {
                ExplainVisibleContentView(stage: explainStage)
            } else if let explainError {
                ExplainVisibleContentView(errorMessage: explainError)
            } else if let explainResponse {
                ExplainVisibleContentView(response: explainResponse)
            } else if isLoading {
                loadingView
            } else if results.isEmpty {
                emptyStateView
            } else {
                resultsListView
            }

            // Bottom control bar
            controlBar
        }
        .frame(width: 520, height: isStealthMode ? 420 : 520)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: OverlayTheme.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: OverlayTheme.cornerRadius, style: .continuous)
                    .fill(OverlayTheme.canvas.opacity(isStealthMode ? 0.72 : 0.90))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: OverlayTheme.cornerRadius, style: .continuous)
                .stroke(OverlayTheme.borderStrong, lineWidth: 1)
        )
        .overlay(
            // Pulsating border when recording
            Group {
                if isRecording {
                    RoundedRectangle(cornerRadius: OverlayTheme.cornerRadius, style: .continuous)
                        .stroke(OverlayTheme.accent, lineWidth: 1)
                        .opacity(pulsatingOpacity)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: pulsatingOpacity
                        )
                }
            }
        )
        .shadow(
            color: .black.opacity(isStealthMode ? 0 : 0.55),
            radius: isStealthMode ? 0 : 32,
            x: 0,
            y: isStealthMode ? 0 : 18
        )
        .onAppear {
            if isRecording {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulsatingOpacity = 1.0
                }
            }
        }
        .overlay(alignment: .top) {
            // Toast notification overlay (local or from popupManager)
            if showToast, let message = toastMessage {
                ToastView(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 60)
            } else if popupManager.showToast, let message = popupManager.toastMessage {
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
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isRecording ? OverlayTheme.danger : OverlayTheme.accent)
                .frame(width: 6, height: 6)

            Text(isRecording ? "Listening" : "RepoWhisper")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(OverlayTheme.textSecondary)

            Spacer()

            Button(action: {
                FloatingPopupManager.shared.hidePopup()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isHoveringCloseButton ? OverlayTheme.textPrimary : OverlayTheme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(isHoveringCloseButton ? OverlayTheme.hover : .clear, in: RoundedRectangle(cornerRadius: 7))
                }
            .buttonStyle(.plain)
            .onHover { isHoveringCloseButton = $0 }
            }
        .padding(.horizontal, 14)
        .frame(height: 36)
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
        HStack(spacing: 8) {
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
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(
            // Glassmorphism separator
            VStack(spacing: 0) {
                Rectangle()
                    .fill(OverlayTheme.border)
                    .frame(height: 0.5)
                Spacer()
            }
        )
    }

    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // Query text
            if query.isEmpty {
                Text(isRecording ? "Listening for context…" : "Ready when you are")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OverlayTheme.textSecondary)
            } else {
                Text(query)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OverlayTheme.textPrimary)
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
                .foregroundStyle(OverlayTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(OverlayTheme.accent.opacity(0.12))
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
                .foregroundStyle(OverlayTheme.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(OverlayTheme.success.opacity(0.10))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        SkeletonLoadingView()
    }
    
    // MARK: - Empty State with Waveform
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            WaveformAnimation(isActive: true)
                .frame(height: 44)
            
            VStack(spacing: 5) {
                Text(query.isEmpty ? "Ask anything about this repository" : "No matching context")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OverlayTheme.textPrimary)
                
                if !query.isEmpty {
                    Text("Try a file name, symbol, or broader question.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(OverlayTheme.textSecondary)
                } else {
                    Text("Search by voice or type above.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(OverlayTheme.textSecondary)
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
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(rank == 1 ? OverlayTheme.accent : OverlayTheme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(rank == 1 ? OverlayTheme.accent.opacity(0.12) : OverlayTheme.hover)
                    .clipShape(Capsule())

                // File info
                HStack(spacing: 6) {
                    Image(systemName: iconForFile(result.filePath))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(fileTypeColor)

                    Text(fileName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(OverlayTheme.textPrimary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    Task { await ExplainVisibleCoordinator.shared.explain(selectedText: result.chunk) }
                } label: {
                    Label("Explain", systemImage: "sparkles")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundStyle(OverlayTheme.accent)

                // Copy button (appears on hover)
                if isHovered || isHoveringCopy {
                    Button(action: copyToClipboard) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 10, weight: .medium))
                            Text(showCopied ? "Copied!" : "Copy")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(showCopied ? OverlayTheme.success : (isHoveringCopy ? OverlayTheme.textPrimary : OverlayTheme.textSecondary))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(showCopied ? OverlayTheme.success.opacity(0.14) : OverlayTheme.hover)
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
                        .foregroundStyle(OverlayTheme.textSecondary)

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
                .foregroundStyle(OverlayTheme.textSecondary.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected || isHovered ? OverlayTheme.hover : OverlayTheme.elevated.opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isSelected ? OverlayTheme.accent.opacity(0.55) : OverlayTheme.border, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
    
    private var fileName: String {
        URL(fileURLWithPath: result.filePath).lastPathComponent
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

// MARK: - Explain Visible Function

struct ExplainVisibleContentView: View {
    let stage: ExplainVisibleStage?
    let response: ExplainVisibleResponse?
    let errorMessage: String?

    init(stage: ExplainVisibleStage) {
        self.stage = stage
        self.response = nil
        self.errorMessage = nil
    }

    init(response: ExplainVisibleResponse) {
        self.stage = nil
        self.response = response
        self.errorMessage = nil
    }

    init(errorMessage: String) {
        self.stage = nil
        self.response = nil
        self.errorMessage = errorMessage
    }

    var body: some View {
        Group {
            if let stage {
                VStack(spacing: 16) {
                    ProgressView().controlSize(.large)
                    Text(stage.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("OCR stays on this Mac. Only matched repository context is sent to an explicitly configured provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            } else if let errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)
                    Text("Explanation unavailable").font(.headline)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        Task { await ExplainVisibleCoordinator.shared.explain() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(28)
            } else if let response {
                responseContent(response)
            }
        }
    }

    @ViewBuilder
    private func responseContent(_ response: ExplainVisibleResponse) -> some View {
        if response.requiresCandidateSelection {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose the visible symbol")
                    .font(.headline)
                Text("Several indexed implementations are equally plausible.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach(response.candidateSymbols) { candidate in
                    Button {
                        Task { await ExplainVisibleCoordinator.shared.selectCandidate(candidate) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(candidate.name).font(.system(.body, design: .monospaced))
                                Text("\(candidate.filePath):\(candidate.lineStart)-\(candidate.lineEnd)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(Int(candidate.confidence * 100))%")
                                .font(.caption)
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        } else if let symbol = response.matchedSymbol,
                  let explanation = response.explanation {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(symbol.name)
                                .font(.system(size: 17, weight: .bold, design: .monospaced))
                            Text("\(symbol.kind) • \(Int(symbol.confidence * 100))% match")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Open") { NSWorkspace.shared.open(URL(fileURLWithPath: symbol.filePath)) }
                    }

                    explanationSection("What it does", explanation.summary)
                    explanationSection(
                        explanation.purposeIsInference ? "Why it may exist (inference)" : "Why it exists",
                        explanation.purpose
                    )
                    bulletSection("How it works", explanation.howItWorks)
                    bulletSection("Inputs", explanation.inputs)
                    bulletSection("Outputs", explanation.outputs)
                    bulletSection("Side effects", explanation.sideEffects)
                    bulletSection("Dependencies and callers", explanation.dependencies + explanation.callers)
                    bulletSection("Risks and questions", explanation.risksAndQuestions)

                    if !response.sources.isEmpty {
                        Text("Sources").font(.headline)
                        ForEach(response.sources) { source in
                            Button {
                                NSWorkspace.shared.open(URL(fileURLWithPath: source.filePath))
                            } label: {
                                Text("\(source.reason): \(source.filePath):\(source.lineStart)-\(source.lineEnd)")
                                    .font(.caption2.monospaced())
                                    .lineLimit(2)
                            }
                            .buttonStyle(.link)
                        }
                    }

                    HStack {
                        Button("Copy explanation") { copy(response) }
                        Button("Ask a follow-up") {
                            FloatingPopupManager.shared.showErrorToast("Follow-up questions are coming in the transcript phase.")
                        }
                        Button("Try another match") {
                            Task { await ExplainVisibleCoordinator.shared.explain() }
                        }
                    }
                    .font(.caption)
                }
                .padding(20)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.folder")
                    .font(.system(size: 28))
                Text("No indexed symbol matched the visible code.")
                Button("Try Another Match") {
                    Task { await ExplainVisibleCoordinator.shared.explain() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func explanationSection(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(text).font(.caption).textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func bulletSection(_ title: String, _ items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text("• \(item)").font(.caption).textSelection(.enabled)
                }
            }
        }
    }

    private func copy(_ response: ExplainVisibleResponse) {
        guard let explanation = response.explanation else { return }
        let text = [
            explanation.summary,
            "Purpose: \(explanation.purpose)",
            "How it works: \(explanation.howItWorks.joined(separator: "; "))",
            "Risks/questions: \(explanation.risksAndQuestions.joined(separator: "; "))"
        ].joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            isActive
                                ? OverlayTheme.accent.opacity(0.16)
                                : (isHovering ? OverlayTheme.hover : OverlayTheme.elevated)
                        )
                        .frame(width: 32, height: 32)

                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            isActive
                                ? OverlayTheme.accent
                                : (isHovering ? OverlayTheme.textPrimary : OverlayTheme.textSecondary)
                        )
                }

                // Label
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(isActive ? OverlayTheme.accent : OverlayTheme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovering ? 1.02 : 1.0)
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
                        .foregroundStyle(mode == option ? OverlayTheme.textPrimary : OverlayTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(mode == option ? OverlayTheme.hover : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(OverlayTheme.elevated)
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

// MARK: - Search History View

struct SearchHistoryView: View {
    @Binding var history: [SearchHistoryItem]
    @Binding var isExpanded: Bool
    let onSelect: (SearchHistoryItem) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header with toggle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("Recent Searches")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Text("\(history.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )

                    Spacer()

                    if isExpanded && !history.isEmpty {
                        Button(action: onClear) {
                            Text("Clear")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
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
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            // Expanded history list
            if isExpanded && !history.isEmpty {
                VStack(spacing: 4) {
                    ForEach(history) { item in
                        SearchHistoryRow(item: item) {
                            onSelect(item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Separator
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Search History Row

struct SearchHistoryRow: View {
    let item: SearchHistoryItem
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))

                Text(item.query)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                // Results count badge
                Text("\(item.resultsCount)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )

                // Relative time
                Text(item.relativeTime)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovering ? Color.white.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Ask Bar (Typed Search Input)

struct AskBar: View {
    @Binding var query: String
    let isRecording: Bool
    let audioLevel: Float
    let onSubmit: (String) -> Void
    let onToggleRecording: () -> Void

    @State private var isFocused = false
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Text field
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OverlayTheme.accent)

                TextField("Ask about your code…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(OverlayTheme.textPrimary)
                    .focused($textFieldFocused)
                    .onSubmit {
                        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSubmit(query)
                        }
                    }
                    .onChange(of: textFieldFocused) { _, newValue in
                        isFocused = newValue
                    }

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(OverlayTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: OverlayTheme.controlRadius, style: .continuous)
                    .fill(OverlayTheme.elevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OverlayTheme.controlRadius, style: .continuous)
                    .stroke(
                        isFocused || isRecording
                            ? (isRecording ? OverlayTheme.danger.opacity(0.65) : OverlayTheme.accent.opacity(0.65))
                            : OverlayTheme.border,
                        lineWidth: 1
                    )
            )

            // Mic button with hotkey badge
            AskBarMicButton(
                isRecording: isRecording,
                audioLevel: audioLevel,
                action: onToggleRecording
            )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

// MARK: - Ask Bar Mic Button

struct AskBarMicButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer pulse ring (when recording)
                if isRecording {
                    Circle()
                        .stroke(OverlayTheme.danger.opacity(0.35), lineWidth: 1)
                        .frame(width: 34 + CGFloat(audioLevel) * 12, height: 34 + CGFloat(audioLevel) * 12)
                        .animation(.easeOut(duration: 0.1), value: audioLevel)
                }

                // Base circle
                Circle()
                    .fill(
                        isRecording
                            ? OverlayTheme.danger.opacity(0.18 + Double(audioLevel) * 0.25)
                            : (isHovering ? OverlayTheme.hover : OverlayTheme.elevated)
                    )
                    .frame(width: 34, height: 34)

                // Mic icon
                Image(systemName: isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isRecording ? OverlayTheme.danger : (isHovering ? OverlayTheme.textPrimary : OverlayTheme.textSecondary))
                    .scaleEffect(isRecording ? 1.0 + CGFloat(audioLevel) * 0.15 : 1.0)
                    .animation(.easeOut(duration: 0.1), value: audioLevel)

                // Hotkey badge
                if !isRecording {
                    HotkeyBadge(keys: "⌘⇧R")
                        .offset(x: 14, y: -14)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Hotkey Badge

struct HotkeyBadge: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundColor(.secondary.opacity(0.8))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Skeleton Loading

struct SkeletonLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    SkeletonResultCard()
                        .opacity(1.0 - Double(index) * 0.15)
                }
            }
            .padding(20)
        }
        .transition(.opacity)
    }
}

struct SkeletonResultCard: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row skeleton
            HStack(spacing: 10) {
                // Rank badge skeleton
                SkeletonShape()
                    .frame(width: 32, height: 18)
                    .clipShape(Capsule())

                // File name skeleton
                SkeletonShape()
                    .frame(width: 120, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Line number skeleton
                SkeletonShape()
                    .frame(width: 50, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Score skeleton
                SkeletonShape()
                    .frame(width: 40, height: 18)
                    .clipShape(Capsule())
            }

            // Code preview skeleton (3 lines)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape()
                    .frame(height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                SkeletonShape()
                    .frame(width: 280, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                SkeletonShape()
                    .frame(width: 200, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.12))
            )

            // File path skeleton
            SkeletonShape()
                .frame(width: 180, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            // Shimmer overlay
            GeometryReader { geometry in
                LinearGradient(
                    gradient: Gradient(colors: [
                        .clear,
                        .white.opacity(0.08),
                        .clear
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 100)
                .offset(x: shimmerPhase)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        shimmerPhase = geometry.size.width + 100
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
    }
}

struct SkeletonShape: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
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
