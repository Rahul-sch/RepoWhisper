//
//  MenuBarView.swift
//  RepoWhisper
//
//  Main menu bar interface with recording controls and mode selection.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var audioManager = AudioManager.shared
    
    @State private var selectedMode: IndexMode = .guided
    @State private var showingFilePicker = false
    @State private var repoPath: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if authManager.isAuthenticated {
                authenticatedView
            } else {
                unauthenticatedView
            }
        }
        .frame(width: 320)
    }
    
    // MARK: - Authenticated View
    
    private var authenticatedView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RepoWhisper")
                        .font(.headline)
                    Text(authManager.currentUser?.email ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    Task { await authManager.signOut() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            Divider()
            
            // Index Mode Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Index Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Mode", selection: $selectedMode) {
                    Label("Manual", systemImage: "hand.tap")
                        .tag(IndexMode.manual)
                    Label("Guided", systemImage: "sparkles")
                        .tag(IndexMode.guided)
                    Label("Full Repo", systemImage: "folder")
                        .tag(IndexMode.full)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 16)
            
            // Repo Path
            VStack(alignment: .leading, spacing: 8) {
                Text("Repository")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("Select a folder...", text: $repoPath)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                    
                    Button {
                        showingFilePicker = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            Divider()
            
            // Recording Control - Cluely-style button
            recordingButton
                .padding(.horizontal, 16)
            
            // Status
            if audioManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("Listening...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(audioManager.lastTranscription)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Text("⌘ + Shift + R to toggle")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(height: 340)
    }
    
    // MARK: - Recording Button
    
    private var recordingButton: some View {
        Button {
            audioManager.toggleRecording()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.title2)
                    .foregroundStyle(audioManager.isRecording ? .red : .purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioManager.isRecording ? "Stop Listening" : "Start Listening")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Click or use ⌘⇧R")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if audioManager.isRecording {
                    // Audio level indicator
                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i < audioManager.audioLevel ? Color.purple : Color.gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat(4 + i * 3))
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(audioManager.isRecording ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Unauthenticated View
    
    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.purple)
            
            Text("Sign in to RepoWhisper")
                .font(.headline)
            
            Text("Connect your account to start voice-powered code search.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Open Login") {
                NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(height: 200)
    }
}

// MARK: - Index Mode Enum

enum IndexMode: String, CaseIterable {
    case manual = "manual"
    case guided = "guided"
    case full = "full"
}

#Preview {
    MenuBarView()
        .environmentObject(AuthManager.shared)
}

