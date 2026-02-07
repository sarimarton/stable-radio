import Foundation
import AVFoundation

/// Audio codec encoder/decoder protocol
public protocol AudioCodecProtocol {
    func encode(_ data: Data, format: TransmissionFormat) throws -> Data
    func decode(_ data: Data, format: TransmissionFormat) throws -> Data
}

/// PCM codec (uncompressed, passthrough)
public class PCMCodec: AudioCodecProtocol {
    public init() {}

    public func encode(_ data: Data, format: TransmissionFormat) throws -> Data {
        // PCM is uncompressed, just pass through
        return data
    }

    public func decode(_ data: Data, format: TransmissionFormat) throws -> Data {
        // PCM is uncompressed, just pass through
        return data
    }
}

/// IMA ADPCM codec (4:1 compression)
public class IMADPCMCodec: AudioCodecProtocol {
    public init() {}

    public func encode(_ data: Data, format: TransmissionFormat) throws -> Data {
        // TODO: Implement ADPCM encoding in Phase 4
        // For now, return empty data
        return Data()
    }

    public func decode(_ data: Data, format: TransmissionFormat) throws -> Data {
        // TODO: Implement ADPCM decoding in Phase 4
        // For now, return empty data
        return Data()
    }
}

/// Codec factory
public class CodecFactory {
    public static func createCodec(for format: TransmissionFormat) -> AudioCodecProtocol {
        switch format.codec {
        case .pcm:
            return PCMCodec()
        case .imaADPCM:
            return IMADPCMCodec()
        case .opus, .aacLC:
            // Not implemented yet, fall back to PCM
            return PCMCodec()
        }
    }
}

/// Codec errors
public enum CodecError: Error {
    case encodingFailed
    case decodingFailed
    case unsupportedFormat
}
