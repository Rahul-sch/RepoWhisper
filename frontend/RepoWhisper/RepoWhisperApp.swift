//
//  RepoWhisperApp.swift
//  RepoWhisper
//
//  Main application entry point for the Mac menu bar app.
//

import SwiftUI

@main
struct RepoWhisperApp: App {
    @StateObject private var authManager = AuthManager.shared
    
    var body: some Scene {
        // Menu Bar Extra - the main interface
        MenuBarExtra {
            MenuBarView()
                .environmentObject(authManager)
        } label: {
            Image(systemName: "waveform.circle.fill")
        }
        .menuBarExtraStyle(.window)
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(authManager)
        }
        
        // Login window (shown when not authenticated)
        Window("RepoWhisper Login", id: "login") {
            LoginView()
                .environmentObject(authManager)
                .frame(width: 400, height: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

