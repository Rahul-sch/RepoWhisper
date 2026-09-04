//
//  ScreenCaptureManager.swift
//  RepoWhisper
//
//  Captures system audio using ScreenCaptureKit.
//

import Foundation
import ScreenCaptureKit
import AVFoundation
import AppKit

/// Manages system audio capture for voice search and meeting mode.
@MainActor
class ScreenCaptureManager: ObservableObject {
    /// Shared singleton instance
    static let shared = ScreenCaptureManager()
    
    /// Whether currently capturing system audio
    @Published var isCapturingSystemAudio: Bool = false
    
    /// Error message if capture fails
    @Published var errorMessage: String?
    
    /// System audio stream
    private var systemAudioStream: SCStream?
    private var systemAudioBuffer: Data = Data()
    
    /// Callback for system audio chunks
    var onSystemAudioChunk: ((Data) -> Void)?
    
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
