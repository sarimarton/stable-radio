import Foundation
import StableRadioCore

/// Broadcasts audio data to multiple receivers via UDP
class StreamBroadcaster {
    private let udpSocket: UDPSocket
    private var currentFormat: TransmissionFormat
    private var receivers: [(host: String, port: UInt16)] = []
    private var sequenceNumber: UInt32 = 0
    private let codec: AudioCodecProtocol
    private let queue = DispatchQueue(label: "com.stableradio.broadcaster", qos: .userInitiated)

    init(format: TransmissionFormat) {
        self.currentFormat = format
        self.udpSocket = UDPSocket()
        self.codec = CodecFactory.createCodec(for: format)
        print("[StreamBroadcaster] Initialized with format: \(format)")
    }

    /// Update the list of receivers
    func updateReceivers(_ endpoints: [(host: String, port: UInt16)]) {
        queue.async { [weak self] in
            self?.receivers = endpoints
            print("[StreamBroadcaster] Updated receivers: \(endpoints.count) devices")
        }
    }

    /// Broadcast audio data to all receivers
    func broadcast(_ audioData: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.receivers.isEmpty else { return }

            do {
                // Encode audio data with codec
                let encodedData = try self.codec.encode(audioData, format: self.currentFormat)

                // Create packet
                let packet = AudioPacket.audioData(
                    sequence: self.sequenceNumber,
                    format: self.currentFormat,
                    audioData: encodedData
                )

                // Serialize packet
                let packetData = packet.serialize()

                // Send to all receivers
                self.udpSocket.broadcast(packetData, to: self.receivers) { successCount in
                    if successCount < self.receivers.count {
                        print("[StreamBroadcaster] Warning: Only \(successCount)/\(self.receivers.count) packets sent")
                    }
                }

                // Increment sequence number
                self.sequenceNumber = self.sequenceNumber &+ 1

            } catch {
                print("[StreamBroadcaster] Error encoding audio: \(error)")
            }
        }
    }

    /// Update transmission format (mid-stream)
    func updateFormat(_ newFormat: TransmissionFormat) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentFormat = newFormat
            print("[StreamBroadcaster] Updated format to: \(newFormat)")

            // Send format change packet to receivers
            // TODO: Implement format change notification
        }
    }

    /// Stop broadcasting
    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }

            // Send stop packet to all receivers
            let stopPacket = AudioPacket.streamStop()
            let packetData = stopPacket.serialize()

            self.udpSocket.broadcast(packetData, to: self.receivers) { _ in
                print("[StreamBroadcaster] Sent stop packets")
            }

            self.receivers.removeAll()
            self.sequenceNumber = 0
        }
    }
}
