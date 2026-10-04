import Foundation

/// A reading outside the standard PID list: one value from one module of one family of cars, asked with service 22
/// ("read data by identifier"). Battery state, for example, is not part of the standard for most EVs.
struct ExtendedPid {
    /// The module's request address, e.g. 7E4.
    let module: String
    let did: String
    let label: String
    let unit: String
    let tier: Tier
    let decode: ([Int]) -> Double?
    /// The key under which the reading is stored and streamed, e.g. "7E4.4801" (16 characters is the server's limit).
    var key: String { "\(module).\(did)" }
}

/// What a family of cars adds to the standard PIDs, chosen from its specifications (make, model, year from the VIN).
/// Every entry is checked against the car at connect time; one the car doesn't answer is simply dropped.
struct VehicleProfile {
    let name: String
    let matches: (Vehicle) -> Bool
    let pids: [ExtendedPid]
}

enum CarProfiles {
    static let all = [machE]

    static func match(_ vehicle: Vehicle?) -> VehicleProfile? {
        guard let vehicle else { return nil }
        return all.first { $0.matches(vehicle) }
    }

    /// Big-endian unsigned value of 1 to 4 data bytes: the number exactly as the module reports it, before any scale.
    static func raw(_ bytes: [Int]) -> Double? {
        guard (1...4).contains(bytes.count) else { return nil }
        return Double(bytes.reduce(0) { $0 << 8 | $1 })
    }

    /// Ford Mustang Mach-E. The battery module (7E4) answers these identifiers on a 2023 car (found with the car scan).
    /// They stream as raw numbers: turning one into a percentage or a voltage needs a reference reading from the car
    /// first, and a guessed scale would show a wrong battery level. 4801 and 4806 are the charge candidates.
    static let machE = VehicleProfile(
        name: "Ford Mustang Mach-E",
        matches: { v in
            (v.make ?? "").localizedCaseInsensitiveContains("ford") && (v.model ?? "").localizedCaseInsensitiveContains("mach-e")
                && (v.year ?? 0) >= 2021
        },
        pids: ["4800", "4801", "4802", "4803", "4804", "4805", "4806", "480A", "480D", "4810", "4811", "4812", "4813",
               "4814", "4818", "481D"].map { did in
            ExtendedPid(module: "7E4", did: did, label: "Mach-E battery module \(did) (raw)", unit: "raw",
                        tier: ["4801", "4806"].contains(did) ? .fast : .normal, decode: raw)
        })
}
