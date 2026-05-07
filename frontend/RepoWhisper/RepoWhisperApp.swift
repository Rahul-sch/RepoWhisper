//
//  RepoWhisperApp.swift
//  RepoWhisper
//
//  Main application entry point for the Mac menu bar app.
//

import SwiftUI
import AppKit
import Combine
import ServiceManagement

@main
struct RepoWhisperApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    init() {
        // Print to console so we know app launched
        print("🚀 RepoWhisper app launching...")

        // Add crash protection
        NSSetUncaughtExceptionHandler { exception in
            print("💥 [CRASH] Uncaught exception: \(exception)")
            print("💥 [CRASH] Reason: \(exception.reason ?? "Unknown")")
            print("💥 [CRASH] Call stack: \(exception.callStackSymbols.joined(separator: "\n"))")
        }

        // Start accessing security-scoped bookmarks
        Task { @MainActor in
            SecurityScopedBookmarkManager.shared.startAccessingAll()
        }
    }
    
    var body: some Scene {
        // Main Window - Full app interface.
        // Local-first: there is no remote login, so we always show the main UI.
        // LoginView still exists in the bundle but is unreachable.
        WindowGroup("RepoWhisper", id: "main") {
            MainWindowView()
                .environmentObject(authManager)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    print("🪟 [APP] Main window appeared")
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        
        // Menu Bar Extra - simplified to prevent crashes
        MenuBarExtra {
            VStack(spacing: 8) {
                Text("RepoWhisper")
                    .font(.headline)
                Divider()

                // Show Demo Popup for testing
                Button("Show Demo Popup") {
                    FloatingPopupManager.shared.showPopup(
                        results: [
                            SearchResultItem(
                                filePath: "/demo/auth.swift",
                                chunk: "func authenticate(user: String, password: String) -> Bool {\n    // Demo code for testing\n    return true\n}",
                                score: 0.95,
                                lineStart: 10,
                                lineEnd: 14
                            ),
                            SearchResultItem(
                                filePath: "/demo/login.swift",
                                chunk: "struct LoginView: View {\n    @State var email = \"\"\n    @State var password = \"\"\n}",
                                score: 0.82,
                                lineStart: 1,
                                lineEnd: 4
                            )
                        ],
                        query: "authentication demo",
                        latency: 42.0,
                        isRecording: false
                    )
                }

                Button("Open App") {
                    // Open main window
                    if let window = NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }

                Divider()

                // Launch at Login toggle
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }

                Divider()

                Button("Quit RepoWhisper") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding()
            .frame(width: 200)
        } label: {
            Image(systemName: "waveform.circle.fill")
        }
        .menuBarExtraStyle(.menu)
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(authManager)
        }
    }
}

// MARK: - Launch at Login Helper

func setLaunchAtLogin(enabled: Bool) {
    if #available(macOS 13.0, *) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                print("✅ [APP] Registered for Launch at Login")
            } else {
                try SMAppService.mainApp.unregister()
                print("✅ [APP] Unregistered from Launch at Login")
            }
        } catch {
            print("❌ [APP] Failed to set Launch at Login: \(error)")
        }
    } else {
        // Fallback for older macOS
        print("⚠️ [APP] Launch at Login requires macOS 13+")
    }
}

// App delegate for keyboard shortcuts and URL handling
class AppDelegate: NSObject, NSApplicationDelegate {
    /// Combine subscriptions retained for the app lifetime.
    private var cancellables = Set<AnyCancellable>()
    /// True after we've successfully spawned the backend at least once
    /// this session, so we don't keep restarting it as the user toggles repos.
    private var backendStartedThisSession = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ RepoWhisper app finished launching")
        print("📌 Look for the menu bar icon (waveform.circle.fill) in the top menu bar")
        print("🔍 [APP] Auth state: authenticated=\(AuthManager.shared.isAuthenticated)")

        // Bring up the backend. If a repo is already approved, start now;
        // otherwise wait for the user to approve one and start then.
        Task { @MainActor in
            self.bootstrapBackend()
            self.observeRepoApprovals()
        }

