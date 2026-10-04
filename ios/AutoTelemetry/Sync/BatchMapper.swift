import Foundation

/// Builds the JSON body of maps-engine's POST /api/v1/ingest/batch from locally stored data.
enum BatchMapper {
    static func json(deviceId: String, vehicles: [Vehicle], trips: [Trip], samples: [Sample]) -> [String: Any] {
        [
            "device_id": deviceId,
            "vehicles": vehicles.map(vehicle),
            // A journey needs a vehicle on the server; a trip recorded with no vehicle id cannot be stored there.
            "journeys": trips.filter { !($0.vehicleId ?? "").isEmpty }.map(journey),
            "observations": samples.map(observation),
        ]
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func iso(_ d: Date) -> String { isoFormatter.string(from: d) }

    private static func vehicle(_ v: Vehicle) -> [String: Any] {
        var o: [String: Any] = ["id": v.id, "is_ev": v.isEv]
        if !v.vin.isEmpty { o["vin"] = v.vin }
        if let n = v.nickname, !n.isEmpty { o["nickname"] = n }
        if let m = v.make { o["make"] = m }
        if let m = v.model { o["model"] = m }
        if let y = v.year { o["year"] = y }
        if let f = v.fuelType { o["fuel_type"] = f }
        return o
    }

    private static func journey(_ t: Trip) -> [String: Any] {
        var o: [String: Any] = ["id": t.id, "vehicle_id": t.vehicleId ?? "", "status": t.status, "started_at": iso(t.startedAt)]
        if let e = t.endedAt { o["ended_at"] = iso(e) }
        if let a = t.startLat, let b = t.startLng { o["start_lat"] = a; o["start_lng"] = b }
        if let a = t.endLat, let b = t.endLng { o["end_lat"] = a; o["end_lng"] = b }
        return o
    }

    private static func observation(_ s: Sample) -> [String: Any] {
        var o: [String: Any] = ["record_id": s.id, "observed_at": iso(s.at)]
        if let t = s.tripId { o["journey_id"] = t }
        if let v = s.vehicleId { o["vehicle_id"] = v }
        // GPS is optional; the server wants both coordinates or neither.
        if let a = s.lat, let b = s.lng { o["lat"] = a; o["lng"] = b }
        if let k = s.speedKmh { o["speed_kmh"] = k }
        if let a = s.accuracyM, a >= 0 { o["accuracy_m"] = a }
        let readings = s.readings.sorted { $0.key < $1.key }.compactMap { pid, r -> [String: Any]? in
            guard let v = r.value, v.isFinite else { return nil }
            return ["pid": pid, "label": r.label, "value": v, "unit": r.unit]
        }
        if !readings.isEmpty { o["readings"] = readings }
        return o
    }
}
