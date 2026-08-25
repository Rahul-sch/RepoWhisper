//
//  SettingsView.swift
//  RepoWhisper
//
//  Settings and diagnostics - Phase C.5
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @StateObject private var backendManager = BackendProcessManager.shared
    @AppStorage("startBackendOnLaunch") private var startBackendOnLaunch = true

    @State private var showAuditOutput = false
    @State private var auditOutput = ""
    @State private var isRunningAudit = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gearshape.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(OverlayTheme.accent)
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OverlayTheme.textPrimary)
                Spacer()
            }
            .padding(20)
            .background(OverlayTheme.canvas)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // General Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Label("General", systemImage: "slider.horizontal.3")
                            .font(.headline)

                        Toggle(isOn: $startBackendOnLaunch) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start backend on launch")
                                    .font(.body)
                                Text("Automatically start the search backend when app opens")
                                    .font(.caption)
                                    .foregroundStyle(OverlayTheme.textSecondary)
                            }
                        }
                        .toggleStyle(.switch)
                        .padding(.vertical, 8)
                    }
                    .padding()
                    .background(OverlayTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(OverlayTheme.border))

                    // Backend Status
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Backend Status", systemImage: "server.rack")
                            .font(.headline)

                        VStack(spacing: 12) {
                            statusRow(
                                icon: "circle.fill",
                                iconColor: statusColor,
                                title: "Status",
                                value: backendManager.statusMessage
                            )

                            if backendManager.isHealthy {
                                statusRow(
                                    icon: "doc.text.fill",
                                    iconColor: OverlayTheme.accent,
                                    title: "Indexed Chunks",
                                    value: "\(backendManager.indexCount)"
                                )
                            }

                            statusRow(
                                icon: "bolt.fill",
                                iconColor: .orange,
                                title: "Process",
                                value: backendManager.isRunning ? "Running" : "Stopped"
                            )
                        }
                    }
                    .padding()
                    .background(OverlayTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(OverlayTheme.border))

                    // Diagnostics
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Diagnostics", systemImage: "wrench.and.screwdriver.fill")
                            .font(.headline)

                        Button(action: openLogs) {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(OverlayTheme.accent)
                                Text("Open Logs Directory")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(OverlayTheme.textSecondary)
                            }
                            .padding()
                            .background(OverlayTheme.canvas.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)

                        Button(action: runAuditScript) {
                            HStack {
                                if isRunningAudit {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundStyle(OverlayTheme.success)
                                }
                                Text(isRunningAudit ? "Running Audit..." : "Run Security Audit")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "play.circle")
                                    .foregroundStyle(OverlayTheme.textSecondary)
                            }
                            .padding()
                            .background(OverlayTheme.canvas.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .disabled(isRunningAudit)
                    }
                    .padding()
                    .background(OverlayTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(OverlayTheme.border))

                    // App Info
                    VStack(alignment: .leading, spacing: 12) {
                        Label("About RepoWhisper", systemImage: "info.circle.fill")
                            .font(.headline)

                        VStack(spacing: 8) {
                            infoRow(label: "Version", value: appVersion)
                            infoRow(label: "Build", value: appBuild)
                            infoRow(label: "Bundle ID", value: bundleIdentifier)
                        }
                    }
                    .padding()
                    .background(OverlayTheme.elevated)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(OverlayTheme.border))
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .sheet(isPresented: $showAuditOutput) {
            auditOutputView
        }
    }

    // MARK: - Status Row

    @ViewBuilder
    private func statusRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(OverlayTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Info Row

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(OverlayTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(OverlayTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Audit Output View

    private var auditOutputView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Security Audit Results")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    showAuditOutput = false
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            // Output
            ScrollView {
                Text(auditOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.primary.opacity(0.03))
        }
        .frame(width: 600, height: 400)
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch backendManager.status {
        case .healthy:
            return OverlayTheme.success
        case .starting:
            return .yellow
        case .stopped:
            return .gray
        case .error:
            return OverlayTheme.danger
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "Unknown"
    }

    // MARK: - Actions

    private func openLogs() {
        let logsPath = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("RepoWhisper")
            .appendingPathComponent("logs")

        if let logsPath = logsPath {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logsPath.path)
        }
    }

    private func runAuditScript() {
        isRunningAudit = true
        auditOutput = "Running security audit...\n\n"

        Task {
            do {
                // Find project root (go up from app bundle)
                let bundlePath = Bundle.main.bundlePath
                let projectRoot = (bundlePath as NSString).deletingLastPathComponent
                let parentRoot = (projectRoot as NSString).deletingLastPathComponent
                let auditScript = (parentRoot as NSString).appendingPathComponent("scripts/audit_secrets.sh")

                // Check if script exists
                guard FileManager.default.fileExists(atPath: auditScript) else {
                    await MainActor.run {
                        auditOutput = "❌ Audit script not found at: \(auditScript)\n\nMake sure you're running from the development environment."
                        isRunningAudit = false
                        showAuditOutput = true
                    }
                    return
                }

                // Run the audit script
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = [auditScript]
                process.currentDirectoryURL = URL(fileURLWithPath: parentRoot)

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "No output"

                await MainActor.run {
                    if process.terminationStatus == 0 {
                        auditOutput = "✅ Security Audit Passed\n\n" + output
                    } else {
                        auditOutput = "❌ Security Audit Failed\n\n" + output
                    }
                    isRunningAudit = false
                    showAuditOutput = true
                }
            } catch {
                await MainActor.run {
                    auditOutput = "❌ Failed to run audit: \(error.localizedDescription)"
                    isRunningAudit = false
                    showAuditOutput = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
