import Foundation
import AVFoundation

/// Audio format constants and utilities
public struct AudioFormatConfig {
    public let sampleRate: Double
    public let bitDepth: Int
    public let channels: Int
    public let isInterleaved: Bool

    public init(sampleRate: Double, bitDepth: Int, channels: Int, isInterleaved: Bool = true) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.isInterleaved = isInterleaved
    }

    /// Create from TransmissionFormat
    public init(from format: TransmissionFormat) {
        self.sampleRate = Double(format.sampleRate.hertz)
        self.bitDepth = format.bitDepth.bits
        self.channels = format.channels.channelCount
        self.isInterleaved = true
    }

    /// Create AVAudioFormat for this configuration
    public func createAVAudioFormat() -> AVAudioFormat? {
        let commonFormat: AVAudioCommonFormat

        switch bitDepth {
        case 8, 12, 16:
            commonFormat = .pcmFormatInt16
        case 24:
            commonFormat = .pcmFormatInt32
        default:
            commonFormat = .pcmFormatInt16
        }

        return AVAudioFormat(
            commonFormat: commonFormat,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channels),
            interleaved: isInterleaved
        )
    }

    /// Bytes per frame
    public var bytesPerFrame: Int {
        return (bitDepth / 8) * channels
    }

    /// Bytes per second
    public var bytesPerSecond: Int {
        return Int(sampleRate) * bytesPerFrame
    }
}

/// Audio conversion utilities
public struct AudioConverter {
    /// Convert Int16 PCM data to Float32 for AVAudioEngine
    public static func int16ToFloat32(_ data: Data) -> [Float] {
        let int16Count = data.count / 2
        var floats = [Float](repeating: 0, count: int16Count)

        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Ptr = baseAddress.assumingMemoryBound(to: Int16.self)

            for i in 0..<int16Count {
                floats[i] = Float(int16Ptr[i]) / Float(Int16.max)
            }
        }

        return floats
    }

    /// Convert Float32 to Int16 PCM data
    public static func float32ToInt16(_ floats: [Float]) -> Data {
        var data = Data(count: floats.count * 2)

        data.withUnsafeMutableBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            let int16Ptr = baseAddress.assumingMemoryBound(to: Int16.self)

            for i in 0..<floats.count {
                let clamped = max(-1.0, min(1.0, floats[i]))
                int16Ptr[i] = Int16(clamped * Float(Int16.max))
            }
        }

        return data
    }

    /// Generate silence data
    public static func generateSilence(duration: TimeInterval, format: AudioFormatConfig) -> Data {
        let byteCount = Int(duration * Double(format.bytesPerSecond))
        return Data(count: byteCount)
    }

    /// Calculate duration of audio data
    public static func duration(of data: Data, format: AudioFormatConfig) -> TimeInterval {
        let bytes = data.count
        return TimeInterval(bytes) / TimeInterval(format.bytesPerSecond)
    }
}
