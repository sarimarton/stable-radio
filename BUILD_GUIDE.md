# StableRadio Build Guide

## Overview

StableRadio consists of three components:
1. **StableRadioCore** - Shared Swift package (builds with SPM)
2. **StableRadio-macOS** - macOS sender app (needs Xcode project)
3. **StableRadio-iOS** - iOS receiver app (needs Xcode project)

## Quick Start: Building StableRadioCore

The shared framework builds successfully with Swift Package Manager:

```bash
cd StableRadioCore
swift build
```

Expected output:
```
Building for debugging...
Build complete! (1.2s)
```

## Creating Xcode Projects

The macOS and iOS apps have all their source code implemented, but need Xcode project files to build and run.

### Option 1: Manual Xcode Project Creation (Recommended)

#### macOS App

1. **Create New Project**:
   - Open Xcode
   - File → New → Project
   - macOS → App
   - Product Name: `StableRadio-macOS`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum deployment: macOS 11.0

2. **Add Source Files**:
   - Delete the default `ContentView.swift` and app file
   - Drag these folders into the project:
     - `StableRadio-macOS/StableRadio-macOS/AudioCapture`
     - `StableRadio-macOS/StableRadio-macOS/Network`
     - `StableRadio-macOS/StableRadio-macOS/Discovery`
     - `StableRadio-macOS/StableRadio-macOS/ViewModels`
     - `StableRadio-macOS/StableRadio-macOS/Views`
     - `StableRadio-macOS/StableRadio-macOS/Models`
   - Add `StableRadioApp.swift` as the app entry point

3. **Add StableRadioCore Dependency**:
   - File → Add Package Dependencies
   - Click "Add Local..."
   - Select `StableRadioCore` folder
   - Add to target

4. **Configure Info.plist**:
   - Replace with provided `StableRadio-macOS/Info.plist`
   - Or manually add:
     - `NSMicrophoneUsageDescription`
     - `NSLocalNetworkUsageDescription`
     - `NSBonjourServices` = `_stableradio._udp`

5. **Add Entitlements** (if needed):
   - Signing & Capabilities → + Capability
   - Add "Audio Input" if required

6. **Build**:
   - Select "My Mac" as destination
   - Product → Build (⌘B)
   - Product → Run (⌘R)

#### iOS App

1. **Create New Project**:
   - Open Xcode
   - File → New → Project
   - iOS → App
   - Product Name: `StableRadio-iOS`
   - Interface: Storyboard (for iOS 12 support)
   - Language: Swift
   - Minimum deployment: iOS 12.0

2. **Add Source Files**:
   - Delete default ViewController.swift
   - Drag these folders into the project:
     - `StableRadio-iOS/StableRadio-iOS/Audio`
     - `StableRadio-iOS/StableRadio-iOS/Network`
     - `StableRadio-iOS/StableRadio-iOS/Discovery`
     - `StableRadio-iOS/StableRadio-iOS/ViewControllers`
     - `StableRadio-iOS/StableRadio-iOS/Views`
   - Replace `AppDelegate.swift` with the provided one
   - Delete SceneDelegate.swift if present (for iOS 12 support)

3. **Add StableRadioCore Dependency**:
   - File → Add Package Dependencies
   - Click "Add Local..."
   - Select `StableRadioCore` folder
   - Add to target

4. **Configure Info.plist**:
   - Replace with provided `StableRadio-iOS/Info.plist`
   - Or manually add:
     - `NSLocalNetworkUsageDescription`
     - `NSBonjourServices` = `_stableradio._udp`
     - `UIBackgroundModes` = `audio`

5. **Remove Storyboard** (we use code-based UI):
   - Delete Main.storyboard
   - In Info.plist, remove:
     - `UIMainStoryboardFile`
     - `UISceneConfigurationName` (if present)

6. **Build**:
   - Select iPhone simulator or device
   - Product → Build (⌘B)
   - Product → Run (⌘R)

### Option 2: Using xcodegen (Advanced)

If you prefer automated project generation, you can create `project.yml` files:

