import Foundation
import AVFoundation
import StableRadioCore

/// Audio playback engine using AVAudioEngine
class AudioPlaybackEngine {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var format: AVAudioFormat?
    private let playbackQueue = DispatchQueue(label: "com.stableradio.playback", qos: .userInitiated)

    private var isPlaying = false
    private var scheduledBuffers = 0

    var onNeedsMoreData: (() -> Void)?

    init() {
        setupAudioSession()
    }

    deinit {
        stop()
    }

    func start(format audioFormat: AudioFormatConfig) throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()

        audioEngine = engine
        playerNode = player

        // Create AVAudioFormat
        guard let format = audioFormat.createAVAudioFormat() else {
            throw PlaybackError.formatCreationFailed
        }
        self.format = format

        // Attach player node
        engine.attach(player)

        // Connect to output
        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Start engine
        try engine.start()

        // Start player
        player.play()

        isPlaying = true
        print("[AudioPlaybackEngine] Started playback with format: \(format)")
    }

    func stop() {
        playerNode?.stop()
        audioEngine?.stop()

        playerNode = nil
        audioEngine = nil
        format = nil
        isPlaying = false
        scheduledBuffers = 0

        print("[AudioPlaybackEngine] Stopped playback")
    }

    func scheduleAudioData(_ data: Data) {
        guard let format = format,
              let playerNode = playerNode,
              isPlaying else {
            return
        }

        // Create PCM buffer from data
        let frameCount = UInt32(data.count) / UInt32(format.streamDescription.pointee.mBytesPerFrame)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("[AudioPlaybackEngine] Failed to create buffer")
            return
        }

        buffer.frameLength = frameCount

        // Copy data to buffer
        guard let channelData = buffer.int16ChannelData else { return }

        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Ptr = baseAddress.assumingMemoryBound(to: Int16.self)

            let channelCount = Int(format.channelCount)
            let framesPerChannel = Int(frameCount)

            if format.isInterleaved {
                // Interleaved format
                channelData[0].update(from: int16Ptr, count: Int(frameCount) * channelCount)
            } else {
                // Non-interleaved format
                for channel in 0..<channelCount {
                    for frame in 0..<framesPerChannel {
                        channelData[channel][frame] = int16Ptr[frame * channelCount + channel]
                    }
                }
            }
        }

        // Schedule buffer for playback
        scheduledBuffers += 1

        playerNode.scheduleBuffer(buffer) { [weak self] in
            self?.playbackQueue.async {
                self?.scheduledBuffers -= 1

                // Request more data when running low
                if let self = self, self.scheduledBuffers < 3 {
                    self.onNeedsMoreData?()
                }
            }
        }
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            print("[AudioPlaybackEngine] Audio session configured")
        } catch {
            print("[AudioPlaybackEngine] Failed to setup audio session: \(error)")
        }
    }
}

/// Playback errors
enum PlaybackError: Error {
    case formatCreationFailed
    case engineStartFailed
}
