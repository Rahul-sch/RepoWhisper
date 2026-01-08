//
//  ScreenshotCapture.swift
//  RepoWhisper
//
//  Silent screenshot capture for Boss Mode - captures active window every 5 seconds.
//

import Foundation
import AppKit
import CoreGraphics

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
    
    /// Request screen recording permission
    func requestPermission() async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }
        
        return await withCheckedContinuation { continuation in
            CGRequestScreenCaptureAccess { (granted: Bool) in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Start capturing screenshots every 5 seconds
    func startCapture() async {
        guard !isCapturing else { return }
        
        // Request permission
        guard await requestPermission() else {
            print("⚠️ Screen recording permission denied")
            return
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
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            // Fallback to main display
            captureMainDisplay()
            return
        }
        
        // Find the frontmost window from the active app
        let activeWindow = windows.first { window in
            guard let ownerName = window[kCGWindowOwnerName as String] as? String,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat else {
                return false
            }
            
            return ownerName == frontmostApp.localizedName && width > 100 && height > 100
        }
        
        if let window = activeWindow,
           let windowID = window[kCGWindowNumber as String] as? CGWindowID,
           let bounds = window[kCGWindowBounds as String] as? [String: Any],
           let x = bounds["X"] as? CGFloat,
           let y = bounds["Y"] as? CGFloat,
           let width = bounds["Width"] as? CGFloat,
           let height = bounds["Height"] as? CGFloat {
            
            // Capture specific window
            if let image = CGWindowListCreateImage(
                CGRect(x: x, y: y, width: width, height: height),
                .optionIncludingWindow,
                windowID,
                .bestResolution
            ) {
                let screenshotData = convertToPNG(image)
                latestScreenshot = screenshotData
                onScreenshot?(screenshotData)
                return
            }
        }
        
        // Fallback to main display
        captureMainDisplay()
    }
    
    /// Capture main display as fallback
    private func captureMainDisplay() {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else { return }
        
        let screenshotData = convertToPNG(image)
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

