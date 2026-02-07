import Foundation
import StableRadioCore
import Network

/// Discovers StableRadio receiver devices on the network
class ReceiverDiscovery {
    private var bonjourBrowser: BonjourBrowser?

    var onReceiverFound: ((DeviceInfo) -> Void)?
    var onReceiverLost: ((String) -> Void)?

    init() {
        bonjourBrowser = BonjourBrowser()
        setupBrowser()
    }

    func start() {
        bonjourBrowser?.start()
        print("[ReceiverDiscovery] Started browsing for receivers")
    }

    func stop() {
        bonjourBrowser?.stop()
        print("[ReceiverDiscovery] Stopped browsing")
    }

    private func setupBrowser() {
        bonjourBrowser?.onDeviceFound = { [weak self] device in
            // Only interested in receiver devices
            if device.deviceType == .receiver {
                self?.onReceiverFound?(device)
            }
        }

        bonjourBrowser?.onDeviceLost = { [weak self] deviceID in
            self?.onReceiverLost?(deviceID)
        }
    }
}
