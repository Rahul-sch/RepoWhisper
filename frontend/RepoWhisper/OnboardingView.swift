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
        ZStack {
            RWAmbientBackground()
            VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                RWBrandMark(size: 52)

                Text("Meet your codebase")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(RWTheme.text)

                Text("Private, screen-aware code intelligence that stays on your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(RWTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 390)
            }
            .padding(.top, 8)

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
            .padding(.horizontal, 18)

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
            .padding(32)
            .rwGlass(radius: 24, emphasized: true)
            .padding(28)
        }
        .frame(minWidth: 620, minHeight: 620)
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
                .foregroundStyle(RWTheme.accentBright)
                .frame(width: 32, height: 32)
                .background(RWTheme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RWTheme.text)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(RWTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(RWTheme.surface.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
    }
}

#if canImport(PreviewsMacros)
#Preview {
    OnboardingView(onComplete: {})
}
#endif
