//
//  FloatingPopupManager.swift
//  RepoWhisper
//
//  Manages floating popup windows that appear on screen (Cluely-style).
//

import SwiftUI
import AppKit

/// Search history item for recent queries
struct SearchHistoryItem: Codable, Identifiable {
    let id: UUID
    let query: String
    let resultsCount: Int
    let timestamp: Date

    init(id: UUID = UUID(), query: String, resultsCount: Int, timestamp: Date = Date()) {
        self.id = id
        self.query = query
        self.resultsCount = resultsCount
        self.timestamp = timestamp
    }

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

/// Manages floating popup windows that appear on screen
class FloatingPopupManager: ObservableObject {
    static let shared = FloatingPopupManager()

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let stealthMode = "RepoWhisper.stealthMode"
        static let windowX = "RepoWhisper.windowX"
        static let windowY = "RepoWhisper.windowY"
        static let hasCustomPosition = "RepoWhisper.hasCustomPosition"
        static let searchHistory = "RepoWhisper.searchHistory"
    }

    private let maxHistoryItems = 10

    @Published var isVisible = false
    @Published var isStealthMode: Bool {
        didSet {
            UserDefaults.standard.set(isStealthMode, forKey: Keys.stealthMode)
        }
    }
    @Published var toastMessage: String?
    @Published var showToast = false
    @Published var searchHistory: [SearchHistoryItem] = []
    @Published var isHistoryExpanded = false

    private var popupWindow: NSPanel?
    private var savedPosition: NSPoint?
    private var autoDismissTask: DispatchWorkItem?

    private init() {
        // Load persisted settings
        self.isStealthMode = UserDefaults.standard.bool(forKey: Keys.stealthMode)

        // Load saved position if exists
        if UserDefaults.standard.bool(forKey: Keys.hasCustomPosition) {
            let x = UserDefaults.standard.double(forKey: Keys.windowX)
            let y = UserDefaults.standard.double(forKey: Keys.windowY)
            self.savedPosition = NSPoint(x: x, y: y)
            print("📍 [POPUP] Loaded saved position: (\(x), \(y))")
        }

        // Load search history
        loadSearchHistory()

        print("⚙️ [POPUP] Loaded settings: stealth=\(isStealthMode), history=\(searchHistory.count) items")
    }

    // MARK: - Persistence

    /// Save current window position
    private func saveWindowPosition() {
        guard let panel = popupWindow else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set(origin.x, forKey: Keys.windowX)
        UserDefaults.standard.set(origin.y, forKey: Keys.windowY)
        UserDefaults.standard.set(true, forKey: Keys.hasCustomPosition)
        savedPosition = origin
        print("💾 [POPUP] Saved position: (\(origin.x), \(origin.y))")
    }

    // MARK: - Search History

    /// Load search history from UserDefaults
    private func loadSearchHistory() {
        guard let data = UserDefaults.standard.data(forKey: Keys.searchHistory) else {
            searchHistory = []
            return
        }
        do {
            searchHistory = try JSONDecoder().decode([SearchHistoryItem].self, from: data)
            print("📚 [POPUP] Loaded \(searchHistory.count) history items")
        } catch {
            print("❌ [POPUP] Failed to decode search history: \(error)")
            searchHistory = []
        }
    }

    /// Save search history to UserDefaults
    private func saveSearchHistoryLocal() {
        do {
            let data = try JSONEncoder().encode(searchHistory)
            UserDefaults.standard.set(data, forKey: Keys.searchHistory)
            print("💾 [POPUP] Saved \(searchHistory.count) history items")
        } catch {
            print("❌ [POPUP] Failed to encode search history: \(error)")
        }
    }

    /// Add a search query to history
    func addToSearchHistory(query: String, resultsCount: Int) {
        // Skip empty queries
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Remove duplicate if exists (same query)
        searchHistory.removeAll { $0.query.lowercased() == query.lowercased() }

        // Add new item at the beginning
        let item = SearchHistoryItem(query: query, resultsCount: resultsCount)
        searchHistory.insert(item, at: 0)

        // Trim to max items
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }

        saveSearchHistoryLocal()
        print("📝 [POPUP] Added to history: '\(query)' (\(resultsCount) results)")

