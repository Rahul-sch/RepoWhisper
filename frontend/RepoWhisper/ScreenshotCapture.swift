//
//  ScreenshotCapture.swift
//  RepoWhisper
//
//  Silent screenshot capture for Boss Mode - captures active window every 5 seconds.
//

import Foundation
import AppKit
import CoreGraphics
import ScreenCaptureKit

/// Handles silent screenshot capture
@MainActor
class ScreenshotCapture: ObservableObject {
    /// Shared singleton instance
    static let shared = ScreenshotCapture()
    
    /// Whether currently capturing
    @Published var isCapturing: Bool = false
    
    /// Latest screenshot data
    @Published var latestScreenshot: Data?
    
    /// Screenshot timer
    private var timer: Timer?
    
    /// Callback for screenshots
    var onScreenshot: ((Data) -> Void)?
    
    private init() {}

    /// Capture one active window for local OCR. Screenshot bytes never leave Swift.
    @MainActor
    func captureVisibleScreen() async throws -> VisibleScreenCapture {
        guard await requestPermission() else {
            throw ExplainVisibleFeatureError.screenPermissionDenied
        }

        var frontmost = NSWorkspace.shared.frontmostApplication
        let ownBundleID = Bundle.main.bundleIdentifier
        let hidApplication = frontmost?.bundleIdentifier == ownBundleID
        if hidApplication {
            NSApp.hide(nil)
            try? await Task.sleep(nanoseconds: 250_000_000)
            frontmost = NSWorkspace.shared.frontmostApplication
        }
        defer {
            if hidApplication { NSApp.unhideWithoutActivation() }
        }

        latestScreenshot = nil
        await captureActiveWindow()
        guard let imageData = latestScreenshot else {
            throw ExplainVisibleFeatureError.screenCaptureFailed
        }
        return VisibleScreenCapture(
            imageData: imageData,
            visibleApp: frontmost?.localizedName
        )
    }
    
    /// Request screen recording permission
    func requestPermission() async -> Bool {
        // Check if already authorized
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        
        // Request permission (triggers system dialog)
        // Note: CGRequestScreenCaptureAccess doesn't take parameters
        // The system will prompt the user, and we check status after
        CGRequestScreenCaptureAccess()
        
        // Wait a moment for user to respond, then check status
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return CGPreflightScreenCaptureAccess()
    }
    
    /// Start capturing screenshots every 5 seconds
    @discardableResult
    func startCapture() async -> Bool {
        guard !isCapturing else { return true }
        
        // Request permission
        guard await requestPermission() else {
            print("⚠️ Screen recording permission denied")
            return false
        }
        
        // Take initial screenshot
        await captureActiveWindow()
        
        // Set up timer for every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                await self.captureActiveWindow()
            }
        }
        
        isCapturing = true
        print("📸 Screenshot capture started (every 5s)")
        return true
    }
    
    /// Stop capturing screenshots
    func stopCapture() {
        timer?.invalidate()
        timer = nil
        isCapturing = false
        print("🛑 Screenshot capture stopped")
    }
    
    /// Capture the active window
    private func captureActiveWindow() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            )
            let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            if let processID,
               let window = content.windows.first(where: {
                   $0.owningApplication?.processID == processID &&
                   $0.frame.width > 100 && $0.frame.height > 100
               }) {
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int(window.frame.width * 2))
                configuration.height = max(1, Int(window.frame.height * 2))
                configuration.showsCursor = false
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
                store(image)
                return
            }

            guard let display = content.displays.first(where: {
                $0.displayID == CGMainDisplayID()
            }) ?? content.displays.first else { return }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            store(image)
        } catch {
            print("⚠️ Screenshot capture failed: \(error.localizedDescription)")
        }
    }

    private func store(_ image: CGImage) {
        let screenshotData = convertToPNG(image)
        guard !screenshotData.isEmpty else { return }
        latestScreenshot = screenshotData
        onScreenshot?(screenshotData)
    }
    
    /// Convert CGImage to PNG data
    private func convertToPNG(_ image: CGImage) -> Data {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        
        // Compress to reduce size (quality 0.7 for faster upload)
        guard let pngData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.7]
        ) else {
            // Fallback to PNG if JPEG fails
            return bitmapRep.representation(using: .png, properties: [:]) ?? Data()
        }
        
        return pngData
    }
}
