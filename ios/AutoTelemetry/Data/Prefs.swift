import Foundation
import Network
import Observation

/// Streaming settings. Streaming is on by default and gates automatic uploads only; "Sync now" always uploads.
@MainActor @Observable
final class Prefs {
    private let d = UserDefaults.standard

    var streaming: Bool { didSet { d.set(streaming, forKey: "streaming") } }
    var wifiOnly: Bool { didSet { d.set(wifiOnly, forKey: "wifiOnly") } }
    /// Start a drive when the car connects (CarPlay) and end it when it disconnects. On by default. (The Shortcuts
    /// actions Start drive and Stop drive work whatever this says: they are explicit.)
    var autoStart: Bool { didSet { d.set(autoStart, forKey: "autoStart") } }
    /// True when the current network is cellular or a hotspot.
    private(set) var metered = false
    private let monitor = NWPathMonitor()

    init() {
        streaming = d.object(forKey: "streaming") as? Bool ?? true
        wifiOnly = d.bool(forKey: "wifiOnly")
        autoStart = d.object(forKey: "autoStart") as? Bool ?? true
        monitor.pathUpdateHandler = { [weak self] path in
            let expensive = path.isExpensive
            Task { @MainActor in self?.metered = expensive }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    var allowsAutoSync: Bool { streaming && !(wifiOnly && metered) }

    /// Stable id for this phone's uploads (the server stores it with each journey).
    var deviceId: String {
        if let id = d.string(forKey: "deviceId") { return id }
        let id = UUID().uuidString
        d.set(id, forKey: "deviceId")
        return id
    }

    /// updatedAt of the newest vehicle/trip already sent, so only later changes are re-sent.
    var metaCursor: Date {
        get { Date(timeIntervalSince1970: d.double(forKey: "metaCursor")) }
        set { d.set(newValue.timeIntervalSince1970, forKey: "metaCursor") }
    }
}
