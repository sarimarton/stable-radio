import Foundation

/// Packet type identifiers
public enum PacketType: UInt16 {
    case audioData = 0x01      // Audio payload
    case streamRequest = 0x02  // Receiver requests stream
    case streamStop = 0x03     // Stop streaming
    case heartbeat = 0x04      // Keep-alive ping
    case bufferStatus = 0x05   // Buffer fill level report
    case formatChange = 0x06   // Format negotiation
}

/// UDP packet structure for StableRadio protocol
public struct AudioPacket {
    // MARK: - Header Fields (16 bytes total)

    /// Magic number: 0x53524144 ("SRAD")
    public static let magic: UInt32 = 0x53524144

    /// Protocol version
    public static let protocolVersion: UInt16 = 1

    /// Packet type
    public let type: PacketType

    /// Sequence number (wraps at UInt32.max)
    public let sequence: UInt32

    /// Audio format flags (encoded TransmissionFormat)
    public let formatFlags: UInt16

    /// Reserved bytes for future use
    public let reserved: UInt16

    // MARK: - Payload

    /// Packet payload (audio data or control message)
    public let payload: Data

    // MARK: - Computed Properties

    /// CRC32 checksum of payload
    public var checksum: UInt32 {
        return payload.crc32()
    }

    /// Total packet size in bytes
    public var totalSize: Int {
        return 16 + 4 + payload.count // Header + CRC + Payload
    }

    // MARK: - Initialization

    public init(
        type: PacketType,
        sequence: UInt32,
        formatFlags: UInt16 = 0,
        reserved: UInt16 = 0,
        payload: Data
    ) {
        self.type = type
        self.sequence = sequence
        self.formatFlags = formatFlags
        self.reserved = reserved
        self.payload = payload
    }

    /// Create audio data packet
    public static func audioData(
        sequence: UInt32,
        format: TransmissionFormat,
        audioData: Data
    ) -> AudioPacket {
        return AudioPacket(
            type: .audioData,
            sequence: sequence,
            formatFlags: format.encodedFlags,
            payload: audioData
        )
    }

    /// Create stream request packet
    public static func streamRequest(deviceID: String) -> AudioPacket {
        let payload = deviceID.data(using: .utf8) ?? Data()
        return AudioPacket(
            type: .streamRequest,
            sequence: 0,
            payload: payload
        )
    }

    /// Create stream stop packet
    public static func streamStop() -> AudioPacket {
        return AudioPacket(
            type: .streamStop,
            sequence: 0,
            payload: Data()
        )
    }

    /// Create heartbeat packet
    public static func heartbeat(sequence: UInt32) -> AudioPacket {
        return AudioPacket(
            type: .heartbeat,
            sequence: sequence,
            payload: Data()
        )
    }

    /// Create buffer status packet
    public static func bufferStatus(fillLevel: Float) -> AudioPacket {
        var level = fillLevel
        let payload = Data(bytes: &level, count: MemoryLayout<Float>.size)
        return AudioPacket(
            type: .bufferStatus,
            sequence: 0,
            payload: payload
        )
    }

    // MARK: - Serialization

    /// Serialize packet to Data for transmission
    public func serialize() -> Data {
        var data = Data(capacity: totalSize)

        // Header (16 bytes)
        data.append(contentsOf: withUnsafeBytes(of: AudioPacket.magic.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: AudioPacket.protocolVersion.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: type.rawValue.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: sequence.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: formatFlags.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: reserved.bigEndian) { Data($0) })

        // Payload
        data.append(payload)

        // CRC32 checksum
        let crc = checksum
        data.append(contentsOf: withUnsafeBytes(of: crc.bigEndian) { Data($0) })

        return data
    }

    /// Deserialize packet from received Data
    public static func deserialize(_ data: Data) -> AudioPacket? {
        guard data.count >= 20 else { return nil } // Minimum: 16-byte header + 4-byte CRC

        var offset = 0

        // Validate magic number
        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        guard magic == AudioPacket.magic else { return nil }
        offset += 4

        // Read version
        let version = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        guard version == AudioPacket.protocolVersion else { return nil }
        offset += 2

        // Read type
        let typeValue = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        guard let type = PacketType(rawValue: typeValue) else { return nil }
        offset += 2

        // Read sequence
        let sequence = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4

        // Read format flags
        let formatFlags = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        offset += 2

        // Read reserved
        let reserved = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        offset += 2

        // Extract payload (everything except last 4 bytes which are CRC)
        let payloadEndIndex = data.count - 4
        guard payloadEndIndex >= offset else { return nil }
        let payload = data.subdata(in: offset..<payloadEndIndex)

        // Verify CRC
        let receivedCRC = data.withUnsafeBytes {
            $0.load(fromByteOffset: payloadEndIndex, as: UInt32.self).bigEndian
        }
        let calculatedCRC = payload.crc32()
        guard receivedCRC == calculatedCRC else { return nil } // CRC mismatch

        return AudioPacket(
            type: type,
            sequence: sequence,
            formatFlags: formatFlags,
            reserved: reserved,
            payload: payload
        )
    }
}

// MARK: - CRC32 Extension

extension Data {
    /// Calculate CRC32 checksum
    func crc32() -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF

        for byte in self {
            let index = (crc ^ UInt32(byte)) & 0xFF
            crc = (crc >> 8) ^ Data.crc32Table[Int(index)]
        }

        return ~crc
    }

    /// CRC32 lookup table
    fileprivate static let crc32Table: [UInt32] = {
        (0...255).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc = crc >> 1
                }
            }
            return crc
        }
    }()
}

// MARK: - Sequence Number Utilities

public extension UInt32 {
    /// Calculate difference between sequence numbers, accounting for wrap-around
    func sequenceDistance(to other: UInt32) -> Int64 {
        let diff = Int64(other) - Int64(self)
        let halfMax = Int64(UInt32.max) / 2

        if diff > halfMax {
            return diff - Int64(UInt32.max) - 1
        } else if diff < -halfMax {
            return diff + Int64(UInt32.max) + 1
        } else {
            return diff
        }
    }
}
