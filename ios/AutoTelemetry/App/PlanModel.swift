import CoreLocation
import Foundation
import Observation

enum SearchState {
    case idle, loading
    case results([Place])
    case error(String)
}

/// What the user can do about a failed plan.
enum FailAction { case retry, allowLocation, openGarage, none }

enum PlanState {
    case idle
    case planning(Place)
    case ready(dest: Place, origin: CLLocationCoordinate2D, plan: RoutePlan, assumption: String?)
    /// The planner lacks something about this car (tank size, or battery size and connector): ask, save, plan again.
    case needsVehicleDetails(Place, ev: Bool)
    case failed(Place, message: String, action: FailAction)

    var destination: Place? {
        switch self {
        case .idle: nil
        case .planning(let p), .needsVehicleDetails(let p, _), .failed(let p, _, _): p
        case .ready(let p, _, _, _): p
        }
    }
}

/// Destination search and route planning against the user's own maps-engine. The planner needs the car's VIN
/// (registered with the server on first use), where you are, and how much charge or fuel you have.
@MainActor @Observable
final class PlanModel {
    private(set) var search: SearchState = .idle
    private(set) var plan: PlanState = .idle

    private let api: MapsEngineAPI?
    private let auth: AuthService
    private let location: LocationService
    private let activeVehicle: () -> Vehicle?
    private let liveFuel: () -> Double?
    private let liveCharge: () -> Double?

    private var nearHint: CLLocationCoordinate2D?
    private var searchTask: Task<Void, Never>?
    private var planTask: Task<Void, Never>?
    private var lastDest: Place?

    private static let assumedFuel = 75
    private static let assumedCharge = 80

    init(auth: AuthService, location: LocationService, activeVehicle: @escaping () -> Vehicle?, liveFuel: @escaping () -> Double?,
         liveCharge: @escaping () -> Double?) {
        api = Config.routerBaseURL.isEmpty ? nil : MapsEngineAPI(baseURL: Config.routerBaseURL)
        self.auth = auth; self.location = location; self.activeVehicle = activeVehicle; self.liveFuel = liveFuel; self.liveCharge = liveCharge
    }

    /// Called when search opens: learn roughly where we are so results rank by distance.
    func beginSearch() {
        Task { if let l = await location.current() { nearHint = l.coordinate } }
    }

