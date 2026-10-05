import Foundation
import Observation
import SwiftData

/// The app's long-lived pieces, built once and shared with every screen.
@MainActor @Observable
final class AppModel {
    /// One model for the phone UI and CarPlay, which can start the app on its own with no phone window.
    static let shared = AppModel()

    let container: ModelContainer
    let auth = AuthService()
    let prefs = Prefs()
    let location = LocationService()
    let ble = BleAdapters()
    let sync: SyncService
    let carRemoval: CarRemoval
    let drive: DriveController
    let plan: PlanModel
    /// The drive shown on the map for review (picked from search). One thing on the map at a time.
    var reviewTrip: Trip?

    init() {
        container = try! ModelContainer(for: Vehicle.self, Trip.self, Sample.self)
        let context = container.mainContext
        let auth = self.auth, location = self.location, prefs = self.prefs
        let sync = SyncService(context: context, auth: auth, prefs: prefs)
        self.sync = sync
        carRemoval = CarRemoval(auth: auth)
        let drive = DriveController(context: context, location: location, owner: { auth.ownerId }, sync: { Task { await sync.sync() } })
        self.drive = drive
        plan = PlanModel(
            auth: auth, location: location,
            activeVehicle: {
                guard let owner = auth.ownerId else { return nil }
                let cars = (try? context.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.ownerId == owner },
                                                                         sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
                return drive.vehicle ?? cars.first
            },
            liveFuel: { drive.fuelPercent }, liveCharge: { drive.live["5B"]?.value })
    }

    /// The signed-in (or guest) user's cars, newest first. The first one is the active car.
    func ownedVehicles() -> [Vehicle] {
        guard let owner = auth.ownerId else { return [] }
        return (try? container.mainContext.fetch(FetchDescriptor<Vehicle>(
            predicate: #Predicate { $0.ownerId == owner }, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
    }

    /// A car scan in progress (see CarScan), and what it is doing now.
    private(set) var scanning = false
    private(set) var scanProgress = ""

    /// Runs the read-only car scan through [car]'s adapter and leaves the result in the connection log.
    func scanCar(_ car: Vehicle) async {
        guard !drive.busy else { return Diag.log("scan: a drive is running; end it first") }
        guard !scanning else { return }
        guard let id = AdapterPrefs.get(car.id), let link = ble.link(for: id) else {
            return Diag.log("scan: no adapter for \(car.displayName) (Bluetooth state \(ble.state.rawValue))")
        }
        scanning = true
        Diag.clear()
        await CarScan.run(link: link, car: car) { [weak self] in self?.scanProgress = $0 }
        scanning = false
    }

    /// The car whose screen should open next (the map asks when a drive can't start for lack of an adapter).
    var openCarId: String?

    /// Starts a drive with the active car's usual adapter. False when it has none yet: the caller shows the car's screen.
    @discardableResult
    func quickStartDrive() -> Bool { lastUsedCar().map(startDrive(car:)) ?? false }

    /// The car you drove most recently that has an adapter set up (see LastUsedCar).
    func lastUsedCar() -> Vehicle? {
        guard let owner = auth.ownerId else { return nil }
        let withAdapter = ownedVehicles().filter { AdapterPrefs.get($0.id) != nil }
        var d = FetchDescriptor<Trip>(predicate: #Predicate { $0.ownerId == owner }, sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        d.fetchLimit = 25
        let recent = ((try? container.mainContext.fetch(d)) ?? []).map(\.vehicleId)
        guard let id = LastUsedCar.pick(carsWithAdapter: withAdapter.map(\.id), recentTripCars: recent) else { return nil }
        return withAdapter.first { $0.id == id }
    }

    /// Starts a drive with the last-used car's adapter, for when the car connects or a shortcut asks. The app may have
    /// just been launched, so wait a few seconds for sign-in and Bluetooth to be ready. A drive already running, or a
    /// scan in progress, is left alone.
    @discardableResult
    func autoStartDrive() async -> Bool {
        for _ in 0..<48 where auth.ownerId == nil || ble.state != .poweredOn { try? await Task.sleep(for: .milliseconds(250)) }
        guard !drive.busy, !scanning else { return false }
        return quickStartDrive()
    }

    /// Connects to [car]'s own adapter (another car's dongle isn't plugged into this one) and starts a drive.
    @discardableResult
    func startDrive(car: Vehicle) -> Bool {
        guard !scanning, auth.ownerId != nil, let id = AdapterPrefs.get(car.id), let link = ble.link(for: id) else { return false }
        drive.start(source: ElmSource(link: link, hint: car), title: car.displayName, vehicle: car, adapter: (id, AdapterPrefs.name(car.id)))
        return true
    }

    /// A guest's cars and drives belong to the account on first sign-in.
    func adoptGuestData(into owner: String) {
        let c = container.mainContext
        let guest = guestOwnerId
        for v in (try? c.fetch(FetchDescriptor<Vehicle>(predicate: #Predicate { $0.ownerId == guest }))) ?? [] { v.ownerId = owner; v.updatedAt = .now }
        for t in (try? c.fetch(FetchDescriptor<Trip>(predicate: #Predicate { $0.ownerId == guest }))) ?? [] { t.ownerId = owner; t.updatedAt = .now }
        for s in (try? c.fetch(FetchDescriptor<Sample>(predicate: #Predicate { $0.ownerId == guest }))) ?? [] { s.ownerId = owner }
        try? c.save()
    }
}
