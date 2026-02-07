import SwiftUI
import StableRadioCore

struct MainView: View {
    @EnvironmentObject var viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection

            Divider()

            // Audio Device Selection
            audioDeviceSection

            Divider()

            // Transmission Format Settings
            formatSettingsSection

            Divider()

            // Discovered Receivers
            receiversSection

            Spacer()

            // Status and Controls
            statusSection

            // Start/Stop Button
            controlButton
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("StableRadio Sender")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Broadcast audio to iOS receivers")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var audioDeviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audio Input Device", systemImage: "mic.fill")
                .font(.headline)

            Picker("Device", selection: $viewModel.selectedAudioDevice) {
                ForEach(viewModel.availableAudioDevices) { device in
                    Text(device.name).tag(device as AudioDeviceInfo?)
                }
            }
            .pickerStyle(.menu)
            .disabled(viewModel.isStreaming)

            Button("Refresh Devices") {
                viewModel.refreshAudioDevices()
            }
            .disabled(viewModel.isStreaming)

            Text("Note: To capture system audio, install BlackHole and create a Multi-Output Device")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }

    private var formatSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transmission Quality", systemImage: "waveform")
                .font(.headline)

            Picker("Preset", selection: $viewModel.selectedFormat) {
                Text("Ultra Low (22kHz Mono)").tag(TransmissionFormat.ultraLow)
                Text("Medium (44.1kHz Mono)").tag(TransmissionFormat.medium)
                Text("High (44.1kHz Stereo)").tag(TransmissionFormat.high)
                Text("Maximum (48kHz Stereo)").tag(TransmissionFormat.maximum)
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedFormat) { newFormat in
                viewModel.formatChanged(newFormat)
            }

            HStack {
                Text("Bandwidth:")
                    .font(.subheadline)
                Spacer()
                Text("\(viewModel.bandwidth) kbps")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }

            Text(viewModel.selectedFormat.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var receiversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Discovered Receivers", systemImage: "iphone")
                .font(.headline)

            if viewModel.discoveredReceivers.isEmpty {
                Text("No receivers found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(viewModel.discoveredReceivers) { receiver in
                    ReceiverRowView(receiver: receiver)
                }
                .frame(height: 120)
            }
        }
    }

    private var statusSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(viewModel.connectionStatus)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Active Connections:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(viewModel.activeConnections)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var controlButton: some View {
        Button(action: {
            if viewModel.isStreaming {
                viewModel.stopStreaming()
            } else {
                viewModel.startStreaming()
            }
        }) {
            Text(viewModel.isStreaming ? "Stop Broadcasting" : "Start Broadcasting")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isStreaming ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.selectedAudioDevice == nil)
    }
}

struct ReceiverRowView: View {
    let receiver: DeviceInfo

    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(receiver.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text("\(receiver.ipAddress):\(receiver.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let format = receiver.currentFormat {
                Text("\(format.estimatedBandwidthKbps) kbps")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MainView()
        .environmentObject(MainViewModel())
}
