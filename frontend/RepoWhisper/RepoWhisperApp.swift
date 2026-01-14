//
//  RepoWhisperApp.swift
//  RepoWhisper
//
//  Main application entry point for the Mac menu bar app.
//

import SwiftUI
import AppKit
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
        // Main Window - Full app interface
        WindowGroup("RepoWhisper", id: "main") {
            Group {
                if authManager.isAuthenticated {
                    MainWindowView()
                        .environmentObject(authManager)
                        .frame(minWidth: 800, minHeight: 600)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                        .frame(width: 400, height: 500)
                }
            }
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("✅ RepoWhisper app finished launching")
        print("📌 Look for the menu bar icon (waveform.circle.fill) in the top menu bar")
        print("🔍 [APP] Auth state: authenticated=\(AuthManager.shared.isAuthenticated)")

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
                    Task {
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
    
    // Handle OAuth callback URLs
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.scheme == "repowhisper" {
                print("📥 Received OAuth callback: \(url)")
                // Handle the OAuth callback
                Task { @MainActor in
                    await AuthManager.shared.handleOAuthCallback(url: url)
                }
            }
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

