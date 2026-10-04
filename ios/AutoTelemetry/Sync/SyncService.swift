import Foundation
import Observation
import SwiftData

enum SyncPhase: Equatable { case idle, syncing, done, failed(String) }

/// Uploads what the phone recorded to the user's own maps-engine, through the router.
/// Local storage is the outbox: readings stay unsynced until the server confirms them, so a crash, a dead zone
/// or a lost response only ever causes a harmless re-send (the server ignores duplicates by record_id).
@MainActor @Observable
final class SyncService {
    private(set) var phase: SyncPhase = .idle
    private(set) var pending = 0

    private let context: ModelContext
    private let auth: AuthService
    private let prefs: Prefs
    private let http = Http(baseURL: Config.routerBaseURL)
    private let batchSize = 500

    init(context: ModelContext, auth: AuthService, prefs: Prefs) {
        self.context = context; self.auth = auth; self.prefs = prefs
        refreshPending()
    }

    func refreshPending() {
        pending = (try? context.fetchCount(FetchDescriptor<Sample>(predicate: #Predicate { !$0.synced }))) ?? 0
    }

    /// [manual] = user tapped "Sync now"; bypasses the streaming settings.
    func sync(manual: Bool = false) async {
        guard phase != .syncing else { return }
        if !manual && !prefs.allowsAutoSync { return }
        guard !Config.routerBaseURL.isEmpty, case .signedIn(let owner, _) = auth.state else { return }
        phase = .syncing
        let result = await run(owner: owner)
        refreshPending()
        phase = result.map { .failed($0) } ?? .done
        if manual || result == nil {
            try? await Task.sleep(for: .seconds(3))
            if phase != .syncing { phase = .idle }
        }
    }

    /// Returns an error message, or nil when everything went up.
    private func run(owner: String) async -> String? {
        guard var token = await auth.token() else { return "Couldn't reach your account." }
        var refreshed = false

        enum Sent { case ok(accepted: Set<String>, rejected: Set<String>), stop(String) }
        func send(_ body: [String: Any]) async -> Sent {
            guard let data = try? JSONSerialization.data(withJSONObject: body) else { return .stop("encode failed") }
            while true {
                guard let r = await http.send("POST", "/maps/api/v1/ingest/batch", token: token, body: data, timeout: 45) else {
                    return .stop("network error")
                }
                switch r.code {
                case 200...299:
                    let j = (try? JSONSerialization.jsonObject(with: Data(r.text.utf8))) as? [String: Any]
                    let acc = Set(j?["accepted_observations"] as? [String] ?? [])
                    let rej = Set((j?["rejected"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String })
                    return .ok(accepted: acc, rejected: rej)
                case 401, 403:
                    // The token may simply have expired mid-run: one fresh attempt before giving up.
                    if refreshed { return .stop("Sign in again to resume streaming.") }
                    refreshed = true
                    guard let t = await auth.token(skipCache: true) else { return .stop("Couldn't reach your account.") }
                    token = t
                case 404 where r.text.contains("no_tenant"): return .stop("Your garage isn't set up on the server yet.")
                default: return .stop("server returned \(r.code)")
                }
            }
        }

        // 1. Changes to vehicles and trips that no new reading would carry (e.g. a trip that just ended).
        let cursor = prefs.metaCursor
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>(
            predicate: #Predicate { $0.ownerId == owner && $0.updatedAt > cursor }, sortBy: [SortDescriptor(\.updatedAt)]))) ?? []
        let trips = (try? context.fetch(FetchDescriptor<Trip>(
            predicate: #Predicate { $0.ownerId == owner && $0.updatedAt > cursor }, sortBy: [SortDescriptor(\.updatedAt)]))) ?? []
        if !vehicles.isEmpty || !trips.isEmpty {
            switch await send(BatchMapper.json(deviceId: prefs.deviceId, vehicles: vehicles, trips: trips, samples: [])) {
            case .stop(let m): return m
            case .ok: prefs.metaCursor = (vehicles.map(\.updatedAt) + trips.map(\.updatedAt)).max() ?? cursor
            }
        }

        // 2. Readings, oldest first, with the vehicles and trips they point at.
        while true {
            var d = FetchDescriptor<Sample>(predicate: #Predicate { !$0.synced && $0.ownerId == owner },
                                            sortBy: [SortDescriptor(\.at)])
            d.fetchLimit = batchSize
            let batch = (try? context.fetch(d)) ?? []
            if batch.isEmpty { return nil }

            let tripIds = Set(batch.compactMap(\.tripId)), vehicleIds = Set(batch.compactMap(\.vehicleId))
            let tripRows = ((try? context.fetch(FetchDescriptor<Trip>())) ?? []).filter { tripIds.contains($0.id) }
            let vehicleRows = ((try? context.fetch(FetchDescriptor<Vehicle>())) ?? []).filter { vehicleIds.contains($0.id) }

            switch await send(BatchMapper.json(deviceId: prefs.deviceId, vehicles: vehicleRows, trips: tripRows, samples: batch)) {
            case .stop(let m): return m
            case .ok(let accepted, let rejected):
                // Rejected records can never be accepted; mark them done or they would be retried forever.
                let stored = batch.filter { accepted.contains($0.id) || rejected.contains($0.id) }
                stored.forEach { $0.synced = true }
                try? context.save()
                refreshPending()
                // The server did not mention the rest; leave them for the next run rather than lose them.
                if stored.count < batch.count { return "The server didn't confirm every reading." }
            }
        }
    }
}
