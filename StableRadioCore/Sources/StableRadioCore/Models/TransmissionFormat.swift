import Foundation

/// Audio codec types supported by StableRadio
public enum AudioCodec: UInt16, Codable {
    case pcm = 0        // Uncompressed PCM
    case imaADPCM = 1   // IMA ADPCM 4:1 compression
    case opus = 2       // Opus codec (optional, Phase 5+)
    case aacLC = 3      // AAC-LC codec (optional, Phase 5+)
}

/// Sample rate options
public enum SampleRate: UInt16, Codable {
    case rate22050 = 0  // 22.05 kHz
    case rate32000 = 1  // 32 kHz
    case rate44100 = 2  // 44.1 kHz (CD quality)
    case rate48000 = 3  // 48 kHz (studio quality)

    public var hertz: Int {
        switch self {
        case .rate22050: return 22050
        case .rate32000: return 32000
        case .rate44100: return 44100
        case .rate48000: return 48000
        }
    }
}

/// Bit depth options
public enum BitDepth: UInt16, Codable {
    case bit8 = 0
    case bit12 = 1
    case bit16 = 2
    case bit24 = 3

    public var bits: Int {
        switch self {
        case .bit8: return 8
        case .bit12: return 12
        case .bit16: return 16
        case .bit24: return 24
        }
    }
}

/// Channel configuration
public enum ChannelConfig: UInt16, Codable {
    case mono = 0
    case stereo = 1

    public var channelCount: Int {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        }
    }
}

/// Complete transmission format configuration
public struct TransmissionFormat: Codable, Equatable, Hashable {
    public let sampleRate: SampleRate
    public let bitDepth: BitDepth
    public let channels: ChannelConfig
    public let codec: AudioCodec
    public let codecBitrate: Int? // Optional bitrate for compressed codecs (kbps)

    public init(
        sampleRate: SampleRate,
        bitDepth: BitDepth,
        channels: ChannelConfig,
        codec: AudioCodec,
        codecBitrate: Int? = nil
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.codec = codec
        self.codecBitrate = codecBitrate
    }

    /// Calculate estimated bandwidth in kilobits per second
    public var estimatedBandwidthKbps: Int {
        switch codec {
        case .pcm:
            // Uncompressed: sample_rate * bit_depth * channels
            let bitsPerSecond = sampleRate.hertz * bitDepth.bits * channels.channelCount
            // Add 10% overhead for UDP headers, sequence numbers, etc.
            return Int(Double(bitsPerSecond) * 1.1 / 1000.0)

        case .imaADPCM:
            // ADPCM compresses 16-bit to 4-bit (4:1 ratio)
            let bitsPerSecond = sampleRate.hertz * 4 * channels.channelCount
            return Int(Double(bitsPerSecond) * 1.1 / 1000.0)

        case .opus, .aacLC:
            // Use configured bitrate + 10% overhead
            return Int(Double(codecBitrate ?? 128) * 1.1)
        }
    }

    /// Encode format as 16-bit flags for packet header
    public var encodedFlags: UInt16 {
        var flags: UInt16 = 0

        // Bits 0-2: Sample rate
        flags |= sampleRate.rawValue & 0x07

        // Bits 3-5: Bit depth
        flags |= (bitDepth.rawValue & 0x07) << 3

        // Bit 6: Channels
        flags |= (channels.rawValue & 0x01) << 6

        // Bits 7-10: Codec
        flags |= (codec.rawValue & 0x0F) << 7

        return flags
    }

    /// Decode format from 16-bit flags
    public static func decode(flags: UInt16) -> TransmissionFormat? {
        guard let sampleRate = SampleRate(rawValue: flags & 0x07),
              let bitDepth = BitDepth(rawValue: (flags >> 3) & 0x07),
              let channels = ChannelConfig(rawValue: (flags >> 6) & 0x01),
              let codec = AudioCodec(rawValue: (flags >> 7) & 0x0F) else {
            return nil
        }

        return TransmissionFormat(
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channels,
            codec: codec
        )
    }
}

// MARK: - Quality Presets

public extension TransmissionFormat {
    /// Ultra Low quality preset - ideal for voice/podcasts on poor networks
    static let ultraLow = TransmissionFormat(
        sampleRate: .rate22050,
        bitDepth: .bit8,
        channels: .mono,
        codec: .pcm
    )

    /// Low quality preset - speech optimized with compression
    static let low = TransmissionFormat(
        sampleRate: .rate32000,
        bitDepth: .bit12,
        channels: .mono,
        codec: .imaADPCM
    )

    /// Medium quality preset - mono music
    static let medium = TransmissionFormat(
        sampleRate: .rate44100,
        bitDepth: .bit16,
        channels: .mono,
        codec: .pcm
    )

    /// Medium+ quality preset - compressed mono music
    static let mediumPlus = TransmissionFormat(
        sampleRate: .rate44100,
        bitDepth: .bit16,
        channels: .mono,
        codec: .opus,
        codecBitrate: 64
    )

    /// High quality preset - CD quality stereo
    static let high = TransmissionFormat(
        sampleRate: .rate44100,
        bitDepth: .bit16,
        channels: .stereo,
        codec: .pcm
    )

    /// High+ quality preset - compressed stereo
    static let highPlus = TransmissionFormat(
        sampleRate: .rate44100,
        bitDepth: .bit16,
        channels: .stereo,
        codec: .opus,
        codecBitrate: 128
    )

    /// Maximum quality preset - studio quality
    static let maximum = TransmissionFormat(
        sampleRate: .rate48000,
        bitDepth: .bit16,
        channels: .stereo,
        codec: .pcm
    )

    /// Get preset name
    var presetName: String? {
        switch self {
        case .ultraLow: return "Ultra Low"
        case .low: return "Low"
        case .medium: return "Medium"
        case .mediumPlus: return "Medium+"
        case .high: return "High"
        case .highPlus: return "High+"
        case .maximum: return "Maximum"
        default: return nil
        }
    }

    /// Check if this format matches a preset
    var isPreset: Bool {
        return presetName != nil
    }
}

// MARK: - Description

extension TransmissionFormat: CustomStringConvertible {
    public var description: String {
        let rateKHz = Double(sampleRate.hertz) / 1000.0
        let codecName: String
        switch codec {
        case .pcm: codecName = "PCM"
        case .imaADPCM: codecName = "ADPCM"
        case .opus: codecName = "Opus"
        case .aacLC: codecName = "AAC-LC"
        }

        let channelName = channels == .mono ? "Mono" : "Stereo"
        let bitrateInfo = codecBitrate.map { " @ \($0)kbps" } ?? ""

        return "\(rateKHz)kHz \(bitDepth.bits)-bit \(channelName) (\(codecName)\(bitrateInfo)) - ~\(estimatedBandwidthKbps)kbps"
    }
}
