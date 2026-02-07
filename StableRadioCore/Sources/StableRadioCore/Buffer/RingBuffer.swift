import Foundation

// MARK: - Sequence Number Extension

extension UInt32 {
    /// Check if this sequence number comes before another (handles wrap-around)
    func isBefore(_ other: UInt32) -> Bool {
        let diff = Int64(other) - Int64(self)
        let halfMax = Int64(UInt32.max) / 2

        if diff > halfMax {
            return false
        } else if diff < -halfMax {
            return false
        } else {
            return diff > 0
        }
    }
}

/// Thread-safe ring buffer for audio data
public class RingBuffer {
    private var buffer: [UInt8]
    private var readIndex: Int = 0
    private var writeIndex: Int = 0
    private var availableBytes: Int = 0
    private let lock = NSLock()
    private let capacity: Int

    /// Current fill level (0.0 to 1.0)
    public var fillLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return Float(availableBytes) / Float(capacity)
    }

    /// Available bytes to read
    public var available: Int {
        lock.lock()
        defer { lock.unlock() }
        return availableBytes
    }

    /// Free space available to write
    public var freeSpace: Int {
        lock.lock()
        defer { lock.unlock() }
        return capacity - availableBytes
    }

    /// Initialize with capacity in bytes
    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [UInt8](repeating: 0, count: capacity)
    }

    /// Write data to the buffer
    /// Returns number of bytes actually written
    @discardableResult
    public func write(_ data: Data) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let bytesToWrite = min(data.count, capacity - availableBytes)
        guard bytesToWrite > 0 else { return 0 }

        data.withUnsafeBytes { sourceBytes in
            guard let sourcePtr = sourceBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            // Write in two parts if wrapping around
            let firstChunkSize = min(bytesToWrite, capacity - writeIndex)
            let secondChunkSize = bytesToWrite - firstChunkSize

            // First chunk
            buffer.withUnsafeMutableBufferPointer { bufferPtr in
                let destPtr = bufferPtr.baseAddress! + writeIndex
                destPtr.update(from: sourcePtr, count: firstChunkSize)
            }

            // Second chunk (if wrapping)
            if secondChunkSize > 0 {
                buffer.withUnsafeMutableBufferPointer { bufferPtr in
                    let destPtr = bufferPtr.baseAddress!
                    destPtr.update(from: sourcePtr + firstChunkSize, count: secondChunkSize)
                }
            }

            writeIndex = (writeIndex + bytesToWrite) % capacity
            availableBytes += bytesToWrite
        }

        return bytesToWrite
    }

    /// Read data from the buffer
    /// Returns Data with requested bytes (or fewer if not enough available)
    public func read(count: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }

        let bytesToRead = min(count, availableBytes)
        guard bytesToRead > 0 else { return Data() }

        var data = Data(count: bytesToRead)

        data.withUnsafeMutableBytes { destBytes in
            guard let destPtr = destBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            // Read in two parts if wrapping around
            let firstChunkSize = min(bytesToRead, capacity - readIndex)
            let secondChunkSize = bytesToRead - firstChunkSize

            // First chunk
            buffer.withUnsafeBufferPointer { bufferPtr in
                let sourcePtr = bufferPtr.baseAddress! + readIndex
                destPtr.update(from: sourcePtr, count: firstChunkSize)
            }

            // Second chunk (if wrapping)
            if secondChunkSize > 0 {
                buffer.withUnsafeBufferPointer { bufferPtr in
                    let sourcePtr = bufferPtr.baseAddress!
                    destPtr.advanced(by: firstChunkSize).update(from: sourcePtr, count: secondChunkSize)
                }
            }

            readIndex = (readIndex + bytesToRead) % capacity
            availableBytes -= bytesToRead
        }

        return data
    }

    /// Peek at data without removing it from the buffer
    public func peek(count: Int) -> Data {
        lock.lock()
        defer { lock.unlock() }

        let bytesToPeek = min(count, availableBytes)
        guard bytesToPeek > 0 else { return Data() }

        var data = Data(count: bytesToPeek)

        data.withUnsafeMutableBytes { destBytes in
            guard let destPtr = destBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

            let peekIndex = readIndex
            let firstChunkSize = min(bytesToPeek, capacity - peekIndex)
            let secondChunkSize = bytesToPeek - firstChunkSize

            buffer.withUnsafeBufferPointer { bufferPtr in
                let sourcePtr = bufferPtr.baseAddress! + peekIndex
                destPtr.update(from: sourcePtr, count: firstChunkSize)
            }

            if secondChunkSize > 0 {
                buffer.withUnsafeBufferPointer { bufferPtr in
                    let sourcePtr = bufferPtr.baseAddress!
                    destPtr.advanced(by: firstChunkSize).update(from: sourcePtr, count: secondChunkSize)
                }
            }
        }

        return data
    }

    /// Skip/discard bytes from the buffer
    @discardableResult
    public func skip(count: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let bytesToSkip = min(count, availableBytes)
        guard bytesToSkip > 0 else { return 0 }

        readIndex = (readIndex + bytesToSkip) % capacity
        availableBytes -= bytesToSkip

        return bytesToSkip
    }

    /// Clear all data from the buffer
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        readIndex = 0
        writeIndex = 0
        availableBytes = 0
    }
}

