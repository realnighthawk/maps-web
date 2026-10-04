import CoreLocation
import Observation

/// Where the phone is: a quick one-shot for planning, and continuous tracking while a drive is recorded.
@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private(set) var last: CLLocation?
    private(set) var authorization: CLAuthorizationStatus

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var waiting: [CheckedContinuation<CLLocation?, Never>] = []
    @ObservationIgnored private var tracking = false

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        if authorized { manager.requestLocation() }
    }

    var authorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }
    var denied: Bool { authorization == .denied || authorization == .restricted }

    func requestPermission() { manager.requestWhenInUseAuthorization() }

    /// A fix no older than [maxAge] seconds, waiting briefly for a new one if needed. Nil without permission or signal.
    func current(maxAge: TimeInterval = 120) async -> CLLocation? {
        if let l = last, -l.timestamp.timeIntervalSinceNow < maxAge { return l }
        guard authorized else { return nil }
        return await withCheckedContinuation { c in
            waiting.append(c)
            manager.requestLocation()
            Task {
                try? await Task.sleep(for: .seconds(8))
                resolve(last.flatMap { -$0.timestamp.timeIntervalSinceNow < maxAge ? $0 : nil })
            }
        }
    }

    /// Keeps fixes coming while a drive is recorded, including with the screen off.
    func startTracking() {
        guard authorized, !tracking else { return }
        tracking = true
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        guard tracking else { return }
        tracking = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func resolve(_ loc: CLLocation?) {
        let w = waiting
        waiting = []
        w.forEach { $0.resume(returning: loc) }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let l = locations.last else { return }
            last = l
            resolve(l)
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        MainActor.assumeIsolated {
            authorization = m.authorizationStatus
            if authorized { m.requestLocation() }
        }
    }
}