        // Optional: Sync to Supabase if authenticated
        Task {
            await syncHistoryToSupabase(item)
        }
    }

    /// Clear all search history
    func clearSearchHistory() {
        searchHistory.removeAll()
        UserDefaults.standard.removeObject(forKey: Keys.searchHistory)
        print("🗑️ [POPUP] Cleared search history")
    }

    // MARK: - Supabase Sync (Optional)

    /// Sync search history item to Supabase if authenticated
    private func syncHistoryToSupabase(_ item: SearchHistoryItem) async {
        // Only sync if authenticated (check on main actor)
        let isAuth = await MainActor.run { AuthManager.shared.isAuthenticated }
        guard isAuth else { return }

        do {
            let session = try await supabase.auth.session
            let userId = session.user.id

            try await supabase.from("search_history")
                .insert([
                    "user_id": userId.uuidString,
                    "query": item.query,
                    "results_count": String(item.resultsCount),
                    "created_at": ISO8601DateFormatter().string(from: item.timestamp)
                ])
                .execute()
            print("☁️ [POPUP] Synced to Supabase: '\(item.query)'")
        } catch {
            // Silently fail - local storage is primary
            print("⚠️ [POPUP] Supabase sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Toast Notification

    func showErrorToast(_ message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                self.showToast = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeOut(duration: 0.2)) {
                    self.showToast = false
                }
            }
        }
    }
    
    /// Show the floating popup with search results
    func showPopup(results: [SearchResultItem], query: String, latency: Double, isRecording: Bool) {
        print("🎯 [POPUP] showPopup called with \(results.count) results, query: '\(query)'")

        // Add to search history
        addToSearchHistory(query: query, resultsCount: results.count)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("❌ [POPUP] self is nil, aborting")
                return
            }
            
            print("✅ [POPUP] Creating popup window...")
            // Close existing window if any (with delay to prevent ViewBridge errors)
            if let existingWindow = self.popupWindow {
                print("🔄 [POPUP] Closing existing window first")
                // Animate out first
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    existingWindow.animator().alphaValue = 0
                }, completionHandler: {
                    existingWindow.close()
                    self.popupWindow = nil
                    // Delay to let the window fully close before creating new one
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.createAndShowPopup(results: results, query: query, latency: latency, isRecording: isRecording)
                    }
                })
            } else {
                self.createAndShowPopup(results: results, query: query, latency: latency, isRecording: isRecording)
            }
        }
    }
    
    private func createAndShowPopup(results: [SearchResultItem], query: String, latency: Double, isRecording: Bool) {
        print("🎨 [POPUP] createAndShowPopup - creating window with \(results.count) results")
        // Create the SwiftUI view
        let contentView = ResultsWindow(
            results: results,
            query: query,
            latencyMs: latency,
            isLoading: false,
            isRecording: isRecording,
            isStealthMode: isStealthMode
        )

        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)
        print("✅ [POPUP] Created hosting view")

        // Calculate position (top-right corner of screen with padding)
        guard let screen = NSScreen.main else {
            print("❌ [POPUP] No main screen found!")
            return
        }
        print("✅ [POPUP] Got main screen: \(screen.frame)")
        let screenFrame = screen.visibleFrame

        // Window size (premium glassmorphism)
        let windowWidth: CGFloat = 580
        let windowHeight: CGFloat = isStealthMode ? 460 : 560
        let padding: CGFloat = 20

        // Use saved position if available, otherwise default to top-right (or bottom-right in stealth)
        let xPos: CGFloat
        let yPos: CGFloat

        if let saved = savedPosition {
            xPos = saved.x
            yPos = saved.y
            print("📍 [POPUP] Using saved position: (\(xPos), \(yPos))")
        } else {
            xPos = screenFrame.maxX - windowWidth - padding
            yPos = isStealthMode
                ? screenFrame.minY + padding
                : screenFrame.maxY - windowHeight - padding
        }

        let windowFrame = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )

        // Create the popup panel with stealth support
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel appearance
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,       // Hidden from Mission Control
            .ignoresCycle      // Skip Cmd+Tab
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = !isStealthMode
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        // Screen-share invisibility ONLY in stealth mode
        panel.sharingType = isStealthMode ? .none : .readOnly

        // Store and show
        self.popupWindow = panel
        self.isVisible = true

        print("📺 [POPUP] Window created at position: x=\(xPos), y=\(yPos), size=\(windowWidth)x\(windowHeight), stealth=\(isStealthMode)")
        
        // Animate in
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        print("✅ [POPUP] Window ordered front - should be visible now!")

        let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = targetAlpha
        }, completionHandler: {
            print("✨ [POPUP] Animation complete - window fully visible")
        })

        // Auto-dismiss (15s normal, 30s stealth)
        autoDismissTask?.cancel()
        let dismissDelay: Double = isStealthMode ? 30 : 15
        let task = DispatchWorkItem { [weak self] in
            self?.hidePopup()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }
    
    /// Show the popup in loading state
    func showLoadingPopup(query: String, isRecording: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Close existing window if any (with delay to prevent ViewBridge errors)
            if let existingWindow = self.popupWindow {
                // Animate out first
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    existingWindow.animator().alphaValue = 0
                }, completionHandler: {
                    existingWindow.close()
                    self.popupWindow = nil
                    // Delay to let the window fully close before creating new one
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.createAndShowLoadingPopup(query: query, isRecording: isRecording)
                    }
                })
            } else {
                self.createAndShowLoadingPopup(query: query, isRecording: isRecording)
            }
        }
    }
    
    private func createAndShowLoadingPopup(query: String, isRecording: Bool) {
        // Create the SwiftUI view with loading state
        let contentView = ResultsWindow(
            results: [],
            query: query,
            latencyMs: 0,
            isLoading: true,
            isRecording: isRecording,
            isStealthMode: isStealthMode
        )

        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)

        // Calculate position (top-right corner of screen with padding)
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        // Window size
        let windowWidth: CGFloat = 580
        let windowHeight: CGFloat = isStealthMode ? 460 : 560
        let padding: CGFloat = 20

        // Use saved position if available
        let xPos: CGFloat
        let yPos: CGFloat

        if let saved = savedPosition {
            xPos = saved.x
            yPos = saved.y
        } else {
            xPos = screenFrame.maxX - windowWidth - padding
            yPos = isStealthMode
                ? screenFrame.minY + padding
                : screenFrame.maxY - windowHeight - padding
        }

        let windowFrame = NSRect(
            x: xPos,
            y: yPos,
            width: windowWidth,
            height: windowHeight
        )

        // Create the popup panel with stealth support
        let panel = NSPanel(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Configure panel appearance
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = !isStealthMode
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        panel.sharingType = isStealthMode ? .none : .readOnly

        // Store and show
        self.popupWindow = panel
        self.isVisible = true

        // Animate in
        let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = targetAlpha
        }, completionHandler: nil)

        // Auto-dismiss (15s normal, 30s stealth)
        autoDismissTask?.cancel()
        let dismissDelay: Double = isStealthMode ? 30 : 15
        let task = DispatchWorkItem { [weak self] in
            self?.hidePopup()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }

    // MARK: - Stealth Mode Controls

    /// Toggle stealth mode on/off
    func toggleStealthMode() {
        isStealthMode.toggle()
        print("🥷 [POPUP] Stealth mode: \(isStealthMode ? "ON" : "OFF")")

        guard let panel = popupWindow else { return }

        // Update panel properties
        panel.hasShadow = !isStealthMode
        panel.sharingType = isStealthMode ? .none : .readOnly

        // Animate opacity change
        let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = targetAlpha
        }

        // Reset auto-dismiss with new timing
        autoDismissTask?.cancel()
        let dismissDelay: Double = isStealthMode ? 30 : 15
        let task = DispatchWorkItem { [weak self] in
            self?.hidePopup()
        }
        autoDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + dismissDelay, execute: task)
    }

    /// Show and center the popup window
    func centerAndShow() {
        guard let panel = popupWindow, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))

        if !isVisible {
            let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = targetAlpha
            }
            isVisible = true
        }
    }

    /// Toggle popup visibility (show/hide with position memory)
    func toggleVisibility() {
        guard let panel = popupWindow else { return }

        if isVisible {
            savedPosition = panel.frame.origin
            hidePopup()
        } else {
            if let pos = savedPosition {
                panel.setFrameOrigin(pos)
            }
            let targetAlpha: CGFloat = isStealthMode ? 0.7 : 1.0
            panel.alphaValue = 0
            panel.orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().alphaValue = targetAlpha
            }
            isVisible = true
        }
    }

    /// Move window by offset
    func moveWindow(direction: NSPoint) {
        guard let panel = popupWindow else { return }
        let newOrigin = NSPoint(
            x: panel.frame.origin.x + direction.x,
            y: panel.frame.origin.y + direction.y
        )
        panel.setFrameOrigin(newOrigin)
        saveWindowPosition() // Persist position
    }

    /// Hide the floating popup
    func hidePopup() {
        // Save position before hiding
        saveWindowPosition()

        DispatchQueue.main.async { [weak self] in
            guard let panel = self?.popupWindow else { return }
            
            // Animate out
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil) // Use orderOut instead of close for smoother transition
                // Delay before clearing to prevent ViewBridge errors
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    panel.close()
                    self?.popupWindow = nil
                    self?.isVisible = false
                }
            })
        }
    }
    
    /// Toggle popup visibility
    func togglePopup() {
        if self.isVisible {
            hidePopup()
        }
    }

    // MARK: - Typed Search

    /// Trigger a search from typed input (not voice)
    func triggerTypedSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        print("⌨️ [POPUP] Typed search triggered: '\(trimmedQuery)'")

        Task {
            // Show loading state
            await MainActor.run {
                showLoadingPopup(query: trimmedQuery, isRecording: false)
            }

            do {
                // Check backend connectivity first
                await APIClient.shared.checkHealth()
                let isConnected = await MainActor.run { APIClient.shared.isConnected }
                guard isConnected else {
                    await MainActor.run {
                        showErrorToast("Backend offline - check localhost:8000")
                        hidePopup()
                    }
                    return
                }

                // Perform search
                let response = try await APIClient.shared.search(query: trimmedQuery)

                await MainActor.run {
                    showPopup(
                        results: response.results,
                        query: trimmedQuery,
                        latency: response.latencyMs,
                        isRecording: false
                    )
                }
            } catch {
                await MainActor.run {
                    showErrorToast("Search failed: \(error.localizedDescription)")
                    hidePopup()
                }
            }
        }
    }
}

