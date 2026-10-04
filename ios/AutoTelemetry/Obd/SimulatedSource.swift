import Foundation

/// A realistic drive without hardware: idle, city, cruise, braking (and optionally a harsh phase). Same PID keys
/// a real adapter produces, so the HUD and the upload see no difference.
final class SimulatedSource: ObdSource {
    static let vin = "SIMICEV8TRUCK2024"
    private let aggressive: Bool
    private let ev: Bool
    private var charge = 78.0
    private var start = Date()
    private var coolant = 65.0
    private var lastSpeed = 0.0

    init(aggressive: Bool = true, ev: Bool = false) { self.aggressive = aggressive; self.ev = ev }

    func connect() async throws {
        start = Date()
        coolant = 60 + Double.random(in: 0...15)
        try? await Task.sleep(for: .milliseconds(600))
    }

    func readVin() async -> String? { Self.vin }
    func close() {}

    func poll() async -> ObdFrame {
        let t = Date().timeIntervalSince(start)
        let (rpm, speed) = values(t)
        lastSpeed = speed
        let throttle = min(100, speed / 140 * 100)
        if ev {
            // An electric car: charge, pedal, outside temperature, 12 V battery. No rpm, coolant or fuel.
            charge = max(5, charge - speed / 3600 * 0.3)
            return ObdFrame(speedKmh: speed.rounded(), readings: [
                "0D": Reading(label: "Vehicle Speed", value: speed.rounded(), unit: "km/h"),
                "5B": Reading(label: "Battery Charge", value: charge, unit: "%"),
                "49": Reading(label: "Accelerator Pedal Position D", value: throttle, unit: "%"),
                "46": Reading(label: "Ambient Air Temperature", value: 18, unit: "°C"),
                "42": Reading(label: "Control Module Voltage", value: 12.6, unit: "V"),
            ])
        }
        let readings: [String: Reading] = [
            "0D": Reading(label: "Vehicle Speed", value: speed.rounded(), unit: "km/h"),
            "0C": Reading(label: "Engine RPM", value: rpm.rounded(), unit: "rpm"),
            "05": Reading(label: "Engine Coolant Temperature", value: coolant, unit: "°C"),
            "11": Reading(label: "Throttle Position", value: throttle, unit: "%"),
            "04": Reading(label: "Calculated Engine Load", value: min(100, throttle * 0.8 + rpm / 400), unit: "%"),
            "2F": Reading(label: "Fuel Tank Level", value: 62, unit: "%"),
        ]
        return ObdFrame(speedKmh: speed.rounded(), readings: readings)
    }

    // Phase lengths in seconds: idle 25, city start 50, cruise 90, braking 25, aggressive 15.
    private func values(_ elapsed: Double) -> (rpm: Double, speed: Double) {
        let total = aggressive ? 205.0 : 190.0
        let t = elapsed.truncatingRemainder(dividingBy: total)
        func r(_ a: Int, _ b: Int) -> Double { Double.random(in: Double(a)...Double(b)) }
        switch t {
        case ..<25:
            coolant = min(75, coolant + 0.02)
            return (r(750, 950), 0)
        case ..<75:
            let p = (t - 25) / 50
            coolant = min(90, coolant + 0.05)
            return (min(3000, 1200 + p * 1300 + r(-100, 100)), max(0, p * 35 + r(-1, 1)))
        case ..<165:
            coolant = min(95, max(85, coolant + 0.02))
            return (1800 + r(0, 1000) + sin(t * 0.15) * 200, 45 + r(0, 20) + sin(t * 0.1) * 5)
        case ..<190:
            let p = (t - 165) / 25
            return (800 + r(0, 150) + p * 200, max(0, lastSpeed * (1 - p)))
        default:
            let p = (t - 190) / 15
            if p < 0.3 { return (2500 + p / 0.3 * 2000 + r(0, 500), p / 0.3 * 70) }
            if p < 0.6 { return (r(1200, 1600), max(0, 70 * (1 - (p - 0.3) / 0.3))) }
            return (r(4600, 5400) * (1 - (p - 0.6) / 0.4) + 800, 40 * (1 - (p - 0.6) / 0.4))
        }
    }
}
