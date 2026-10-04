import Foundation

/// Connection diagnostics, kept on the phone (last 3000 lines) and printed to the console. When an adapter won't
/// connect, the log shows whether it failed at the Bluetooth link, the adapter's data channel, or the car.
enum Diag {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var buffer: [String] = []
    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    /// Per-command tx/rx lines. On while connecting and for the first poll, then off so polling (about 10 lines a
    /// second) doesn't push the connection steps out of the 300-line buffer.
    nonisolated(unsafe) static var verbose = true

    static func log(_ message: String) {
        let line = "\(time.string(from: .now)) \(message)"
        print("[OBD] \(line)")
        lock.lock(); defer { lock.unlock() }
        buffer.append(line)
        if buffer.count > 3000 { buffer.removeFirst(buffer.count - 3000) }
    }

    static var lines: [String] {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }

    static func clear() {
        lock.lock(); defer { lock.unlock() }
        buffer.removeAll()
    }
}
