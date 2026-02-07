import Foundation
import AVFoundation
import StableRadioCore

/// Audio capture engine using AVAudioEngine
class AudioCaptureEngine {
    private let deviceID: String
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    var onAudioData: ((Data) -> Void)?

    init(deviceID: String) {
        self.deviceID = deviceID
    }

    func start() throws {
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        self.inputNode = inputNode

        // Get input format (what the device provides)
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Define output format (what we want)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44100,
            channels: 2,
            interleaved: true
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }

        print("[AudioCaptureEngine] Input format: \(inputFormat)")
        print("[AudioCaptureEngine] Output format: \(outputFormat)")

        // Install tap on input node
        let bufferSize: AVAudioFrameCount = 4096

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, targetFormat: outputFormat)
        }

        // Start the engine
        try engine.start()
        print("[AudioCaptureEngine] Audio engine started")
    }

    func stop() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        print("[AudioCaptureEngine] Audio engine stopped")
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Convert float samples to Int16
        var int16Samples: [Int16] = []
        int16Samples.reserveCapacity(frameLength * channelCount)

        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let sample = channelData[channel][frame]
                let clampedSample = max(-1.0, min(1.0, sample))
                let int16Value = Int16(clampedSample * Float(Int16.max))
                int16Samples.append(int16Value)
            }
        }

        // Convert to Data
        let data = int16Samples.withUnsafeBytes { Data($0) }

        // Send to handler
        onAudioData?(data)
    }
}

/// Audio capture errors
enum AudioCaptureError: Error {
    case formatCreationFailed
    case engineStartFailed
    case deviceNotFound
}