/// Packet-based ring buffer with sequence number support
public class PacketRingBuffer {
    private var packets: [UInt32: Data] = [:] // Sequence number -> audio data
    private var nextSequenceToRead: UInt32 = 0
    private var maxBufferedPackets: Int
    private var totalBufferedBytes: Int = 0
    private let lock = NSLock()

    /// Maximum buffer size in bytes
    public let maxBufferSize: Int

    /// Current number of buffered packets
    public var packetCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return packets.count
    }

    /// Current buffered bytes
    public var bufferedBytes: Int {
        lock.lock()
        defer { lock.unlock() }
        return totalBufferedBytes
    }

    /// Fill level (0.0 to 1.0)
    public var fillLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return Float(totalBufferedBytes) / Float(maxBufferSize)
    }

    public init(maxBufferSize: Int) {
        self.maxBufferSize = maxBufferSize
        // Assume average packet size of 1024 bytes
        self.maxBufferedPackets = maxBufferSize / 1024
    }

    /// Insert a packet with sequence number
    public func insert(sequence: UInt32, data: Data) {
        lock.lock()
        defer { lock.unlock() }

        // Don't insert if this is an old packet
        if sequence.isBefore(nextSequenceToRead) {
            return
        }

        // Don't insert duplicates
        if packets[sequence] != nil {
            return
        }

        // Enforce buffer size limit
        while totalBufferedBytes + data.count > maxBufferSize && !packets.isEmpty {
            // Remove oldest packet
            if let oldData = packets.removeValue(forKey: nextSequenceToRead) {
                totalBufferedBytes -= oldData.count
            }
            nextSequenceToRead = nextSequenceToRead &+ 1
        }

        packets[sequence] = data
        totalBufferedBytes += data.count
    }

    /// Read next packet in sequence
    /// Returns nil if next packet is not available
    public func readNext() -> Data? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = packets.removeValue(forKey: nextSequenceToRead) else {
            return nil
        }

        totalBufferedBytes -= data.count
        nextSequenceToRead = nextSequenceToRead &+ 1
        return data
    }

    /// Check if next packet is available
    public func hasNext() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return packets[nextSequenceToRead] != nil
    }

    /// Detect missing packets in sequence
    /// Returns array of missing sequence numbers up to a limit
    public func detectMissing(maxGapSize: Int = 100) -> [UInt32] {
        lock.lock()
        defer { lock.unlock() }

        var missing: [UInt32] = []
        guard !packets.isEmpty else { return missing }

        // Find the highest sequence number we have
        let maxSeq = packets.keys.max() ?? nextSequenceToRead

        // Check for gaps
        var seq = nextSequenceToRead
        var gapCount = 0

        while seq.isBefore(maxSeq) && gapCount < maxGapSize {
            if packets[seq] == nil {
                missing.append(seq)
                gapCount += 1
            }
            seq = seq &+ 1
        }

        return missing
    }

    /// Clear all packets
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        packets.removeAll()
        totalBufferedBytes = 0
        nextSequenceToRead = 0
    }

    /// Reset to specific sequence number
    public func reset(to sequence: UInt32) {
        lock.lock()
        defer { lock.unlock() }

        packets.removeAll()
        totalBufferedBytes = 0
        nextSequenceToRead = sequence
    }
}
