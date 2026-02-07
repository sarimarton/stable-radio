# StableRadio

A stable audio streaming system for macOS-to-iOS audio broadcasting, designed to handle highly unstable WiFi connections through configurable large buffers (5-30 seconds).

## Features

- **Large Adaptive Buffers**: User-configurable 5-30+ second buffers for maximum stability
- **Automatic Discovery**: Bonjour-based zero-configuration device discovery
- **Flexible Audio Formats**: Multiple quality presets from Ultra Low to Maximum
- **Codec Support**: PCM, IMA-ADPCM, and optional Opus/AAC compression
- **iOS 12+ Support**: Compatible with older iOS devices
- **Packet Reordering**: Handles out-of-order packet delivery
- **System Audio Capture**: macOS system audio streaming (requires BlackHole virtual audio device)

## Architecture

### Components

1. **StableRadioCore**: Shared Swift package containing network protocol, audio codecs, and buffer management
2. **StableRadio-macOS**: macOS sender application with audio capture and broadcasting
3. **StableRadio-iOS**: iOS receiver application with adaptive buffering and playback

## Requirements

- **macOS**: macOS 11 Big Sur or later
- **iOS**: iOS 12 or later
- **Network**: Both devices must be on the same local network
- **System Audio** (optional): [BlackHole](https://github.com/ExistentialAudio/BlackHole) virtual audio device for capturing system audio on macOS

## Current Implementation Status

✅ **Phase 1-3 Complete**: Core framework, macOS sender, and iOS receiver code implemented
⚠️ **Xcode Projects**: Need to be created to build and run the apps

See [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md) for detailed status.

## Building the Project

### StableRadioCore (Shared Framework)

The core framework builds successfully with Swift Package Manager:

```bash
cd StableRadioCore
swift build
swift test  # Run tests (when available)
```

### macOS and iOS Apps

The macOS and iOS apps require Xcode projects to be created. The code is complete and organized, but needs proper `.xcodeproj` files.

**Option 1: Create Xcode Projects Manually**

1. Open Xcode
2. Create New Project → App
3. Add existing Swift files from `StableRadio-macOS/StableRadio-macOS/` or `StableRadio-iOS/StableRadio-iOS/`
4. Add StableRadioCore as a local Swift Package dependency
5. Configure Info.plist and entitlements
6. Build and run

**Option 2: Use the Package.swift** (partial support)

```bash
# macOS
cd StableRadio-macOS
swift build  # Will build executable but not create full app bundle

# iOS
cd StableRadio-iOS
swift build  # Framework only, needs Xcode for iOS app
```

### Required Permissions

**macOS (Info.plist)**:
- `NSMicrophoneUsageDescription`: "StableRadio needs microphone access to capture audio"
- `NSLocalNetworkUsageDescription`: "StableRadio needs network access to stream audio"

**iOS (Info.plist)**:
- `NSLocalNetworkUsageDescription`: "StableRadio needs network access to receive audio"
- `UIBackgroundModes`: `audio` (for background playback)

## Installation

### Prerequisites

- **macOS**: macOS 11 Big Sur or later, Xcode 13+
- **iOS**: iOS 12 or later
- **Network**: Both devices on same local network (WiFi)
- **System Audio** (optional): [BlackHole](https://github.com/ExistentialAudio/BlackHole) for macOS system audio capture

## Usage

### macOS (Sender)

1. Launch the macOS app
2. Select an audio input device (microphone or BlackHole for system audio)
3. Choose a quality preset or configure custom format
4. Click "Start Broadcasting"
5. iOS receivers will appear in the list automatically

### iOS (Receiver)

1. Launch the iOS app
2. Available senders will appear in the list
3. Tap a sender to connect
4. Adjust buffer size if needed (larger = more stable on poor WiFi)
5. Audio will begin playing once the buffer fills

## Audio Quality Presets

| Preset | Sample Rate | Bit Depth | Channels | Codec | Bandwidth | Use Case |
|--------|-------------|-----------|----------|-------|-----------|----------|
| Ultra Low | 22.05 kHz | 8-bit | Mono | PCM | ~176 kbps | Voice/Podcast |
| Low | 32 kHz | 12-bit | Mono | ADPCM | ~128 kbps | Speech |
| Medium | 44.1 kHz | 16-bit | Mono | PCM | ~706 kbps | Music (mono) |
| High | 44.1 kHz | 16-bit | Stereo | PCM | ~1411 kbps | CD quality |
| Maximum | 48 kHz | 16-bit | Stereo | PCM | ~1536 kbps | Studio quality |

## Technical Details

- **Protocol**: Custom UDP-based streaming with sequence numbers and CRC32 validation
- **Discovery**: Bonjour service (`_stableradio._udp.local`)
- **Buffer Strategy**: Adaptive ring buffer with configurable size (1-60 seconds)
- **Packet Loss**: Automatic gap detection and silence filling

## License

MIT License

## Contributing

Pull requests welcome! Please maintain the existing code style and add tests for new features.
