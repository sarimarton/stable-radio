import Foundation
import CoreAudio
import AVFoundation

/// Manager for enumerating and managing audio devices on macOS
class AudioDeviceManager {
    /// List all input audio devices
    func listInputDevices() -> [AudioDeviceInfo] {
        var devices: [AudioDeviceInfo] = []

        // Get all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        guard status == kAudioHardwareNoError else {
            print("[AudioDeviceManager] Failed to get device list size")
            return devices
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )

        guard status == kAudioHardwareNoError else {
            print("[AudioDeviceManager] Failed to get device list")
            return devices
        }

        // Query each device
        for deviceID in audioDevices {
            if let deviceInfo = getDeviceInfo(deviceID: deviceID) {
                devices.append(deviceInfo)
            }
        }

        return devices.filter { $0.isInput }
    }

    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioDeviceInfo? {
        // Get device name
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        var status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )

        guard status == kAudioHardwareNoError else { return nil }

        // Check if device has input streams
        propertyAddress.mSelector = kAudioDevicePropertyStreams
        propertyAddress.mScope = kAudioDevicePropertyScopeInput
        dataSize = 0

        status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        let hasInput = status == kAudioHardwareNoError && dataSize > 0

        // Check if device has output streams
        propertyAddress.mScope = kAudioDevicePropertyScopeOutput
        dataSize = 0

        status = AudioObjectGetPropertyDataSize(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        let hasOutput = status == kAudioHardwareNoError && dataSize > 0

        return AudioDeviceInfo(
            id: String(deviceID),
            name: deviceName as String,
            isInput: hasInput,
            isOutput: hasOutput
        )
    }

    /// Get default input device
    func getDefaultInputDevice() -> AudioDeviceInfo? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )

        guard status == kAudioHardwareNoError else { return nil }

        return getDeviceInfo(deviceID: deviceID)
    }
}
