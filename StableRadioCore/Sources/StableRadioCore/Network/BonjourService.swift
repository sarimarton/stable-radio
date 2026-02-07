import Foundation

/// Bonjour service type for StableRadio
public let StableRadioServiceType = "_stableradio._udp."

/// Bonjour service publisher for advertising devices
public class BonjourPublisher: NSObject {
    private var netService: NetService?
    private let deviceInfo: DeviceInfo

    public var isPublishing: Bool {
        return netService != nil
    }

    public init(deviceInfo: DeviceInfo) {
        self.deviceInfo = deviceInfo
        super.init()
    }

    deinit {
        stop()
    }

    /// Start publishing the service
    public func start() {
        stop() // Stop any existing service

        netService = NetService(
            domain: "local.",
            type: StableRadioServiceType,
            name: deviceInfo.name,
            port: Int32(deviceInfo.port)
        )

        netService?.delegate = self

        // Set TXT record with device info
        var txtRecord: [String: Data] = [:]
        txtRecord["id"] = deviceInfo.id.data(using: .utf8)
        txtRecord["type"] = deviceInfo.deviceType.rawValue.data(using: .utf8)
        txtRecord["ip"] = deviceInfo.ipAddress.data(using: .utf8)

        if let currentFormat = deviceInfo.currentFormat {
            txtRecord["format"] = "\(currentFormat.encodedFlags)".data(using: .utf8)
            txtRecord["bandwidth"] = "\(currentFormat.estimatedBandwidthKbps)".data(using: .utf8)
        }

        let txtData = NetService.data(fromTXTRecord: txtRecord)
        netService?.setTXTRecord(txtData)

        netService?.publish()
        print("[BonjourPublisher] Publishing service: \(deviceInfo.name)")
    }

    /// Stop publishing the service
    public func stop() {
        netService?.stop()
        netService = nil
    }

    /// Update TXT record with new format
    public func updateFormat(_ format: TransmissionFormat) {
        guard let netService = netService else { return }

        var txtRecord: [String: Data] = [:]
        txtRecord["id"] = deviceInfo.id.data(using: .utf8)
        txtRecord["type"] = deviceInfo.deviceType.rawValue.data(using: .utf8)
        txtRecord["ip"] = deviceInfo.ipAddress.data(using: .utf8)
        txtRecord["format"] = "\(format.encodedFlags)".data(using: .utf8)
        txtRecord["bandwidth"] = "\(format.estimatedBandwidthKbps)".data(using: .utf8)

        let txtData = NetService.data(fromTXTRecord: txtRecord)
        netService.setTXTRecord(txtData)
    }
}

extension BonjourPublisher: NetServiceDelegate {
    public func netServiceDidPublish(_ sender: NetService) {
        print("[BonjourPublisher] Service published successfully")
    }

    public func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("[BonjourPublisher] Failed to publish: \(errorDict)")
    }
}

/// Bonjour service browser for discovering devices
public class BonjourBrowser: NSObject {
    private var netServiceBrowser: NetServiceBrowser?
    private var foundServices: [NetService] = []
    private let servicesLock = NSLock()

    public var onDeviceFound: ((DeviceInfo) -> Void)?
    public var onDeviceLost: ((String) -> Void)? // Device ID

    public var isSearching: Bool {
        return netServiceBrowser != nil
    }

    override public init() {
        super.init()
    }

    deinit {
        stop()
    }

    /// Start browsing for services
    public func start() {
        stop() // Stop any existing browser

        netServiceBrowser = NetServiceBrowser()
        netServiceBrowser?.delegate = self
        netServiceBrowser?.searchForServices(ofType: StableRadioServiceType, inDomain: "local.")
        print("[BonjourBrowser] Started browsing for StableRadio devices")
    }

    /// Stop browsing
    public func stop() {
        netServiceBrowser?.stop()
        netServiceBrowser = nil

        servicesLock.lock()
        foundServices.removeAll()
        servicesLock.unlock()
    }
}

extension BonjourBrowser: NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("[BonjourBrowser] Found service: \(service.name)")

        servicesLock.lock()
        foundServices.append(service)
        servicesLock.unlock()

        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        print("[BonjourBrowser] Lost service: \(service.name)")

        servicesLock.lock()
        foundServices.removeAll { $0 === service }
        servicesLock.unlock()

        // Extract device ID from TXT record
        if let txtData = service.txtRecordData() {
            let txtRecord = NetService.dictionary(fromTXTRecord: txtData)
            if let idData = txtRecord["id"],
               let deviceID = String(data: idData, encoding: .utf8) {
                onDeviceLost?(deviceID)
            }
        }
    }

    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        print("[BonjourBrowser] Browser stopped")
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        print("[BonjourBrowser] Browser error: \(errorDict)")
    }
}

extension BonjourBrowser: NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        print("[BonjourBrowser] Resolved service: \(sender.name)")

        // Extract TXT record data
        guard let txtData = sender.txtRecordData() else {
            print("[BonjourBrowser] No TXT record data")
            return
        }

        let txtRecord = NetService.dictionary(fromTXTRecord: txtData)

        // Parse device info
        guard let idData = txtRecord["id"],
              let deviceID = String(data: idData, encoding: .utf8),
              let typeData = txtRecord["type"],
              let typeString = String(data: typeData, encoding: .utf8),
              let deviceType = DeviceInfo.DeviceType(rawValue: typeString) else {
            print("[BonjourBrowser] Invalid TXT record")
            return
        }

        // Get IP address from resolved addresses
        var ipAddress = "0.0.0.0"
        if let addresses = sender.addresses, !addresses.isEmpty {
            // Try to get IPv4 address
            for addressData in addresses {
                let sockaddrPtr = addressData.withUnsafeBytes { bytes -> UnsafePointer<sockaddr>? in
                    return bytes.baseAddress?.assumingMemoryBound(to: sockaddr.self)
                }

                guard let addr = sockaddrPtr else { continue }

                if addr.pointee.sa_family == sa_family_t(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(addr, socklen_t(addressData.count), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    ipAddress = String(cString: hostname)
                    break
                }
            }
        }

        // Parse format if available
        var currentFormat: TransmissionFormat?
        if let formatData = txtRecord["format"],
           let formatString = String(data: formatData, encoding: .utf8),
           let formatFlags = UInt16(formatString) {
            currentFormat = TransmissionFormat.decode(flags: formatFlags)
        }

        let deviceInfo = DeviceInfo(
            id: deviceID,
            name: sender.name,
            deviceType: deviceType,
            ipAddress: ipAddress,
            port: UInt16(sender.port),
            supportedFormats: [],
            currentFormat: currentFormat
        )

        onDeviceFound?(deviceInfo)
    }

    public func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("[BonjourBrowser] Failed to resolve: \(sender.name), error: \(errorDict)")
    }
}
