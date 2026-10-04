import Foundation

struct DriveStat: Equatable {
    var label: String
    var value: String
}

/// Which measurements to show for a car, by drivetrain, and only the ones the car actually reports. An electric
/// car shows its charge, not rpm and fuel; a combustion car the other way round.
enum DriveDisplay {
    static func stats(_ drivetrain: Drivetrain, live: [String: Reading]) -> [DriveStat] {
        func pct(_ label: String, _ v: Double?) -> DriveStat? { v.map { DriveStat(label: label, value: "\(Int($0.rounded()))%") } }
        let charge = pct("Charge", live["5B"]?.value)
        let throttle = pct(drivetrain == .ev ? "Pedal" : "Throttle", PidRegistry.throttle(live))
        let rpm = live["0C"]?.value.map { DriveStat(label: "RPM", value: "\(Int($0.rounded()))") }
        let coolant = live["05"]?.value.map { DriveStat(label: "Coolant", value: Temp.text($0)) }
        let fuel = pct("Fuel", live["2F"]?.value)
        let outside = live["46"]?.value.map { DriveStat(label: "Outside", value: Temp.text($0)) }
        let volts = live["42"]?.value.map { DriveStat(label: "12 V", value: String(format: "%.1f V", $0)) }

        switch drivetrain {
        case .ev: return [charge, throttle, outside, volts].compactMap { $0 }
        case .hybrid: return [charge, rpm, coolant, fuel].compactMap { $0 }
        case .gas, .diesel: return [rpm, coolant, throttle, fuel].compactMap { $0 }
        }
    }
}
