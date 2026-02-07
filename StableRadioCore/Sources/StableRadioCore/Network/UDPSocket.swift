import Foundation
import Network

/// UDP socket wrapper for sending and receiving StableRadio packets
public class UDPSocket {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.stableradio.udp", qos: .userInitiated)
    private var receiveHandler: ((Data, NWEndpoint) -> Void)?

    public var isConnected: Bool {
        return connection?.state == .ready
    }

    // MARK: - Initialization

    public init() {}

    deinit {
        close()
    }

    // MARK: - Listen Mode (Receiver)

    /// Start listening on a specific port
    public func listen(on port: UInt16, handler: @escaping (Data, NWEndpoint) -> Void) throws {
        receiveHandler = handler

        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = false

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[UDPSocket] Listening on port \(port)")
            case .failed(let error):
                print("[UDPSocket] Listener failed: \(error)")
            case .cancelled:
                print("[UDPSocket] Listener cancelled")
            default:
                break
            }
        }

        listener.start(queue: queue)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveData(from: connection)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                if let endpoint = context?.protocolMetadata.first as? NWProtocolUDP.Metadata {
                    // Extract remote endpoint if available
                    // For now, we'll use a placeholder
                    let remoteEndpoint = NWEndpoint.hostPort(host: "0.0.0.0", port: 0)
                    self?.receiveHandler?(data, remoteEndpoint)
                }
            }

            if let error = error {
                print("[UDPSocket] Receive error: \(error)")
                return
            }

            // Continue receiving
            self?.receiveData(from: connection)
        }
    }

    // MARK: - Send Mode (Sender)

    /// Send data to a specific host and port
    public func send(_ data: Data, to host: String, port: UInt16, completion: ((Error?) -> Void)? = nil) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port)
        )

        // Create a new connection for each send (UDP is connectionless)
        let connection = NWConnection(to: endpoint, using: .udp)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: data, completion: .contentProcessed { error in
                    completion?(error)
                    connection.cancel()
                })
            case .failed(let error):
                completion?(error)
                connection.cancel()
            default:
                break
            }
        }

        connection.start(queue: queue)
    }

    /// Send data to multiple endpoints (broadcast)
    public func broadcast(_ data: Data, to endpoints: [(host: String, port: UInt16)], completion: ((Int) -> Void)? = nil) {
        let group = DispatchGroup()
        var successCount = 0
        let lock = NSLock()

        for endpoint in endpoints {
            group.enter()
            send(data, to: endpoint.host, port: endpoint.port) { error in
                if error == nil {
                    lock.lock()
                    successCount += 1
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: queue) {
            completion?(successCount)
        }
    }

    // MARK: - Close

    /// Close the socket
    public func close() {
        connection?.cancel()
        connection = nil
        receiveHandler = nil
    }
}

// MARK: - Listener Class

/// UDP listener for receiving packets
public class UDPListener {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.stableradio.udp.listener", qos: .userInitiated)
    private var connections: [NWConnection] = []
    private let connectionLock = NSLock()

    public var receiveHandler: ((Data, String) -> Void)?

    public init() {}

    deinit {
        stop()
    }

    /// Start listening on specified port
    public func start(port: UInt16) throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.acceptLocalOnly = false

        listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

        listener?.newConnectionHandler = { [weak self] newConnection in
            self?.handleNewConnection(newConnection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[UDPListener] Listening on port \(port)")
            case .failed(let error):
                print("[UDPListener] Failed: \(error)")
            case .cancelled:
                print("[UDPListener] Cancelled")
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connectionLock.lock()
        connections.append(connection)
        connectionLock.unlock()

        connection.start(queue: queue)
        receiveData(from: connection)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                // Extract source IP address
                var sourceIP = "unknown"
                if case .hostPort(let host, _) = connection.endpoint {
                    sourceIP = "\(host)"
                }
                self?.receiveHandler?(data, sourceIP)
            }

            if let error = error {
                print("[UDPListener] Receive error: \(error)")
                self?.removeConnection(connection)
                return
            }

            // Continue receiving
            self?.receiveData(from: connection)
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connectionLock.lock()
        connections.removeAll { $0 === connection }
        connectionLock.unlock()
        connection.cancel()
    }

    /// Stop listening
    public func stop() {
        listener?.cancel()
        listener = nil

        connectionLock.lock()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        connectionLock.unlock()
    }
}
