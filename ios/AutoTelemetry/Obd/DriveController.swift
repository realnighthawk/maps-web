import Foundation
import Observation
import SwiftData

enum DriveState: Equatable {
    case idle
    case connecting(String)
    case live
    case error(String)
}

/// Runs a drive: connects to a source, records a trip and one sample per second (with GPS), and keeps the live
/// numbers the HUD shows. Local storage is the outbox the sync service drains.
@MainActor @Observable
final class DriveController {
    private(set) var state: DriveState = .idle
    private(set) var live: [String: Reading] = [:]
    private(set) var speedKmh: Double?
    private(set) var vehicle: Vehicle?
    private(set) var startedAt: Date?
    /// When the drive was asked for (before it connected), so a car disconnecting can tell whether it was its drive.
    private(set) var requestedAt: Date?

    private let context: ModelContext
    private let location: LocationService
    private let owner: () -> String?
    private let sync: () -> Void
    @ObservationIgnored private let phone = PhoneSensors()
    @ObservationIgnored private var source: ObdSource?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var trip: Trip?

    init(context: ModelContext, location: LocationService, owner: @escaping () -> String?, sync: @escaping () -> Void) {
        self.context = context; self.location = location; self.owner = owner; self.sync = sync
        closeStaleTrips()
    }

    var isDriving: Bool { state == .live }
    var busy: Bool { if case .connecting = state { true } else { state == .live } }
    var fuelPercent: Double? { live["2F"]?.value }

    /// [vehicle] is the car being driven (the garage's first car, or nil to learn it from the car's VIN).
    func start(source: ObdSource, title: String, vehicle: Vehicle?, adapter: (id: UUID, name: String?)? = nil) {
        guard !busy, let owner = owner() else { return }
        requestedAt = .now
        self.source = source
        state = .connecting(title)
        loop = Task {
            do {
                try await source.connect()
                let car = await resolveVehicle(vehicle, vin: await source.readVin(), owner: owner)
                self.vehicle = car
                // The VIN can reveal a different car than the card you tapped; its adapter is the one just used.
                if let car, car.id != vehicle?.id, let adapter { AdapterPrefs.set(car.id, adapter.id, name: adapter.name) }
                source.configure(vehicle: car)
                let fix = await location.current(maxAge: 30)
                let t = Trip(vehicleId: car?.id, ownerId: owner, startLat: fix?.coordinate.latitude, startLng: fix?.coordinate.longitude)
                context.insert(t)
                try? context.save()
                trip = t
                startedAt = t.startedAt
                location.startTracking()
                phone.start()
                state = .live
                await run(source: source, trip: t, owner: owner)
            } catch is CancellationError {
            } catch {
                state = .error((error as? ObdError)?.message ?? "Couldn't connect. Try again.")
                source.close()
                self.source = nil
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
        source?.close()
        source = nil
        location.stopTracking()
        phone.stop()
        if let t = trip {
            let fix = location.last
            t.status = TripStatus.completed.rawValue
            t.endedAt = .now
            t.endLat = fix?.coordinate.latitude ?? t.startLat
            t.endLng = fix?.coordinate.longitude ?? t.startLng
            t.updatedAt = .now
            try? context.save()
        }
        trip = nil; startedAt = nil; live = [:]; speedKmh = nil
        state = .idle
        sync()
    }

    func dismissError() { if case .error = state { state = .idle } }

    private func run(source: ObdSource, trip: Trip, owner: String) async {
        var ticks = 0
        while !Task.isCancelled {
            let started = Date()
            let frame = await source.poll()
            if Task.isCancelled { return }
            // Slow readings aren't polled every cycle: keep the latest known value of each for the screen.
            live.merge(frame.readings) { _, new in new }
            if let s = frame.speedKmh { speedKmh = s }
            let fix = location.last
            // The car's readings plus the phone's own (motion, pressure, GPS extras) form one record.
            var readings = frame.readings
            let phoneReadings = phone.snapshot(location: fix)
            readings.merge(phoneReadings) { _, new in new }
            // The Live screen shows all of it, plus the fix itself (the stream sends that as dedicated fields).
            live.merge(phoneReadings) { _, new in new }
            if let fix {
                live["gps.lat"] = Reading(label: "Latitude", value: fix.coordinate.latitude, unit: "°")
                live["gps.lng"] = Reading(label: "Longitude", value: fix.coordinate.longitude, unit: "°")
                if fix.horizontalAccuracy >= 0 { live["gps.acc"] = Reading(label: "GPS accuracy", value: fix.horizontalAccuracy, unit: "m") }
            }
            context.insert(Sample(tripId: trip.id, vehicleId: trip.vehicleId, ownerId: owner,
                                  lat: fix?.coordinate.latitude, lng: fix?.coordinate.longitude,
                                  speedKmh: frame.speedKmh ?? speedKmh,
                                  accuracyM: fix.flatMap { $0.horizontalAccuracy >= 0 ? $0.horizontalAccuracy : nil },
                                  readings: readings))
            ticks += 1
            if ticks % 10 == 0 { try? context.save(); sync() }
            // A cycle already takes about a second against a real car; only wait out the rest of it.
            try? await Task.sleep(for: .seconds(max(0, 1 - Date().timeIntervalSince(started))))
        }
    }

    /// The car being driven. The VIN the car reports is the truth about what is plugged in, so it wins over the garage
    /// card that was tapped (that may be a different car): match it to a car in the garage, else describe it from the
    /// VIN and add it (or fill in a car added by hand with no VIN). The demo's made-up VIN never replaces your car.
    private func resolveVehicle(_ given: Vehicle?, vin: String?, owner: String) async -> Vehicle? {
        if vin == SimulatedSource.vin, let given { return given }
        guard let vin else { return given }
        let mine = (try? context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.ownerId == owner }))) ?? []
        if let match = mine.first(where: { $0.vin == vin }) { return match }

        let m = await describe(vin)
        if let given, given.vin.isEmpty {
            given.vin = vin; given.make = m.make; given.model = m.model; given.year = m.year; given.fuelType = m.fuelType
            given.electrificationLevel = m.electrificationLevel; given.isEv = m.isEv; given.updatedAt = .now
            try? context.save()
            return given
        }
        let car = Vehicle(vin: vin, make: m.make, model: m.model, year: m.year, fuelType: m.fuelType,
                          electrificationLevel: m.electrificationLevel, isEv: m.isEv, ownerId: owner)
        context.insert(car)
        try? context.save()
        return car
    }

    private func describe(_ vin: String) async -> VehicleMetadata {
        if vin == SimulatedSource.vin {
            return VehicleMetadata(vin: vin, make: "Simulated", model: "F-150 V8 (Sim)", year: 2024, fuelType: "Gasoline", isEv: false)
        }
        if case .found(let m, _) = await VinDecoder.decode(vin) { return m }
        return VehicleMetadata(vin: vin, isEv: false)
    }

    /// A trip left ACTIVE by a crash or a killed app is closed at the last reading we have for it.
    private func closeStaleTrips() {
        let active = TripStatus.active.rawValue
        for t in (try? context.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.status == active }))) ?? [] {
            let id = t.id
            var d = FetchDescriptor<Sample>(predicate: #Predicate { $0.tripId == id }, sortBy: [SortDescriptor(\.at, order: .reverse)])
            d.fetchLimit = 1
            let last = (try? context.fetch(d))?.first
            t.status = TripStatus.interrupted.rawValue
            t.endedAt = last?.at ?? t.startedAt
            t.endLat = last?.lat ?? t.startLat
            t.endLng = last?.lng ?? t.startLng
            t.updatedAt = .now
        }
        try? context.save()
    }
}
