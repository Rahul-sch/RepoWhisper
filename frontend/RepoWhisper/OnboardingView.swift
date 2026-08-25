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
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(OverlayTheme.accent)
                    .frame(width: 52, height: 52)
                    .background(OverlayTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))

                Text("Welcome to RepoWhisper")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(OverlayTheme.textPrimary)

                Text("Ask questions about your code without leaving your flow.")
                    .font(.system(size: 13))
                    .foregroundStyle(OverlayTheme.textSecondary)
            }
            .padding(.top, 32)

            // Explanation
            VStack(alignment: .leading, spacing: 10) {
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
            .padding(.horizontal, 44)

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
                    .padding(.vertical, 13)
                    .background(OverlayTheme.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: OverlayTheme.controlRadius))
                }
                .buttonStyle(.plain)

                Text("You can always add more repositories later")
                    .font(.caption)
                    .foregroundStyle(OverlayTheme.textSecondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 560, height: 620)
        .background(OverlayTheme.canvas)
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
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OverlayTheme.accent)
                .frame(width: 34, height: 34)
                .background(OverlayTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(OverlayTheme.textPrimary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(OverlayTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(OverlayTheme.elevated.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(OverlayTheme.border, lineWidth: 1))
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
