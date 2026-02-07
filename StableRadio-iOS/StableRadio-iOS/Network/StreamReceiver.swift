import Foundation
import StableRadioCore

/// Receives audio stream from sender via UDP
class StreamReceiver {
    private let udpListener: UDPListener
    private let port: UInt16 = 5555 // Default listening port
    private var adaptiveBuffer: AdaptiveBuffer?
    private var currentFormat: TransmissionFormat?

    var onPacketReceived: ((AudioPacket) -> Void)?
    var onFormatChanged: ((TransmissionFormat) -> Void)?
    var onStreamStopped: (() -> Void)?

    init() {
        self.udpListener = UDPListener()
        setupListener()
    }

    deinit {
        stop()
    }

    func start() throws {
        try udpListener.start(port: port)
        print("[StreamReceiver] Started listening on port \(port)")
    }

    func stop() {
        udpListener.stop()
        adaptiveBuffer = nil
        currentFormat = nil
        print("[StreamReceiver] Stopped receiving")
    }

    func createBuffer(maxBufferSeconds: TimeInterval, format: AudioFormatConfig) -> AdaptiveBuffer {
        let buffer = AdaptiveBuffer(maxBufferSeconds: maxBufferSeconds, format: format)
        adaptiveBuffer = buffer
        return buffer
    }

    private func setupListener() {
        udpListener.receiveHandler = { [weak self] data, sourceIP in
            self?.handleReceivedData(data, from: sourceIP)
        }
    }

    private func handleReceivedData(_ data: Data, from sourceIP: String) {
        // Deserialize packet
        guard let packet = AudioPacket.deserialize(data) else {
            print("[StreamReceiver] Failed to deserialize packet from \(sourceIP)")
            return
        }

        // Handle different packet types
        switch packet.type {
        case .audioData:
            // Extract format from packet if changed
            if let format = TransmissionFormat.decode(flags: packet.formatFlags) {
                if currentFormat != format {
                    currentFormat = format
                    onFormatChanged?(format)
                }
            }

            // Pass to buffer
            adaptiveBuffer?.insertPacket(packet)

            // Notify handler
            onPacketReceived?(packet)

        case .streamStop:
            onStreamStopped?()
            print("[StreamReceiver] Stream stopped by sender")

        case .heartbeat:
            // Heartbeat received, connection alive
            break

        case .formatChange:
            // Format change notification
            if let format = TransmissionFormat.decode(flags: packet.formatFlags) {
                currentFormat = format
                onFormatChanged?(format)
            }

        default:
            break
        }
    }

    /// Send stream request to sender
    func requestStream(to host: String, port: UInt16, deviceID: String) {
        let packet = AudioPacket.streamRequest(deviceID: deviceID)
        let data = packet.serialize()

        let socket = UDPSocket()
        socket.send(data, to: host, port: port) { error in
            if let error = error {
                print("[StreamReceiver] Failed to send stream request: \(error)")
            } else {
                print("[StreamReceiver] Sent stream request to \(host):\(port)")
            }
        }
    }
}
