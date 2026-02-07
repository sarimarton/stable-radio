import Foundation
import StableRadioCore

/// Adaptive buffer for handling network jitter and packet loss
class AdaptiveBuffer {
    private let packetBuffer: PacketRingBuffer
    private let smoothBuffer: RingBuffer
    private let maxBufferSeconds: TimeInterval
    private let format: AudioFormatConfig

    private var lastReadSequence: UInt32 = 0
    private var packetsReceived: UInt64 = 0
    private var packetsLost: UInt64 = 0

    /// Current fill level (0.0 to 1.0)
    var fillLevel: Float {
        return packetBuffer.fillLevel
    }

    /// Should start playback (buffer is sufficiently filled)
    var shouldStartPlayback: Bool {
        return fillLevel >= 0.3 // Start at 30% full
    }

    /// Should pause playback (buffer too low)
    var shouldPausePlayback: Bool {
        return fillLevel < 0.1 // Pause below 10%
    }

    /// Packet loss percentage
    var packetLossPercentage: Double {
        let total = packetsReceived + packetsLost
        guard total > 0 else { return 0 }
        return Double(packetsLost) / Double(total) * 100.0
    }

    init(maxBufferSeconds: TimeInterval = 10.0, format: AudioFormatConfig) {
        self.maxBufferSeconds = maxBufferSeconds
        self.format = format

        let maxBufferBytes = Int(Double(format.bytesPerSecond) * maxBufferSeconds)
        self.packetBuffer = PacketRingBuffer(maxBufferSize: maxBufferBytes)
        self.smoothBuffer = RingBuffer(capacity: maxBufferBytes)

        print("[AdaptiveBuffer] Initialized with \(maxBufferSeconds)s buffer (\(maxBufferBytes) bytes)")
    }

    /// Insert received packet
    func insertPacket(_ packet: AudioPacket) {
        guard packet.type == .audioData else { return }

        packetsReceived += 1

        // Insert into packet buffer
        packetBuffer.insert(sequence: packet.sequence, data: packet.payload)

        // Detect and handle missing packets
        let missing = packetBuffer.detectMissing(maxGapSize: 10)
        if !missing.isEmpty {
            packetsLost += UInt64(missing.count)

            // Fill gaps with silence
            for missingSeq in missing {
                let silenceData = AudioConverter.generateSilence(duration: 0.01, format: format)
                packetBuffer.insert(sequence: missingSeq, data: silenceData)
            }
        }
    }

    /// Read audio data for playback
    /// Returns nil if not enough data available
    func readAudioData(frameCount: Int) -> Data? {
        let bytesNeeded = frameCount * format.bytesPerFrame

        // Try to read from smooth buffer first
        if smoothBuffer.available >= bytesNeeded {
            return smoothBuffer.read(count: bytesNeeded)
        }

        // Fill smooth buffer from packet buffer
        while packetBuffer.hasNext() && smoothBuffer.freeSpace > 0 {
            if let packetData = packetBuffer.readNext() {
                smoothBuffer.write(packetData)
            } else {
                break
            }
        }

        // Try reading again
        if smoothBuffer.available >= bytesNeeded {
            return smoothBuffer.read(count: bytesNeeded)
        }

        // Not enough data
        return nil
    }

    /// Clear all buffered data
    func clear() {
        packetBuffer.clear()
        smoothBuffer.clear()
        lastReadSequence = 0
        packetsReceived = 0
        packetsLost = 0
    }

    /// Reset to specific sequence number
    func reset(to sequence: UInt32) {
        clear()
        packetBuffer.reset(to: sequence)
        lastReadSequence = sequence
    }
}
