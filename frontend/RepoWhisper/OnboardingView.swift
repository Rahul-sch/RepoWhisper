//
//  OnboardingView.swift
//  RepoWhisper
//
//  First-run onboarding screen for repository access.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var bookmarkManager = SecurityScopedBookmarkManager.shared
    @State private var showError = false
    @State private var errorMessage = ""

    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Welcome to RepoWhisper")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Voice-powered code search")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            // Explanation
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield",
                    title: "Privacy First",
                    description: "All processing happens locally. Your code never leaves your Mac."
                )

                FeatureRow(
                    icon: "folder.badge.plus",
                    title: "Secure Access",
                    description: "Grant access only to specific folders. RepoWhisper can't access anything else."
                )

                FeatureRow(
                    icon: "magnifyingglass",
                    title: "Smart Search",
                    description: "Find code using natural language. Just describe what you're looking for."
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            // Call to action
            VStack(spacing: 16) {
                Button(action: addFirstRepository) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Add Your First Repository")
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
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Text("You can always add more repositories later")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 600, height: 700)
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage)
        }
    }

    private func addFirstRepository() {
        Task { @MainActor in
            do {
                if let _ = try bookmarkManager.addFolder() {
                    try bookmarkManager.writeAllowlistFile()
                    onComplete()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
