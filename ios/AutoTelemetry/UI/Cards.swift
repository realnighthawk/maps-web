import CoreLocation
import SwiftUI

/// Speed in the user's own units (mph or km/h), so the HUD and a drive review always agree.
enum Speed {
    static var unit: UnitSpeed { Locale.current.measurementSystem == .metric ? .kilometersPerHour : .milesPerHour }
    static func value(_ kmh: Double) -> Int { Int(Measurement(value: kmh, unit: UnitSpeed.kilometersPerHour).converted(to: unit).value.rounded()) }
    static func text(_ kmh: Double) -> String { "\(value(kmh)) \(unit.symbol)" }
}

// MARK: route

/// The planned route and what it needs from the user: the numbers, the hand-off to Google Maps, or the one thing
/// to fix when planning couldn't finish.
struct RouteCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let openGarage: () -> Void
    @State private var tank = ""
    @State private var mpg = ""
    @State private var battery = ""
    @State private var range = ""
    @State private var connector = "CCS"

    var body: some View {
        Card {
            switch model.plan.plan {
            case .idle: EmptyView()
            case .planning(let d):
                header(d.name)
                HStack(spacing: 12) { ProgressView(); Text("Planning your route…").foregroundStyle(Tok.muted) }
            case .needsVehicleDetails(let d, let ev):
                header(d.name)
                if ev { evForm } else { fuelForm }
            case .failed(let d, let message, let action):
                header(d.name)
                Text(message).foregroundStyle(Tok.muted)
                failButton(action)
            case .ready(let d, let origin, let plan, let assumption):
                header(d.name)
                ready(d, origin, plan, assumption)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func header(_ name: String) -> some View {
        HStack {
            Text(name).font(.title3.bold()).lineLimit(1)
            Spacer()
            Button { model.plan.clear() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                .accessibilityLabel("Close route")
        }
    }

    @ViewBuilder private func ready(_ d: Place, _ origin: CLLocationCoordinate2D, _ plan: RoutePlan, _ assumption: String?) -> some View {
        let minutes = Int((plan.durationSec / 60).rounded())
        let arrive = Date().addingTimeInterval(plan.durationSec).formatted(date: .omitted, time: .shortened)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min").font(.largeTitle.bold())
            Text("\(Measurement(value: plan.distanceKm, unit: UnitLength.kilometers).formatted(.measurement(width: .abbreviated, usage: .road))) · arrive \(arrive)")
                .foregroundStyle(Tok.muted)
        }
        var line: [String] = []
        let _ = {
            if plan.totalCost > 0 { line.append("About " + plan.totalCost.formatted(.currency(code: "USD"))) }
            if let p = plan.arrivalPercent { line.append("Arrive with \(Int(p.rounded()))% \(plan.arrivalIsCharge ? "charge" : "fuel")") }
        }()
        if !line.isEmpty { Text(line.joined(separator: " · ")).font(.body) }
        ForEach(plan.stops) { s in
            Label("\(s.name.isEmpty ? (s.isCharge ? "Charge stop" : "Fuel stop") : s.name) · \(Int(s.minutes)) min",
                  systemImage: s.isCharge ? "bolt.fill" : "fuelpump.fill").font(.subheadline)
        }
        if let assumption { Text(assumption).font(.subheadline).foregroundStyle(Tok.muted) }
        ForEach(plan.warnings, id: \.self) { Text($0).font(.subheadline).foregroundStyle(Tok.warn) }
        Button {
            if let u = MapsHandoff.url(origin: origin, destination: d.coordinate, via: plan.stops.map(\.coordinate)) { openURL(u) }
        } label: { Label("Navigate", systemImage: "location.north.fill") }
            .buttonStyle(PrimaryButtonStyle()).padding(.top, 4)
        Text("Opens Google Maps for turn-by-turn, with your stops added.").font(.footnote).foregroundStyle(Tok.muted)
    }

    private var fuelForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To plan fuel stops we need a couple of details about your car. You'll only be asked once.").foregroundStyle(Tok.muted)
            TextField("Tank size (gallons)", text: $tank).keyboardType(.decimalPad).field()
            Text("In the owner's manual. Most cars hold 12 to 20.").font(.footnote).foregroundStyle(Tok.muted)
            TextField("Fuel economy, MPG (optional)", text: $mpg).keyboardType(.decimalPad).field()
            Button("Save and plan") {
                model.plan.saveFuelDetails(tankGallons: Double(tank) ?? 0, mpg: Double(mpg))
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .buttonStyle(PrimaryButtonStyle()).disabled((Double(tank) ?? 0) <= 0)
        }
    }

    private var evForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To plan charging stops we need a few details about your car. You'll only be asked once.").foregroundStyle(Tok.muted)
            TextField("Battery size (kWh)", text: $battery).keyboardType(.decimalPad).field()
            Text("Usable capacity, in the owner's manual. Most EVs have 40 to 100.").font(.footnote).foregroundStyle(Tok.muted)
            TextField("Range, miles (optional)", text: $range).keyboardType(.decimalPad).field()
            Picker("Charge port", selection: $connector) {
                Text("CCS").tag("CCS"); Text("Tesla").tag("TESLA"); Text("CHAdeMO").tag("CHAdeMO"); Text("J1772").tag("J1772")
            }.pickerStyle(.segmented)
            Button("Save and plan") {
                model.plan.saveEvDetails(batteryKwh: Double(battery) ?? 0, rangeMiles: Double(range), connector: connector)
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .buttonStyle(PrimaryButtonStyle()).disabled(!(10...250).contains(Double(battery) ?? 0))
        }
    }

    @ViewBuilder private func failButton(_ action: FailAction) -> some View {
        switch action {
        case .retry: Button("Try again") { model.plan.retry() }.buttonStyle(PrimaryButtonStyle())
        case .allowLocation: Button("Allow location") { model.location.requestPermission() }.buttonStyle(PrimaryButtonStyle())
        case .openGarage: Button("Open garage") { model.plan.clear(); openGarage() }.buttonStyle(PrimaryButtonStyle())
        case .none: EmptyView()
        }
    }
}

