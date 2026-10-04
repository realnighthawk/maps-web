import Foundation

struct LiveRow: Equatable, Identifiable {
    let key: String
    let label: String
    let value: String
    let unit: String
    var id: String { key }
}

struct LiveGroup: Equatable, Identifiable {
    let title: String
    let rows: [LiveRow]
    var id: String { title }
}

/// Everything a drive captures, sorted into sections for the Live screen: the car's standard readings, readings
/// specific to its model (by module), the location fix, and the phone's own sensors.
enum LiveGroups {
    static func make(_ live: [String: Reading]) -> [LiveGroup] {
        func rows(_ keys: [String], sorted: (String, String) -> Bool) -> [LiveRow] {
            keys.sorted(by: sorted).compactMap { k in live[k].map { LiveRow(key: k, label: $0.label, value: format($0).value, unit: $0.unit) } }
        }
        let keys = Array(live.keys)
        // "7E4.4801": a module address and an identifier.
        let moduleKeys = keys.filter { $0.range(of: #"^[0-9A-F]{3}\."#, options: .regularExpression) != nil }
        let gpsOrder = ["gps.lat", "gps.lng", "gps.acc", "gps.alt", "gps.course", "gps.speed"]

        var groups: [LiveGroup] = []
        let car = rows(keys.filter { !$0.contains(".") }, sorted: <)
        if !car.isEmpty { groups.append(LiveGroup(title: "Car", rows: car)) }
        for module in Set(moduleKeys.map { String($0.prefix(3)) }).sorted() {
            let r = rows(moduleKeys.filter { $0.hasPrefix(module + ".") }, sorted: <)
            groups.append(LiveGroup(title: "Module \(module) (raw values)", rows: r))
        }
        let gps = rows(keys.filter { $0.hasPrefix("gps.") }) { (gpsOrder.firstIndex(of: $0) ?? 99) < (gpsOrder.firstIndex(of: $1) ?? 99) }
        if !gps.isEmpty { groups.append(LiveGroup(title: "Location", rows: gps)) }
        let phone = rows(keys.filter { $0.hasPrefix("phone.") }) { (live[$0]?.label ?? "") < (live[$1]?.label ?? "") }
        if !phone.isEmpty { groups.append(LiveGroup(title: "Phone sensors", rows: phone)) }
        return groups
    }

    /// A number as it reads best: whole numbers plain, small ones with the decimals that matter, coordinates in full.
    static func format(_ r: Reading) -> (value: String, unit: String) {
        guard let v = r.value else { return ("–", r.unit) }
        let text: String
        if r.label == "Latitude" || r.label == "Longitude" { text = String(format: "%.5f", v) }
        else if v == v.rounded() || abs(v) >= 1000 { text = String(format: "%.0f", v) }
        else if abs(v) < 1 { text = String(format: "%.3f", v) }
        else { text = String(format: "%.1f", v) }
        return (text, r.unit)
    }
}
