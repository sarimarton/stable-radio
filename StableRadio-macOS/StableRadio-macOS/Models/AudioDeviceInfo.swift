import Foundation

/// Audio device information for macOS
struct AudioDeviceInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let isInput: Bool
    let isOutput: Bool
}
