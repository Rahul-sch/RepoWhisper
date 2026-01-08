//
//  AudioCapture.swift
//  RepoWhisper
//
//  Real-time microphone capture using AVAudioEngine.
//  Streams PCM audio to the Python backend for transcription.
//

import Foundation
import AVFoundation
import Combine

/// Handles real-time microphone audio capture
@MainActor
class AudioCapture: ObservableObject {
    /// Shared singleton instance
    static let shared = AudioCapture()
    
    /// Whether currently recording
    @Published var isRecording: Bool = false
    
    /// Current audio level (0-1) for visualization
    @Published var audioLevel: Float = 0.0
    
    /// Error message if capture fails
    @Published var errorMessage: String?
    
    /// Audio engine for capture
    private var audioEngine: AVAudioEngine?
    
    /// Buffer for accumulating audio samples
    private var audioBuffer: Data = Data()
    
    /// Target sample rate (16kHz for Whisper)
    private let targetSampleRate: Double = 16000
    
    /// Chunk duration in seconds before sending to backend
    private let chunkDuration: Double = 1.0
    
    /// Callback for when audio chunk is ready
    var onAudioChunk: ((Data) -> Void)?
    
    private init() {}
    
    /// Request microphone permission
    func requestPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Start recording audio
    func startRecording() {
        guard !isRecording else { return }
        
        do {
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            // Calculate buffer size for ~100ms chunks
            let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)
            
            // Install tap on input node
            inputNode.installTap(
                onBus: 0,
                bufferSize: bufferSize,
                format: inputFormat
            ) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer, format: inputFormat)
            }
            
            // Start the engine
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            errorMessage = nil
            print("🎤 Audio capture started")
            
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("❌ Audio capture error: \(error)")
        }
    }
    
    /// Stop recording audio
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        // Flush remaining audio
        if !audioBuffer.isEmpty {
            onAudioChunk?(audioBuffer)
            audioBuffer.removeAll()
        }
        
        isRecording = false
        audioLevel = 0.0
        print("🛑 Audio capture stopped")
    }
    
    /// Process captured audio buffer
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        
        // Calculate audio level for visualization
        var sum: Float = 0
        for i in 0..<frameCount {
            sum += abs(channelData[i])
        }
        let avgLevel = sum / Float(frameCount)
        
        DispatchQueue.main.async {
            self.audioLevel = min(avgLevel * 5, 1.0) // Scale for visibility
        }
        
        // Convert to 16kHz mono PCM16
        let convertedData = convertToPCM16(
            buffer: buffer,
            sourceRate: format.sampleRate,
            targetRate: targetSampleRate
        )
        
        audioBuffer.append(convertedData)
        
        // Check if we have enough audio for a chunk
        let bytesPerSecond = Int(targetSampleRate) * 2 // 16-bit = 2 bytes
        let chunkBytes = Int(Double(bytesPerSecond) * chunkDuration)
        
        if audioBuffer.count >= chunkBytes {
            let chunk = audioBuffer.prefix(chunkBytes)
            onAudioChunk?(Data(chunk))
            audioBuffer.removeFirst(chunkBytes)
        }
    }
    
    /// Convert audio buffer to 16kHz mono PCM16
    private func convertToPCM16(
        buffer: AVAudioPCMBuffer,
        sourceRate: Double,
        targetRate: Double
    ) -> Data {
        guard let channelData = buffer.floatChannelData?[0] else {
            return Data()
        }
        
        let frameCount = Int(buffer.frameLength)
        let ratio = sourceRate / targetRate
        let outputFrameCount = Int(Double(frameCount) / ratio)
        
        var outputData = Data(capacity: outputFrameCount * 2)
        
        for i in 0..<outputFrameCount {
            let sourceIndex = Int(Double(i) * ratio)
            if sourceIndex < frameCount {
                // Convert float32 to int16
                let sample = channelData[sourceIndex]
                let clampedSample = max(-1.0, min(1.0, sample))
                let int16Sample = Int16(clampedSample * 32767)
                
                withUnsafeBytes(of: int16Sample.littleEndian) { bytes in
                    outputData.append(contentsOf: bytes)
                }
            }
        }
        
        return outputData
    }
    
    /// Toggle recording state
    func toggle() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}

