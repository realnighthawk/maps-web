import Foundation

/// What the CarPlay "Drive" screen says, decided apart from any CarPlay type so it can be tested.
///
/// Design rules for the car: one glance, no reading. Few rows, short words, the number that matters first, and
/// at most one button. Everything else (adapter choice, sign-in, planning) stays on the phone.
struct CarPlayDrive: Equatable {
    enum Action: Equatable { case start, stop, retry }
    var title: String
    var rows: [Row]
    var action: Action?

    struct Row: Equatable {
        var label: String
        var value: String
    }
}

/// The planned trip as the car shows it: the numbers that matter, then the stops. Works for any drivetrain: a stop is a
/// charge or a fuel stop. Plans are made on the phone (destination search isn't available to this kind of CarPlay app).
struct CarPlayPlanScreen: Equatable {
    struct Stop: Equatable {
        var name: String
        var detail: String
        var isCharge: Bool
        var latitude: Double
        var longitude: Double
    }
    var title: String
    var summary: [CarPlayDrive.Row]
    var stops: [Stop]
    /// Shown instead of the plan when there isn't one (or it isn't ready).
    var message: String?
}

enum CarPlayContent {
    static func plan(_ state: PlanState) -> CarPlayPlanScreen {
        func message(_ title: String, _ text: String) -> CarPlayPlanScreen {
            CarPlayPlanScreen(title: title, summary: [], stops: [], message: text)
        }
        switch state {
        case .idle: return message("Plan", "Plan a trip on your iPhone. It shows up here, with its stops.")
        case .planning(let d): return message(d.name, "Planning your route…")
        case .needsVehicleDetails(let d, _): return message(d.name, "Finish setting up this car on your iPhone to plan the trip.")
        case .failed(let d, let m, _): return message(d.name, m)
        case .ready(let dest, _, let plan, _):
            let mins = max(1, Int((plan.durationSec / 60).rounded()))
            let time = mins >= 60 ? "\(mins / 60) h \(mins % 60) min" : "\(mins) min"
            let distance = Measurement(value: plan.distanceKm, unit: UnitLength.kilometers).formatted(.measurement(width: .abbreviated, usage: .road))
            let arrive = Date().addingTimeInterval(plan.durationSec).formatted(date: .omitted, time: .shortened)
            var rows = [CarPlayDrive.Row(label: "Trip", value: "\(time) · \(distance)"), .init(label: "Arrive", value: arrive)]
            if let p = plan.arrivalPercent { rows.append(.init(label: "Arrive with", value: "\(Int(p.rounded()))% \(plan.arrivalIsCharge ? "charge" : "fuel")")) }
            if plan.totalCost > 0 { rows.append(.init(label: "About", value: plan.totalCost.formatted(.currency(code: "USD")))) }
            let stops = plan.stops.map { s in
                CarPlayPlanScreen.Stop(
                    name: s.name.isEmpty ? (s.isCharge ? "Charge stop" : "Fuel stop") : s.name,
                    detail: [s.minutes > 0 ? "\(Int(s.minutes.rounded())) min" : nil, s.cost > 0 ? s.cost.formatted(.currency(code: "USD")) : nil]
                        .compactMap { $0 }.joined(separator: " · "),
                    isCharge: s.isCharge, latitude: s.coordinate.latitude, longitude: s.coordinate.longitude)
            }
            return CarPlayPlanScreen(title: dest.name, summary: rows, stops: stops, message: nil)
        }
    }

    static func drive(state: DriveState, car: String?, drivetrain: Drivetrain = .gas, live: [String: Reading], speedKmh: Double?,
                      signedIn: Bool, streaming: Bool, pending: Int) -> CarPlayDrive {
        let title = car ?? "Garage"
        let upload = !signedIn ? "Off" : streaming ? "On" : "Paused"

        switch state {
        case .connecting(let what):
            return CarPlayDrive(title: title, rows: [.init(label: "Status", value: "Connecting to \(what)…")], action: nil)

        case .error(let message):
            return CarPlayDrive(title: title, rows: [.init(label: "Couldn't connect", value: message)], action: .retry)

        case .live:
            var rows = [CarPlayDrive.Row(label: "Speed", value: speedKmh.map(Speed.text) ?? "–")]
            rows += DriveDisplay.stats(drivetrain, live: live).map { .init(label: $0.label, value: $0.value) }
            rows.append(.init(label: "Streaming", value: signedIn && streaming ? "On" : "Saving on phone"))
            return CarPlayDrive(title: title, rows: rows, action: .stop)

        case .idle:
            var rows = [CarPlayDrive.Row(label: "Status", value: "Ready")]
            rows.append(.init(label: "Streaming", value: upload))
            if pending > 0 { rows.append(.init(label: "Waiting to upload", value: "\(pending)")) }
            return CarPlayDrive(title: title, rows: rows, action: .start)
        }
    }

    /// "12 min" or "1 h 5 min"; a drive under a minute still reads "1 min".
    static func duration(_ seconds: TimeInterval) -> String {
        let m = max(1, Int((seconds / 60).rounded()))
        return m < 60 ? "\(m) min" : "\(m / 60) h \(m % 60) min"
    }

    static func tripTitle(_ start: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = start.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(start, inSameDayAs: now) { return "Today \(time)" }
        if let y = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(start, inSameDayAs: y) { return "Yesterday \(time)" }
        return start.formatted(.dateTime.month(.abbreviated).day()) + " " + time
    }
}

/// Temperature in the user's own units, like [Speed].
enum Temp {
    static func text(_ celsius: Double) -> String {
        let unit: UnitTemperature = Locale.current.measurementSystem == .us ? .fahrenheit : .celsius
        let v = Measurement(value: celsius, unit: UnitTemperature.celsius).converted(to: unit).value
        return "\(Int(v.rounded()))\(unit.symbol)"
    }
}