**macOS (StableRadio-macOS/project.yml)**:
```yaml
name: StableRadio-macOS
options:
  bundleIdPrefix: com.stableradio
targets:
  StableRadio-macOS:
    type: application
    platform: macOS
    deploymentTarget: "11.0"
    sources:
      - StableRadio-macOS
    dependencies:
      - package: StableRadioCore
    info:
      path: Info.plist
packages:
  StableRadioCore:
    path: ../StableRadioCore
```

Then run:
```bash
cd StableRadio-macOS
xcodegen generate
xed .
```

## Troubleshooting

### Build Errors

**"No such module 'StableRadioCore'"**
- Solution: Make sure StableRadioCore is added as a package dependency
- Verify the package builds: `cd StableRadioCore && swift build`

**"Cannot find type 'MainViewModel' in scope"**
- Solution: Ensure all source files are added to the target
- Check target membership in File Inspector

**"Sandbox: rsync deny file-write"**
- This is a warning about sudo prompts, can be ignored
- Does not affect build

### Runtime Errors

**"This app has crashed because it attempted to access privacy-sensitive data..."**
- Solution: Add required usage descriptions to Info.plist
- macOS: `NSMicrophoneUsageDescription`, `NSLocalNetworkUsageDescription`
- iOS: `NSLocalNetworkUsageDescription`

**Bonjour service not found**
- Solution: Add `NSBonjourServices` array to Info.plist
- Value: `_stableradio._udp`
- Ensure both devices are on same WiFi network

**No audio devices found (macOS)**
- Solution: Grant microphone permission in System Preferences
- For system audio: Install [BlackHole](https://github.com/ExistentialAudio/BlackHole)

## Testing the Apps

### Basic Functionality Test

1. **Build both apps**:
   - macOS app on your Mac
   - iOS app on iPhone/iPad or Simulator

2. **Start macOS sender**:
   - Launch StableRadio-macOS
   - Select an audio input device
   - Click "Start Broadcasting"

3. **Connect iOS receiver**:
   - Launch StableRadio-iOS
   - Wait for sender to appear in list
   - Tap sender name to connect
   - Audio should start playing within 3-10 seconds

### System Audio Test (macOS)

1. **Install BlackHole**:
   ```bash
   brew install blackhole-2ch
   ```

2. **Create Multi-Output Device**:
   - Open Audio MIDI Setup
   - Click "+" → Create Multi-Output Device
   - Check your speakers + BlackHole 2ch
   - Set as system output

3. **Configure StableRadio**:
   - Select "BlackHole 2ch" as input device
   - Start broadcasting
   - Play music/video on Mac
   - Should hear on iOS device

### Network Test

1. **Check discovery**:
   - Both apps should see each other automatically
   - Check Console for "[BonjourBrowser] Found service" messages

2. **Monitor bandwidth**:
   - macOS: Check "Bandwidth" display
   - iOS: Check format display
   - Should match selected quality preset

3. **Test buffer**:
   - iOS: Adjust buffer slider (1-60s)
   - Larger buffer = more latency but more stable
   - Monitor buffer fill progress bar

## Performance Optimization

### macOS App
- Use lowest quality preset that meets your needs
- Close unused audio applications
- Monitor Activity Monitor for CPU usage

### iOS App
- Use larger buffer (10-30s) on unstable WiFi
- Keep app in foreground for best performance
- Background audio works but may have interruptions

## Next Steps

After successfully building:
1. Test on real devices (not just simulator)
2. Test on different WiFi networks
3. Measure actual latency with stopwatch
4. Report issues on GitHub

## Known Limitations

- iOS Simulator may have audio issues (test on real device)
- Bluetooth headphones add extra latency
- VPN can interfere with Bonjour discovery
- Maximum ~30 second buffer may not be enough for very poor WiFi

## Support

For build issues:
1. Check IMPLEMENTATION_STATUS.md for current status
2. Review error messages carefully
3. Try cleaning build folder (⇧⌘K)
4. Create issue on GitHub with full error log
