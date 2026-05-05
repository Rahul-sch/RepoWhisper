//
//  ScreenCaptureManager.swift
//  RepoWhisper
//
//  Boss Mode: Captures system audio and screenshots using ScreenCaptureKit.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

/// Manages system audio capture and screenshot capture for Boss Mode
@MainActor
class ScreenCaptureManager: ObservableObject {
    /// Shared singleton instance
    static let shared = ScreenCaptureManager()
    
    /// Whether currently capturing system audio
    @Published var isCapturingSystemAudio: Bool = false
    
    /// Whether currently capturing screenshots
    @Published var isCapturingScreenshots: Bool = false
    
    /// Latest screenshot data
    @Published var latestScreenshot: Data?
    
    /// Error message if capture fails
    @Published var errorMessage: String?
    
    /// System audio stream
    private var systemAudioStream: SCStream?
    private var systemAudioBuffer: Data = Data()
    
    /// Screenshot timer
    private var screenshotTimer: Timer?
    
    /// Callback for system audio chunks
    var onSystemAudioChunk: ((Data) -> Void)?
    
    /// Callback for screenshots
    var onScreenshot: ((Data) -> Void)?
    
    private init() {}
    
    // MARK: - Permissions
    
    /// Request screen recording permission
    func requestScreenRecordingPermission() async -> Bool {
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
    
    // MARK: - System Audio Capture
    
    /// Start capturing system audio
    func startSystemAudioCapture() async {
        guard !isCapturingSystemAudio else { return }
        
        // Check permission
        guard await requestScreenRecordingPermission() else {
            errorMessage = "Screen recording permission required for system audio"
            return
        }
        
        do {
            // Get available content (system audio)
            // First get shareable content to create filter
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                errorMessage = "No display available for capture"
                return
            }
            
            // Create filªter for the display
            let filter = SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: []
            )
            
            // Configure stream for audio only
            let streamConfig = SCStreamConfiguration()
            streamConfig.capturesAudio = true
            streamConfig.excludesCurrentProcessAudio = false
            streamConfig.sampleRate = 48000
            streamConfig.channelCount = 2
            
            // Create stream delegate
            let delegate = SystemAudioStreamDelegate { [weak self] sampleBuffer in
                self?.processSystemAudio(sampleBuffer)
            }
            
            // Create stream
            let stream = SCStream(filter: filter, configuration: streamConfig, delegate: delegate)
            
            // Add audio stream output
            try stream.addStreamOutput(
                delegate,
                type: SCStreamOutputType.audio,
                sampleHandlerQueue: DispatchQueue(label: "system.audio.queue")
            )
            
            // Start stream
            try await stream.startCapture()
            
            systemAudioStream = stream
            isCapturingSystemAudio = true
            errorMessage = nil
            print("🔊 System audio capture started")
            
        } catch {
            errorMessage = "Failed to start system audio capture: \(error.localizedDescription)"
            print("❌ System audio capture error: \(error)")
        }
    }
    
    /// Stop capturing system audio
    func stopSystemAudioCapture() {
        guard isCapturingSystemAudio else { return }
        
        Task {
            try? await systemAudioStream?.stopCapture()
            systemAudioStream = nil
            isCapturingSystemAudio = false
            systemAudioBuffer.removeAll()
            print("🛑 System audio capture stopped")
        }
    }
    
    /// Process system audio sample buffer
    private func processSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        
        // Convert to 16kHz mono PCM16 (same as microphone)
        let convertedData = convertSystemAudioToPCM16(sampleBuffer, formatDescription)
        
        systemAudioBuffer.append(convertedData)
        
        // Send chunks (1 second duration)
        let bytesPerSecond = 16000 * 2 // 16kHz, 16-bit
        if systemAudioBuffer.count >= bytesPerSecond {
            let chunk = systemAudioBuffer.prefix(bytesPerSecond)
            onSystemAudioChunk?(Data(chunk))
            systemAudioBuffer.removeFirst(bytesPerSecond)
        }
    }
    
    /// Convert SCStream audio (typically 48 kHz Float32 stereo) into the
    /// 16 kHz mono Int16 PCM that the Whisper backend expects.
    /// Returns empty Data if the format can't be read or conversion fails.
    private func convertSystemAudioToPCM16(_ sampleBuffer: CMSampleBuffer, _ formatDescription: CMFormatDescription) -> Data {
        guard let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return Data()
        }
        var asbd = asbdPtr.pointee
        guard let sourceFormat = AVAudioFormat(streamDescription: &asbd) else {
            return Data()
        }

        let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frames > 0,
              let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frames) else {
            return Data()
        }
        sourceBuffer.frameLength = frames

        // Pull the audio bytes out of the CMSampleBuffer into the PCM buffer.
        // withAudioBufferList handles ABL sizing for multi-channel non-interleaved data.
        do {
            try sampleBuffer.withAudioBufferList { srcABL, _ in
                let dstABL = UnsafeMutableAudioBufferListPointer(sourceBuffer.mutableAudioBufferList)
                for i in 0..<min(srcABL.count, dstABL.count) {
                    if let src = srcABL[i].mData, let dst = dstABL[i].mData {
                        let bytes = Int(min(srcABL[i].mDataByteSize, dstABL[i].mDataByteSize))
                        memcpy(dst, src, bytes)
                    }
                }
            }
        } catch {
            return Data()
        }

        guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: 16000,
                channels: 1,
                interleaved: true
              ),
              let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return Data()
        }

        // Generous capacity for resampling slack.
        let outCapacity = AVAudioFrameCount(
            Double(frames) * 16000.0 / sourceFormat.sampleRate + 1024
        )
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else {
            return Data()
        }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: targetBuffer, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        guard status != .error, error == nil,
              let channel = targetBuffer.int16ChannelData?[0] else {
            return Data()
        }

        let outFrames = Int(targetBuffer.frameLength)
        return Data(bytes: channel, count: outFrames * 2)
    }
    
    // MARK: - Screenshot Capture
    
    /// Start capturing screenshots every 5 seconds
    func startScreenshotCapture() async {
        guard !isCapturingScreenshots else { return }
        
        // Check permission
        guard await requestScreenRecordingPermission() else {
            errorMessage = "Screen recording permission required for screenshots"
            return
        }
        
        // Take initial screenshot
        await captureScreenshot()
        
        // Set up timer for every 5 seconds
        screenshotTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.captureScreenshot()
            }
        }
        
        isCapturingScreenshots = true
        errorMessage = nil
        print("📸 Screenshot capture started (every 5s)")
    }
    
    /// Stop capturing screenshots
    func stopScreenshotCapture() {
        screenshotTimer?.invalidate()
        screenshotTimer = nil
        isCapturingScreenshots = false
        print("🛑 Screenshot capture stopped")
    }
    
    /// Capture a screenshot of the active window
    private func captureScreenshot() async {
        guard let window = await getActiveWindow() else {
            // Fallback to main display if no active window
            captureMainDisplay()
            return
        }
        
        // Capture specific window
        do {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false
            
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            // Capture frame
            try await stream.startCapture()
            
            // Get screenshot data (simplified - use proper frame capture in production)
            // This is a placeholder - actual implementation needs frame callback
            
            try? await stream.stopCapture()
            
        } catch {
            // Fallback to main display
            captureMainDisplay()
        }
    }
    
    /// Capture main display as fallback
    private func captureMainDisplay() {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else { return }
        
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { return }
        
        latestScreenshot = pngData
        onScreenshot?(pngData)
    }
    
    /// Get the currently active window
    private func getActiveWindow() async -> SCWindow? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            let windows = content.windows
            
            // Find the frontmost window
            return windows.first { window in
                window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
            }
        } catch {
            return nil
        }
    }
    
    // MARK: - Combined Control
    
    /// Start Boss Mode (system audio + screenshots)
    func startBossMode() async {
        await startSystemAudioCapture()
        await startScreenshotCapture()
    }
    
    /// Stop Boss Mode
    func stopBossMode() {
        stopSystemAudioCapture()
        stopScreenshotCapture()
    }
}

// MARK: - Stream Delegate & Output

private class SystemAudioStreamDelegate: NSObject, SCStreamDelegate, SCStreamOutput {
    let onSampleBuffer: (CMSampleBuffer) -> Void
    
    init(onSampleBuffer: @escaping (CMSampleBuffer) -> Void) {
        self.onSampleBuffer = onSampleBuffer
    }
    
    // SCStreamDelegate method
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream stopped with error: \(error)")
    }
    
    // SCStreamOutput method
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        if type == .audio {
            onSampleBuffer(sampleBuffer)
        }
    }
}

