import Foundation

struct VehicleMetadata: Equatable {
    var vin: String
    var make: String?
    var model: String?
    var year: Int?
    var fuelType: String?
    var electrificationLevel: String?
    var isEv: Bool
}

/// Looks a car up from its VIN with NHTSA's public vPIC service (free, no key). The same lookup the OBD adapter
/// flow uses once it has read a VIN off the car.
enum VinDecoder {
    enum Result {
        /// [checkDigitOk] false means the VIN decoded but its 9th character doesn't compute: likely a typo.
        case found(VehicleMetadata, checkDigitOk: Bool)
        /// Reached the service, but it doesn't know this VIN.
        case unknown(String)
        /// Couldn't reach the service (offline, timeout).
        case unavailable(String)
    }

    // 17 characters, never I, O or Q (they read as 1 and 0).
    private static let format = try! NSRegularExpression(pattern: "^[A-HJ-NPR-Z0-9]{17}$")

    static func normalize(_ raw: String) -> String { String(raw.uppercased().filter { $0.isLetter || $0.isNumber }) }

    static func isValid(_ vin: String) -> Bool {
        format.firstMatch(in: vin, range: NSRange(vin.startIndex..., in: vin)) != nil
    }

    static func decode(_ vin: String) async -> Result {
        guard let url = URL(string: "https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/\(vin)?format=json") else {
            return .unavailable("Bad VIN.")
        }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "GET"
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse else {
            return .unavailable("Couldn't reach the lookup service.")
        }
        guard http.statusCode == 200 else { return .unavailable("The lookup service returned \(http.statusCode).") }
        return parse(vin, data)
    }

    static func parse(_ vin: String, _ data: Data) -> Result {
        guard let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let r = (j["Results"] as? [[String: Any]])?.first else {
            return .unavailable("Unreadable response from the lookup service.")
        }
        func field(_ key: String) -> String? {
            let s = (r[key] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
            return s.isEmpty || s.lowercased() == "null" ? nil : s
        }
        guard let make = field("Make"), let year = field("ModelYear").flatMap(Int.init) else {
            return .unknown(field("ErrorText") ?? "No details found for this VIN.")
        }
        let fuel = field("FuelTypePrimary")
        let electrification = field("ElectrificationLevel")
        let isEv = fuel?.localizedCaseInsensitiveContains("Electric") == true ||
            electrification?.localizedCaseInsensitiveContains("Battery Electric") == true
        let codes = field("ErrorCode")?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        return .found(
            VehicleMetadata(vin: vin, make: titleCase(make), model: field("Model"), year: year, fuelType: fuel,
                            electrificationLevel: electrification, isEv: isEv),
            // vPIC lists error code 1 when the 9th-position check digit doesn't compute.
            checkDigitOk: !codes.contains("1"))
    }

    private static let acronyms: Set<String> = ["BMW", "GMC", "MG", "RAM", "AMG", "FCA"]

    /// vPIC shouts makes ("HONDA"); show "Honda" but keep real acronyms like BMW.
    static func titleCase(_ s: String) -> String {
        s.split(separator: " ").map { w in
            acronyms.contains(w.uppercased()) ? w.uppercased() : w.lowercased().capitalized
        }.joined(separator: " ")
    }
}
