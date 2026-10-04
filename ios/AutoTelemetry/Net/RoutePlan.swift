import CoreLocation
import Foundation

/// A charging or fuel stop the planner added along the route.
struct PlanStop: Identifiable {
    let id = UUID()
    let type: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let minutes: Double
    let cost: Double
    var isCharge: Bool { type.localizedCaseInsensitiveContains("charg") }
}

struct RoutePlan {
    let points: [CLLocationCoordinate2D]
    let distanceKm: Double
    let durationSec: Double
    let stops: [PlanStop]
    let totalCost: Double
    /// Charge (EV) or fuel (combustion) left on arrival, in percent, when the planner says.
    let arrivalPercent: Double?
    let arrivalIsCharge: Bool
    let warnings: [String]
}

/// Reads maps-engine's POST /api/v1/route/plan response (the fields the app shows).
enum PlanParser {
    struct Unreadable: Error {}

    static func parse(_ body: String) throws -> RoutePlan {
        guard let j = try JSONSerialization.jsonObject(with: Data(body.utf8)) as? [String: Any],
              let route = j["route"] as? [String: Any] else { throw Unreadable() }
        let stops: [PlanStop] = (j["stops"] as? [[String: Any]] ?? []).compactMap { s in
            guard let loc = s["location"] as? [String: Any], let lat = loc["lat"] as? Double, let lng = loc["lng"] as? Double
            else { return nil }
            return PlanStop(type: s["stopType"] as? String ?? "", name: s["name"] as? String ?? "",
                            coordinate: .init(latitude: lat, longitude: lng),
                            minutes: s["stopDurationMin"] as? Double ?? 0, cost: s["energyCost"] as? Double ?? 0)
        }
        let arrival = j["arrival"] as? [String: Any]
        let ev = (arrival?["ev"] as? [String: Any])?["projectedSoC"] as? Double
        let ice = (arrival?["ice"] as? [String: Any])?["projectedFuelLevel"] as? Double
        return RoutePlan(
            points: Polyline.decode(route["polyline"] as? String ?? ""),
            distanceKm: route["totalDistanceKm"] as? Double ?? 0,
            durationSec: route["totalDurationSec"] as? Double ?? 0,
            stops: stops,
            totalCost: (j["cost"] as? [String: Any])?["totalCost"] as? Double ?? 0,
            arrivalPercent: ev ?? ice,
            arrivalIsCharge: ev != nil,
            warnings: j["warnings"] as? [String] ?? [])
    }
}

/// Google's encoded polyline format (precision 5), as returned by the routing provider.
enum Polyline {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = Array(encoded.utf8)
        var out: [CLLocationCoordinate2D] = []
        var i = 0, lat = 0, lng = 0

        func next() -> Int? {
            var shift = 0, result = 0
            while i < bytes.count {
                let b = Int(bytes[i]) - 63
                i += 1
                result |= (b & 0x1f) << shift
                shift += 5
                if b < 0x20 { return result & 1 != 0 ? ~(result >> 1) : result >> 1 }
            }
            return nil
        }
        while i < bytes.count {
            guard let dLat = next(), let dLng = next() else { break }
            lat += dLat; lng += dLng
            out.append(.init(latitude: Double(lat) / 1e5, longitude: Double(lng) / 1e5))
        }
        return out
    }
}

/// Builds the Google Maps "directions" link used to hand a planned route over for turn-by-turn.
enum MapsHandoff {
    // Google Maps accepts at most 9 waypoints in a URL.
    private static let maxWaypoints = 9

    static func url(origin: CLLocationCoordinate2D?, destination: CLLocationCoordinate2D, via: [CLLocationCoordinate2D]) -> URL? {
        func p(_ c: CLLocationCoordinate2D) -> String { String(format: "%.6f,%.6f", c.latitude, c.longitude) }
        var s = "https://www.google.com/maps/dir/?api=1&travelmode=driving"
        if let origin { s += "&origin=" + p(origin) }
        s += "&destination=" + p(destination)
        let stops = via.prefix(maxWaypoints)
        if !stops.isEmpty { s += "&waypoints=" + stops.map(p).joined(separator: "%7C") }
        return URL(string: s)
    }
}

/// The planner's vehicle profile for a combustion car, built from what the user told us.
enum VehicleProfiles {
    private static let litersPerGallon = 3.78541

    static func ice(vin: String, make: String?, model: String?, year: Int?, tankGallons: Double, mpg: Double?) -> [String: Any] {
        var p: [String: Any] = ["vin": vin, "drivetrain": "ICE", "fuel_tank_size_liters": tankGallons * litersPerGallon]
        if let make { p["make"] = make }
        if let model { p["model"] = model }
        if let year { p["year"] = year }
        // One figure for both: the planner has defaults, and a single honest number beats two guesses.
        if let mpg { p["epa_mpg_city"] = mpg; p["epa_mpg_highway"] = mpg }
        return p
    }

    /// The planner's profile for an electric car. The server needs a battery size and at least one connector type.
    static func ev(vin: String, make: String?, model: String?, year: Int?, batteryKwh: Double, rangeMiles: Double?,
                   connector: String) -> [String: Any] {
        var p: [String: Any] = ["vin": vin, "drivetrain": "EV", "battery_capacity_kwh": batteryKwh, "connector_types": [connector]]
        if let make { p["make"] = make }
        if let model { p["model"] = model }
        if let year { p["year"] = year }
        if let rangeMiles { p["epa_range_miles"] = rangeMiles }
        return p
    }
}