    func onQuery(_ raw: String) {
        searchTask?.cancel()
        let q = raw.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { search = .idle; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300)) // typing, not tapping: wait for a pause
            if Task.isCancelled { return }
            search = .loading
            guard let api else { return search = .error("This build has no server address, so search is off.") }
            guard case .signedIn = auth.state else { return search = .error("Sign in to search places and plan routes.") }
            guard let token = await auth.token() else { return search = .error("Couldn't reach your account. Check your connection.") }
            let r = await api.searchPlaces(token: token, query: q, near: nearHint)
            if Task.isCancelled { return }
            switch r {
            case .ok(let p): search = .results(p)
            case .unauthorized: search = .error("Sign in again to search places.")
            case .notProvisioned: search = .error("Your garage isn't set up on the server yet.")
            case .retry: search = .error("Couldn't reach the server. Check your connection.")
            case .failed(_, let m): search = .error(m)
            }
        }
    }

    func choose(_ place: Place) { lastDest = place; startPlan(place) }
    func retry() { if let d = lastDest { startPlan(d) } }

    func clear() {
        planTask?.cancel()
        lastDest = nil
        plan = .idle
    }

    /// Saves the tank size (and optionally MPG) to the car's planner profile, then plans again.
    func saveFuelDetails(tankGallons: Double, mpg: Double?) {
        saveProfile { car in
            VehicleProfiles.ice(vin: car.vin, make: car.make, model: car.model, year: car.year, tankGallons: tankGallons, mpg: mpg)
        }
    }

    /// Saves the battery size, optional EPA range and charge connector to the car's planner profile, then plans again.
    func saveEvDetails(batteryKwh: Double, rangeMiles: Double?, connector: String) {
        saveProfile { car in
            VehicleProfiles.ev(vin: car.vin, make: car.make, model: car.model, year: car.year,
                               batteryKwh: batteryKwh, rangeMiles: rangeMiles, connector: connector)
        }
    }

    private func saveProfile(_ build: @escaping (Vehicle) -> [String: Any]) {
        guard let dest = lastDest, let car = activeVehicle(), !car.vin.isEmpty else { return }
        let profile = build(car), vin = car.vin
        planTask?.cancel()
        planTask = Task {
            plan = .planning(dest)
            guard let token = await auth.token() else { return fail(dest, "Couldn't reach your account. Check your connection.") }
            switch await api?.putProfile(token: token, vin: vin, profile: profile) {
            case .ok: startPlan(dest)
            case .failed(_, let m): fail(dest, "Couldn't save the details: \(m)")
            default: fail(dest, "Couldn't reach the server. Check your connection.")
            }
        }
    }

    /// The location permission dialog closed: if that was what the plan was waiting for, try again.
    func onLocationPermissionResult() {
        if case .failed(_, _, .allowLocation) = plan { retry() }
    }

    private func fail(_ dest: Place, _ message: String, _ action: FailAction = .retry) {
        plan = .failed(dest, message: message, action: action)
    }

    private func startPlan(_ dest: Place) {
        planTask?.cancel()
        planTask = Task { await runPlan(dest) }
    }

    private func runPlan(_ dest: Place) async {
        plan = .planning(dest)
        guard let api else { return fail(dest, "This build has no server address, so routes can't be planned.", .none) }
        guard let car = activeVehicle() else { return fail(dest, "Add a car to your garage to plan routes.", .openGarage) }
        guard !car.vin.isEmpty else { return fail(dest, "Planning needs this car's VIN. Add it in your garage.", .openGarage) }

        guard let origin = (await location.current())?.coordinate else {
            return location.authorized
                ? fail(dest, "Couldn't find your location. Try again with a clear view of the sky.")
                : fail(dest, "Allow location so we can plan from where you are.", .allowLocation)
        }
        guard case .signedIn = auth.state else { return fail(dest, "Sign in to plan routes.", .none) }
        guard var token = await auth.token() else { return fail(dest, "Couldn't reach your account. Check your connection.") }

        let (body, assumption) = request(car: car, origin: origin, dest: dest)
        var result = await api.planRoute(token: token, request: body)

        // Unauthorized once is usually an expired token; the server not knowing the car just means it's new.
        if case .unauthorized = result {
            guard let t = await auth.token(skipCache: true) else { return fail(dest, "Sign in again to plan routes.", .none) }
            token = t
            result = await api.planRoute(token: token, request: body)
        }
        if case .failed(let code, _) = result, code == "VIN_NOT_FOUND" || code == "VEHICLE_NOT_FOUND" {
            switch await api.registerVin(token: token, vin: car.vin) {
            case .ok: result = await api.planRoute(token: token, request: body)
            case .failed(_, let m): return fail(dest, "The car lookup failed: \(m)")
            default: break
            }
        }
        if Task.isCancelled { return }

        switch result {
        case .ok(let p): plan = .ready(dest: dest, origin: origin, plan: p, assumption: assumption)
        case .failed(let code, _) where code == "VEHICLE_DATA_MISSING":
            plan = .needsVehicleDetails(dest, ev: car.isEv)
        case .failed(let code, let m): fail(dest, Self.message(code, m))
        case .unauthorized: fail(dest, "Sign in again to plan routes.", .none)
        case .notProvisioned: fail(dest, "Your garage isn't set up on the server yet.", .none)
        case .retry: fail(dest, "Couldn't reach the server. Check your connection.")
        }
    }

    /// The request body, plus a note when charge or fuel had to be guessed.
    private func request(car: Vehicle, origin: CLLocationCoordinate2D, dest: Place) -> ([String: Any], String?) {
        func ll(_ c: CLLocationCoordinate2D) -> [String: Any] { ["lat": c.latitude, "lng": c.longitude] }
        var state: [String: Any] = ["location": ll(origin), "speedKmh": 0]
        var note: String?
        if car.isEv {
            let charge = liveCharge()
            state["ev"] = ["soc": charge ?? Double(Self.assumedCharge), "batteryTempC": 25]
            if charge == nil { note = "Assuming \(Self.assumedCharge)% charge. Connect your adapter for the real level." }
        } else {
            let fuel = liveFuel()
            state["ice"] = ["fuelLevelPercent": fuel ?? Double(Self.assumedFuel)]
            if fuel == nil { note = "Assuming \(Self.assumedFuel)% fuel. Connect your adapter for the real level." }
        }
        return (["vehicleVin": car.vin, "origin": ll(origin), "destination": ll(dest.coordinate), "currentState": state], note)
    }

    private static func message(_ code: String?, _ fallback: String) -> String {
        switch code {
        case "NO_CHARGER_COVERAGE": "No charging stations found along this route for your car."
        case "NO_FUEL_STATION": "No fuel stops found along this route."
        case "UNREACHABLE_DESTINATION": "Your car can't reach this destination with the charge or fuel it has."
        case "DRIVETRAIN_UNSUPPORTED": "Route planning doesn't support this type of car yet."
        case "NO_FEASIBLE_ROUTE": "No drivable route found."
        default: fallback
        }
    }
}
