import Foundation
import StableRadioCore

/// View model for main view controller
class MainViewViewModel {
    // MARK: - Properties

    private var senderDiscovery: SenderDiscovery?
    private var streamReceiver: StreamReceiver?
    private var audioPlayback: AudioPlaybackEngine?
    private var adaptiveBuffer: AdaptiveBuffer?

    private var bufferSize: TimeInterval = 10.0
    private var connectedSender: DeviceInfo?
    private var currentFormat: TransmissionFormat?

    var discoveredSenders: [DeviceInfo] = []
    var isConnected: Bool { return connectedSender != nil }
    var currentStats: StreamingStats?

    // Callbacks
    var onSendersChanged: (() -> Void)?
    var onStatusChanged: ((String) -> Void)?
    var onBufferFillChanged: ((Float) -> Void)?
    var onFormatChanged: ((TransmissionFormat) -> Void)?

    // MARK: - Discovery

    func startDiscovery() {
        senderDiscovery = SenderDiscovery()

        senderDiscovery?.onSenderFound = { [weak self] sender in
            self?.discoveredSenders.append(sender)
            self?.onSendersChanged?()
            print("[MainViewViewModel] Found sender: \(sender.name)")
        }

        senderDiscovery?.onSenderLost = { [weak self] senderID in
            self?.discoveredSenders.removeAll { $0.id == senderID }
            self?.onSendersChanged?()
            print("[MainViewViewModel] Lost sender: \(senderID)")
        }

        senderDiscovery?.start()
    }

    func stopDiscovery() {
        senderDiscovery?.stop()
        senderDiscovery = nil
    }

    // MARK: - Connection

    func connectToSender(_ sender: DeviceInfo) {
        guard !isConnected else { return }

        do {
            // Create stream receiver
            streamReceiver = StreamReceiver()

            // Setup receiver callbacks
            streamReceiver?.onPacketReceived = { [weak self] packet in
                // Update stats
                self?.updateStats()

                // Update buffer fill level
                if let fillLevel = self?.adaptiveBuffer?.fillLevel {
                    self?.onBufferFillChanged?(fillLevel)
                }

                // Check if we should start playback
                if let buffer = self?.adaptiveBuffer,
                   buffer.shouldStartPlayback,
                   self?.audioPlayback?.onNeedsMoreData == nil {
                    self?.startPlayback()
                }
            }

            streamReceiver?.onFormatChanged = { [weak self] format in
                self?.currentFormat = format
                self?.onFormatChanged?(format)
                print("[MainViewViewModel] Format changed: \(format)")
            }

            streamReceiver?.onStreamStopped = { [weak self] in
                self?.stopReceiving()
                self?.onStatusChanged?("Stream stopped by sender")
            }

            // Start receiving
            try streamReceiver?.start()

            // Request stream from sender
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            streamReceiver?.requestStream(to: sender.ipAddress, port: sender.port, deviceID: deviceID)

            connectedSender = sender
            onStatusChanged?("Connected to \(sender.name)")
            print("[MainViewViewModel] Connected to sender: \(sender.name)")

        } catch {
            onStatusChanged?("Error: \(error.localizedDescription)")
            print("[MainViewViewModel] Failed to connect: \(error)")
        }
    }

    func stopReceiving() {
        audioPlayback?.stop()
        streamReceiver?.stop()

        audioPlayback = nil
        streamReceiver = nil
        adaptiveBuffer = nil
        connectedSender = nil
        currentFormat = nil

        onStatusChanged?("Disconnected")
        onBufferFillChanged?(0)
        print("[MainViewViewModel] Disconnected")
    }

    // MARK: - Buffer Management

    func setBufferSize(_ seconds: TimeInterval) {
        bufferSize = seconds

        // If connected, recreate buffer
        if isConnected, let format = currentFormat {
            let audioConfig = AudioFormatConfig(from: format)
            adaptiveBuffer = streamReceiver?.createBuffer(maxBufferSeconds: bufferSize, format: audioConfig)
            print("[MainViewViewModel] Buffer size set to \(seconds)s")
        }
    }

    // MARK: - Playback

    private func startPlayback() {
        guard let format = currentFormat,
              let buffer = adaptiveBuffer else { return }

        do {
            // Create playback engine
            let audioConfig = AudioFormatConfig(from: format)
            audioPlayback = AudioPlaybackEngine()

            // Setup callback to feed data
            audioPlayback?.onNeedsMoreData = { [weak self] in
                self?.feedAudioData()
            }

            // Start playback
            try audioPlayback?.start(format: audioConfig)

            onStatusChanged?("Playing")
            print("[MainViewViewModel] Started playback")

            // Initial feed
            feedAudioData()

        } catch {
            onStatusChanged?("Playback error: \(error.localizedDescription)")
            print("[MainViewViewModel] Playback error: \(error)")
        }
    }

    private func feedAudioData() {
        guard let buffer = adaptiveBuffer,
              let playback = audioPlayback else { return }

        // Feed multiple buffers
        for _ in 0..<3 {
            if let audioData = buffer.readAudioData(frameCount: 4096) {
                playback.scheduleAudioData(audioData)
            } else {
                break
            }
        }

        // Check if buffer is too low
        if buffer.shouldPausePlayback {
            audioPlayback?.stop()
            onStatusChanged?("Buffering...")
        }
    }

    private func updateStats() {
        guard let buffer = adaptiveBuffer else { return }

        var stats = StreamingStats()
        stats.bufferFillLevel = buffer.fillLevel

        // Estimate latency based on buffer fill
        let fillSeconds = Double(buffer.fillLevel) * bufferSize
        stats.currentLatencyMs = fillSeconds * 1000.0

        currentStats = stats
    }
}