        // Auto-launch: Show centered welcome popup on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🎯 [APP] Auto-launching centered welcome popup...")
            FloatingPopupManager.shared.showPopup(
                results: [
                    SearchResultItem(
                        filePath: "Welcome to RepoWhisper",
                        chunk: "Press ⌘⇧R to start voice recording\\nYour query will search the indexed codebase\\n\\nHotkeys:\\n• ⌘⇧R - Toggle recording\\n• ⌘⇧Space - Center popup\\n• ⌘B - Toggle visibility\\n• ⌘⇧H - Stealth mode",
                        score: 1.0,
                        lineStart: 1,
                        lineEnd: 8
                    )
                ],
                query: "Getting Started",
                latency: 0,
                isRecording: false
            )
            // Center the popup after it's created
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                FloatingPopupManager.shared.centerAndShow()
            }
        }

        // Register global keyboard shortcuts
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let _ = self else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // ⌘⇧R - Toggle recording
            if flags == [.command, .shift] && event.keyCode == 15 { // R key
                if AudioCapture.shared.isRecording {
                    AudioCapture.shared.stopRecording()
                } else {
                    Task { @MainActor in
                        // Guard 1: must have at least one approved repo, otherwise
                        // the backend can't start and a search would have nothing to hit.
                        if SecurityScopedBookmarkManager.shared.approvedPaths.isEmpty {
                            FloatingPopupManager.shared.showErrorToast(
                                "Add a repository folder first (open RepoWhisper → Add Repo)."
                            )
                            return
                        }
                        // Guard 2: backend healthy. If it crashed/didn't start, kick it.
                        if !BackendProcessManager.shared.isRunning {
                            FloatingPopupManager.shared.showErrorToast("Starting backend…")
                            do { try BackendProcessManager.shared.start() }
                            catch {
                                FloatingPopupManager.shared.showErrorToast(
                                    "Backend failed to start: \(error.localizedDescription)"
                                )
                                return
                            }
                        }
                        // Guard 3: warn (but don't block) if models are still loading.
                        if APIClient.shared.modelsLoading {
                            FloatingPopupManager.shared.showErrorToast(
                                "Loading speech models (one-time, ~30-60s) — recording anyway."
                            )
                        }

                        let granted = await AudioCapture.shared.requestPermission()
                        if granted {
                            AudioCapture.shared.startRecording()
                        }
                    }
                }
            }

            // ⌘⇧Space - Show/center overlay
            if flags == [.command, .shift] && event.keyCode == 49 { // Space key
                print("🎯 [HOTKEY] ⌘⇧Space - Center and show overlay")
                FloatingPopupManager.shared.centerAndShow()
            }

            // ⌘B - Toggle visibility
            if flags == [.command] && event.keyCode == 11 { // B key
                print("🎯 [HOTKEY] ⌘B - Toggle visibility")
                FloatingPopupManager.shared.toggleVisibility()
            }

            // ⌘⇧H - Toggle stealth mode
            if flags == [.command, .shift] && event.keyCode == 4 { // H key
                print("🎯 [HOTKEY] ⌘⇧H - Toggle stealth mode")
                FloatingPopupManager.shared.toggleStealthMode()
            }

            // ⌘← - Move window left
            if flags == [.command] && event.keyCode == 123 { // Left arrow
                FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: -50, y: 0))
            }

            // ⌘→ - Move window right
            if flags == [.command] && event.keyCode == 124 { // Right arrow
                FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: 50, y: 0))
            }

            // ⌘↑ - Move window up
            if flags == [.command] && event.keyCode == 126 { // Up arrow
                FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: 0, y: 50))
            }

            // ⌘↓ - Move window down
            if flags == [.command] && event.keyCode == 125 { // Down arrow
                FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: 0, y: -50))
            }
        }

        print("⌨️ [APP] Global hotkeys registered: ⌘⇧R (record), ⌘⇧Space (center), ⌘B (visibility), ⌘⇧H (stealth), ⌘+Arrows (move)")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("🛑 [APP] Application will terminate")
    }

    // MARK: - Silent Background Mode
    // Keep app alive in menu bar when window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        print("📍 [APP] Last window closed - staying alive in menu bar")
        return false // Don't quit - stay in menu bar
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show popup when dock icon is clicked (if no windows visible)
        if !flag {
            FloatingPopupManager.shared.centerAndShow()
        }
        return true
    }
    
    // Handle OAuth callback URLs (disabled for local-first mode)
    func application(_ application: NSApplication, open urls: [URL]) {
        // TODO: Remove in Phase D when removing auth completely
        print("📥 URL handling disabled in local-first mode")
    }

    // MARK: - Backend Lifecycle

    /// Try to spawn the backend if (a) we haven't already this session and
    /// (b) at least one repo folder has been approved.
    @MainActor
    private func bootstrapBackend() {
        guard !backendStartedThisSession else { return }
        guard !SecurityScopedBookmarkManager.shared.approvedPaths.isEmpty else {
            print("⏸ [APP] No repos approved yet — backend will start when one is added.")
            return
        }
        do {
            try BackendProcessManager.shared.start()
            backendStartedThisSession = true
            BackendProcessManager.shared.startHealthMonitoring()
            // Once the socket is up, kick the warmup so the first /transcribe
            // and /search calls are fast.
            scheduleWarmupWhenHealthy()
        } catch {
            print("❌ [APP] Backend start failed: \(error.localizedDescription)")
        }
    }

    /// Watch the bookmark manager. As soon as the user approves their first
    /// repo, bootstrap the backend (deferred-start case).
    @MainActor
    private func observeRepoApprovals() {
        SecurityScopedBookmarkManager.shared.$approvedPaths
            .removeDuplicates()
            .sink { [weak self] paths in
                guard let self = self,
                      !self.backendStartedThisSession,
                      !paths.isEmpty else { return }
                Task { @MainActor in self.bootstrapBackend() }
            }
            .store(in: &cancellables)
    }

    /// Poll BackendProcessManager.isHealthy and call APIClient.warmup() once.
    /// Stops polling after success or after ~60s of failure.
    @MainActor
    private func scheduleWarmupWhenHealthy() {
        let deadline = Date().addingTimeInterval(60)
        Task { @MainActor in
            while Date() < deadline {
                if BackendProcessManager.shared.isHealthy {
                    print("🔥 [APP] Backend healthy — kicking warmup")
                    await APIClient.shared.warmup()
                    return
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            print("⚠️ [APP] Backend never reported healthy within 60s — warmup skipped")
        }
    }
}

// Container for ResultsWindow that manages state
struct ResultsWindowContainer: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var apiClient = APIClient.shared
    @State private var results: [SearchResultItem] = []
    @State private var query: String = ""
    @State private var latency: Double = 0
    @State private var isLoading = false
    
    var body: some View {
        ResultsWindow(
            results: results,
            query: query,
            latencyMs: latency,
            isLoading: isLoading,
            isRecording: false
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SearchResults"))) { notification in
            if let data = notification.userInfo,
               let searchResults = data["results"] as? [SearchResultItem],
               let searchQuery = data["query"] as? String,
               let searchLatency = data["latency"] as? Double {
                results = searchResults
                query = searchQuery
                latency = searchLatency
                isLoading = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SearchStarted"))) { _ in
            isLoading = true
        }
    }
}

