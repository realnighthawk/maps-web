import Foundation

/// Cars deleted on this phone that the server has not been told about yet. A delete made offline (or with an expired
/// sign-in) waits here until it goes through, so a deleted car does not come back on the web.
@MainActor
final class CarRemoval {
    struct Car: Codable, Hashable { let id: String; let vin: String }

    private let key = "pendingCarDeletes"
    private let auth: AuthService
    private let api = Config.routerBaseURL.isEmpty ? nil : MapsEngineAPI(baseURL: Config.routerBaseURL)
    private var flushing = false

    init(auth: AuthService) { self.auth = auth }

    private var pending: [Car] {
        get { (UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode([Car].self, from: $0) }) ?? [] }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    func queue(id: String, vin: String) {
        pending = pending.filter { $0.id != id } + [Car(id: id, vin: vin)]
        Task { await flush() }
    }

    /// A car added back before its delete went through must not be deleted from the server afterwards.
    func cancel(vin: String) {
        guard !vin.isEmpty else { return }
        pending = pending.filter { $0.vin != vin }
    }

    func flush() async {
        guard let api, !flushing, !pending.isEmpty else { return }
        flushing = true
        defer { flushing = false }
        for car in pending {
            guard var token = await auth.token() else { return }
            var r = await api.removeCar(token: token, id: car.id, vin: car.vin)
            if case .unauthorized = r {
                guard let fresh = await auth.token(skipCache: true) else { return }
                token = fresh
                r = await api.removeCar(token: token, id: car.id, vin: car.vin)
            }
            guard case .ok = r else { return } // try again next time; the car stays queued
            pending = pending.filter { $0 != car }
        }
    }
}