// MARK: driving

/// The map's only trace of a drive: a slim pill. Everything else lives on the Live tab.
struct DrivePill: View {
    @Environment(AppModel.self) private var model
    let openLive: () -> Void

    var body: some View {
        let d = model.drive
        HStack(spacing: 12) {
            Circle().fill(Tok.live).frame(width: 10, height: 10)
            Button(action: openLive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recording").font(.subheadline.weight(.semibold)).foregroundStyle(Tok.text)
                    HStack(spacing: 8) {
                        if let s = d.startedAt {
                            TimelineView(.periodic(from: s, by: 1)) { ctx in
                                Text(Duration.seconds(ctx.date.timeIntervalSince(s)).formatted(.time(pattern: .minuteSecond))).monospacedDigit()
                            }
                        }
                        if let kmh = d.speedKmh { Text(Speed.text(kmh)).monospacedDigit() }
                        Text("Live data").foregroundStyle(Tok.accent)
                    }
                    .font(.footnote).foregroundStyle(Tok.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button("Stop drive") { d.stop() }
                .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background(Tok.critical, in: Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Tok.surface, in: Capsule()).overlay(Capsule().stroke(Tok.hairline))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: review

/// A finished drive: when, how far, how fast, and a scrubber to move along it.
struct TripReviewCard: View {
    let trip: Trip
    let samples: [Sample]
    @Binding var scrub: Double
    let carName: String?
    let onClose: () -> Void

    private var distanceKm: Double {
        let pts = samples.compactMap { s in s.lat.flatMap { a in s.lng.map { CLLocation(latitude: a, longitude: $0) } } }
        return zip(pts, pts.dropFirst()).reduce(0) { $0 + $1.1.distance(from: $1.0) } / 1000
    }

    private var current: Sample? {
        samples.isEmpty ? nil : samples[min(samples.count - 1, Int(scrub * Double(samples.count - 1)))]
    }

    var body: some View {
        Card {
            HStack {
                VStack(alignment: .leading) {
                    Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.title3.bold())
                    if let carName { Text(carName).font(.subheadline).foregroundStyle(Tok.muted) }
                }
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Close drive")
            }
            let secs = (trip.endedAt ?? trip.startedAt).timeIntervalSince(trip.startedAt)
            HStack {
                tile("Time", Duration.seconds(secs).formatted(.time(pattern: .hourMinute)))
                tile("Distance", Measurement(value: distanceKm, unit: UnitLength.kilometers).formatted(.measurement(width: .abbreviated, usage: .road)))
                tile("Top speed", Speed.text(samples.compactMap(\.speedKmh).max() ?? 0))
            }
            if samples.count > 1 {
                Slider(value: $scrub)
                if let c = current {
                    Text("\(c.at.formatted(date: .omitted, time: .standard)) · \(Speed.text(c.speedKmh ?? 0))" +
                         (c.readings["0C"]?.value.map { " · \(Int($0)) rpm" } ?? ""))
                        .font(.footnote).foregroundStyle(Tok.muted).monospacedDigit()
                }
            } else {
                Text("No readings were recorded for this drive.").font(.subheadline).foregroundStyle(Tok.muted)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(Tok.muted)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
