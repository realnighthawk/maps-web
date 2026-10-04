import CoreLocation
import CoreMotion
import Foundation

/// Motion samples (about 20 a second) boiled down to one summary per second, so a drive streams a handful of numbers
/// instead of thousands. Phone orientation in the car is unknown, so magnitudes are used, not axes.
struct MotionAggregate {
    private var count = 0
    private var accelSum = 0.0, accelMax = 0.0, gyroSum = 0.0, gyroMax = 0.0

    mutating func add(accel: Double, gyro: Double) {
        count += 1
        accelSum += accel; accelMax = max(accelMax, accel)
        gyroSum += gyro; gyroMax = max(gyroMax, gyro)
    }

    /// The summary since the last call, then starts over. Nil if nothing arrived.
    mutating func takeSummary() -> (accelAvg: Double, accelMax: Double, gyroAvg: Double, gyroMax: Double)? {
        defer { self = MotionAggregate() }
        guard count > 0 else { return nil }
        return (accelSum / Double(count), accelMax, gyroSum / Double(count), gyroMax)
    }
}

/// What the phone itself can tell us during a drive: motion, air pressure, and the parts of the GPS fix beyond
/// latitude and longitude. Readings use the same shape as the car's, so they stream with no backend change.
@MainActor
final class PhoneSensors {
    private let motion = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var aggregate = MotionAggregate()
    private var pressureKpa: Double?
    private var relativeAltitude: Double?

    func start() {
        aggregate = MotionAggregate()
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.05
            motion.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
                guard let m else { return }
                let a = m.userAcceleration, r = m.rotationRate   // gravity already removed
                MainActor.assumeIsolated {
                    self?.aggregate.add(accel: (a.x * a.x + a.y * a.y + a.z * a.z).squareRoot(),
                                        gyro: (r.x * r.x + r.y * r.y + r.z * r.z).squareRoot())
                }
            }
        }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] d, _ in
                guard let d else { return }
                MainActor.assumeIsolated {
                    self?.pressureKpa = d.pressure.doubleValue
                    self?.relativeAltitude = d.relativeAltitude.doubleValue
                }
            }
        }
    }

    func stop() {
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        pressureKpa = nil; relativeAltitude = nil
    }

    /// This second's readings. [location] is the latest GPS fix.
    func snapshot(location: CLLocation?) -> [String: Reading] {
        var r: [String: Reading] = [:]
        func add(_ key: String, _ label: String, _ value: Double, _ unit: String) { r[key] = Reading(label: label, value: value, unit: unit) }
        if let s = aggregate.takeSummary() {
            add("phone.accel_avg", "Phone acceleration (average)", s.accelAvg, "g")
            add("phone.accel_max", "Phone acceleration (peak)", s.accelMax, "g")
            add("phone.gyro_avg", "Phone rotation rate (average)", s.gyroAvg, "rad/s")
            add("phone.gyro_max", "Phone rotation rate (peak)", s.gyroMax, "rad/s")
        }
        if let p = pressureKpa { add("phone.baro_kpa", "Air pressure", p, "kPa") }
        if let a = relativeAltitude { add("phone.alt_rel", "Relative altitude (barometer)", a, "m") }
        if let l = location {
            if l.verticalAccuracy >= 0 { add("gps.alt", "GPS altitude", l.altitude, "m") }
            if l.course >= 0 { add("gps.course", "GPS heading", l.course, "°") }
            if l.speed >= 0 { add("gps.speed", "GPS speed", l.speed * 3.6, "km/h") }
        }
        return r
    }
}
