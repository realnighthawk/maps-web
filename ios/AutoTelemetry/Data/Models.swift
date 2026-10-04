import Foundation
import SwiftData

/// Owner id stamped on locally stored data before sign-in; an account adopts it on first sign-in.
let guestOwnerId = "guest"

@Model final class Vehicle {
    @Attribute(.unique) var id: String
    var vin: String
    var make: String?
    var model: String?
    var year: Int?
    var fuelType: String?
    var electrificationLevel: String?
    var isEv: Bool
    var nickname: String?
    var ownerId: String
    var updatedAt: Date

    init(id: String = UUID().uuidString, vin: String, make: String?, model: String?, year: Int?, fuelType: String?,
         electrificationLevel: String? = nil, isEv: Bool, nickname: String? = nil, ownerId: String) {
        self.id = id; self.vin = vin; self.make = make; self.model = model; self.year = year
        self.fuelType = fuelType; self.electrificationLevel = electrificationLevel; self.isEv = isEv
        self.nickname = nickname; self.ownerId = ownerId; self.updatedAt = .now
    }

    var displayName: String {
        if let n = nickname, !n.isEmpty { return n }
        let s = [year.map(String.init), make, model].compactMap { $0 }.joined(separator: " ")
        return s.isEmpty ? "My car" : s
    }

    var details: String {
        var parts = [isEv ? "Electric" : (fuelType ?? "Combustion")]
        if nickname?.isEmpty == false {
            let s = [year.map(String.init), make, model].compactMap { $0 }.joined(separator: " ")
            if !s.isEmpty { parts.append(s) }
        }
        return parts.joined(separator: " · ")
    }
}

enum Drivetrain { case gas, diesel, hybrid, ev }

extension Vehicle {
    /// What kind of car this is, from its VIN decode. It decides which measurements make sense to read and show.
    var drivetrain: Drivetrain {
        if isEv { return .ev }
        let level = electrificationLevel ?? "", fuel = fuelType ?? ""
        if level.localizedCaseInsensitiveContains("hybrid") || level.localizedCaseInsensitiveContains("PHEV") { return .hybrid }
        if fuel.localizedCaseInsensitiveContains("diesel") { return .diesel }
        return .gas
    }
}

enum TripStatus: String { case active = "ACTIVE", completed = "COMPLETED", interrupted = "INTERRUPTED" }

@Model final class Trip {
    @Attribute(.unique) var id: String
    var vehicleId: String?
    var ownerId: String
    var startedAt: Date
    var endedAt: Date?
    var status: String
    var startLat: Double?
    var startLng: Double?
    var endLat: Double?
    var endLng: Double?
    var updatedAt: Date

    init(id: String = UUID().uuidString, vehicleId: String?, ownerId: String, startedAt: Date = .now,
         startLat: Double?, startLng: Double?) {
        self.id = id; self.vehicleId = vehicleId; self.ownerId = ownerId; self.startedAt = startedAt
        self.status = TripStatus.active.rawValue; self.startLat = startLat; self.startLng = startLng
        self.updatedAt = .now
    }
}

/// One poll cycle. Local storage is the upload outbox: a row stays unsynced until the server confirms it.
@Model final class Sample {
    @Attribute(.unique) var id: String
    var tripId: String?
    var vehicleId: String?
    var ownerId: String
    var at: Date
    var lat: Double?
    var lng: Double?
    var speedKmh: Double?
    /// GPS horizontal accuracy in metres (nil when there was no fix).
    var accuracyM: Double?
    /// JSON-encoded [String: Reading].
    var readingsJSON: Data
    var synced: Bool

    init(id: String = UUID().uuidString, tripId: String?, vehicleId: String?, ownerId: String, at: Date = .now,
         lat: Double?, lng: Double?, speedKmh: Double?, accuracyM: Double? = nil, readings: [String: Reading]) {
        self.id = id; self.tripId = tripId; self.vehicleId = vehicleId; self.ownerId = ownerId; self.at = at
        self.lat = lat; self.lng = lng; self.speedKmh = speedKmh; self.accuracyM = accuracyM
        // One NaN would make the whole encode fail and lose every reading in the sample.
        self.readingsJSON = (try? JSONEncoder().encode(readings.filter { $0.value.value?.isFinite != false })) ?? Data()
        self.synced = false
    }

    var readings: [String: Reading] { (try? JSONDecoder().decode([String: Reading].self, from: readingsJSON)) ?? [:] }
}

struct Reading: Codable, Equatable {
    var label: String
    var value: Double?
    var unit: String
}
