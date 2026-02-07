import Foundation
import StableRadioCore

/// Discovers StableRadio sender devices on the network
class SenderDiscovery {
    private var bonjourBrowser: BonjourBrowser?

    var onSenderFound: ((DeviceInfo) -> Void)?
    var onSenderLost: ((String) -> Void)?

    init() {
        bonjourBrowser = BonjourBrowser()
        setupBrowser()
    }

    func start() {
        bonjourBrowser?.start()
        print("[SenderDiscovery] Started browsing for senders")
    }

    func stop() {
        bonjourBrowser?.stop()
        print("[SenderDiscovery] Stopped browsing")
    }

    private func setupBrowser() {
        bonjourBrowser?.onDeviceFound = { [weak self] device in
            // Only interested in sender devices
            if device.deviceType == .sender {
                self?.onSenderFound?(device)
            }
        }

        bonjourBrowser?.onDeviceLost = { [weak self] deviceID in
            self?.onSenderLost?(deviceID)
        }
    }
}
