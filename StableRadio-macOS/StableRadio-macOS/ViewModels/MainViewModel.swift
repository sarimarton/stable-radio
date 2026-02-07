import Foundation
import SwiftUI
import Combine
import StableRadioCore
import AVFoundation

/// Main view model for the macOS sender app
@MainActor
class MainViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isStreaming: Bool = false
    @Published var discoveredReceivers: [DeviceInfo] = []
    @Published var selectedFormat: TransmissionFormat = .high
    @Published var availableAudioDevices: [AudioDeviceInfo] = []
    @Published var selectedAudioDevice: AudioDeviceInfo?
    @Published var bandwidth: Int = 0 // Current bandwidth in kbps
    @Published var connectionStatus: String = "Not streaming"
    @Published var activeConnections: Int = 0

    // MARK: - Private Properties

    private var audioCaptureEngine: AudioCaptureEngine?
    private var streamBroadcaster: StreamBroadcaster?
    private var receiverDiscovery: ReceiverDiscovery?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupAudioDevices()
        setupReceiverDiscovery()
    }

    // MARK: - Public Methods

    func startStreaming() {
        guard let selectedDevice = selectedAudioDevice else {
            connectionStatus = "No audio device selected"
            return
        }

        do {
            // Create audio capture engine
            audioCaptureEngine = AudioCaptureEngine(deviceID: selectedDevice.id)

            // Create stream broadcaster
            streamBroadcaster = StreamBroadcaster(format: selectedFormat)

            // Connect capture to broadcaster
            audioCaptureEngine?.onAudioData = { [weak self] audioData in
                self?.streamBroadcaster?.broadcast(audioData)
            }

            // Update active receivers
            updateActiveReceivers()

            // Start capture
            try audioCaptureEngine?.start()

            isStreaming = true
            connectionStatus = "Streaming"
            bandwidth = selectedFormat.estimatedBandwidthKbps
            print("[MainViewModel] Started streaming with format: \(selectedFormat)")

        } catch {
            connectionStatus = "Error: \(error.localizedDescription)"
            print("[MainViewModel] Failed to start streaming: \(error)")
        }
    }

    func stopStreaming() {
        audioCaptureEngine?.stop()
        streamBroadcaster?.stop()

        isStreaming = false
        connectionStatus = "Not streaming"
        activeConnections = 0
        bandwidth = 0
        print("[MainViewModel] Stopped streaming")
    }

    func refreshAudioDevices() {
        setupAudioDevices()
    }

    func formatChanged(_ newFormat: TransmissionFormat) {
        selectedFormat = newFormat
        bandwidth = newFormat.estimatedBandwidthKbps

        if isStreaming {
            // Update broadcaster format
            streamBroadcaster?.updateFormat(newFormat)
        }
    }

    // MARK: - Private Methods

    private func setupAudioDevices() {
        let deviceManager = AudioDeviceManager()
        availableAudioDevices = deviceManager.listInputDevices()

        // Select first device by default
        if selectedAudioDevice == nil {
            selectedAudioDevice = availableAudioDevices.first
        }

        print("[MainViewModel] Found \(availableAudioDevices.count) audio devices")
    }

    private func setupReceiverDiscovery() {
        receiverDiscovery = ReceiverDiscovery()

        receiverDiscovery?.onReceiverFound = { [weak self] receiver in
            DispatchQueue.main.async {
                self?.discoveredReceivers.append(receiver)
                self?.updateActiveReceivers()
                print("[MainViewModel] Discovered receiver: \(receiver.name)")
            }
        }

        receiverDiscovery?.onReceiverLost = { [weak self] receiverID in
            DispatchQueue.main.async {
                self?.discoveredReceivers.removeAll { $0.id == receiverID }
                self?.updateActiveReceivers()
                print("[MainViewModel] Lost receiver: \(receiverID)")
            }
        }

        receiverDiscovery?.start()
    }

    private func updateActiveReceivers() {
        guard let broadcaster = streamBroadcaster else { return }

        // Update broadcaster with current list of receivers
        let endpoints = discoveredReceivers.map { (host: $0.ipAddress, port: $0.port) }
        broadcaster.updateReceivers(endpoints)

        activeConnections = discoveredReceivers.count
    }
}
