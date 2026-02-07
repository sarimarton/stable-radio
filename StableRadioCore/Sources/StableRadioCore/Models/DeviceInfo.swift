import Foundation

/// Information about a StableRadio device (sender or receiver)
public struct DeviceInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let deviceType: DeviceType
    public let ipAddress: String
    public let port: UInt16
    public var supportedFormats: [TransmissionFormat]
    public var currentFormat: TransmissionFormat?

    public enum DeviceType: String, Codable {
        case sender
        case receiver
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        deviceType: DeviceType,
        ipAddress: String,
        port: UInt16,
        supportedFormats: [TransmissionFormat] = [],
        currentFormat: TransmissionFormat? = nil
    ) {
        self.id = id
        self.name = name
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.port = port
        self.supportedFormats = supportedFormats
        self.currentFormat = currentFormat
    }
}

extension DeviceInfo: Equatable {
    public static func == (lhs: DeviceInfo, rhs: DeviceInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Connection status for a device
public enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case streaming
    case error(String)

    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .streaming: return "Streaming"
        case .error(let message): return "Error: \(message)"
        }
    }
}

/// Streaming statistics
public struct StreamingStats {
    public var packetsReceived: UInt64 = 0
    public var packetsLost: UInt64 = 0
    public var bytesReceived: UInt64 = 0
    public var currentLatencyMs: Double = 0
    public var averageLatencyMs: Double = 0
    public var bufferFillLevel: Float = 0 // 0.0 to 1.0

    public var packetLossPercentage: Double {
        let total = packetsReceived + packetsLost
        guard total > 0 else { return 0 }
        return Double(packetsLost) / Double(total) * 100.0
    }

    public init() {}
}
